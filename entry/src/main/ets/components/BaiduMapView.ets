import { MapComponent, MapController, MapOptions, MapStatus, Polyline } from '@bdmap/map';
import { SysEnum } from '@bdmap/map';
import { LatLng } from '@bdmap/base';
import { BusinessError } from '@kit.BasicServicesKit';
import { Intersection, RoadSegment } from '../model/Intersection';
import { wgs84ToBd09 } from '../common/utils/CoordinateUtil';
import { AppConstants } from '../common/constants/AppConstants';
import { TrafficUtil } from '../common/utils/TrafficUtil';

/**
 * 百度地图底图组件（HarmonyOS SDK @bdmap/map）
 *
 * 道路形状、路名与百度地图完全一致（同一渲染引擎）；
 * 开启官方实时路况图层，并在其上叠加 32 条路段的三档路况色带（与 Canvas 引擎同源）。
 * 路段数据 / 路况等级变化时自动重绘；SDK 未初始化时不应挂载本组件（由 TrafficMapPage 决定）。
 */
@ComponentV2
export struct BaiduMapView {
  @Param @Require segments: RoadSegment[] = [];
  @Param intersections: Intersection[] = [];
  /** segId → 三档路况（0 畅通 / 1 缓行 / 2 拥堵），来自百度实测 */
  @Param levels: Map<string, number> = new Map();
  /** 底图加载失败（鉴权错/无网络/超时）：通知父组件回落 Canvas */
  @Event onFail: () => void = () => {
  };

  private controller: MapController | null = null;
  /** segId → 已添加的折线，用于等级变化时就地改色 */
  private polylines: Map<string, Polyline> = new Map();
  /** segId → 折线坐标（Polyline.points 不可读，绘制时同步保存） */
  private linePoints: Map<string, LatLng[]> = new Map();

  private mapOpt: MapOptions = new MapOptions({
    mapStatus: new MapStatus({
      center: BaiduMapView.bd09(AppConstants.MAP_CENTER_LON, AppConstants.MAP_CENTER_LAT),
      zoom: AppConstants.MAP_ZOOM
    }),
    gestures: {
      zoom: true,
      move: true,
      rotate: false,
      overlooking: false
    },
    shows: {
      satelliteMap: SysEnum.ESatelliteLayerType.NONE,
      trafficMap: true
    }
  });

  private static bd09(lon: number, lat: number): LatLng {
    const p: number[] = wgs84ToBd09(lon, lat);
    return new LatLng(p[1], p[0]);
  }

  private loadTimerId: number = -1;

  aboutToAppear(): void {
    // 鉴权失败或弱网时 SDK 可能既不回调也不报错，8s 兜底回落 Canvas
    this.loadTimerId = setTimeout(() => {
      if (this.controller === null) {
        this.onFail();
      }
    }, 8000);
  }

  aboutToDisappear(): void {
    if (this.loadTimerId !== -1) {
      clearTimeout(this.loadTimerId);
      this.loadTimerId = -1;
    }
  }

  private onMapReady = (err: BusinessError, ctrl: MapController): void => {
    if (err) {
      this.onFail();
      return;
    }
    this.controller = ctrl;
    if (this.loadTimerId !== -1) {
      clearTimeout(this.loadTimerId);
      this.loadTimerId = -1;
    }
    this.drawSegments();
  };

  build() {
    MapComponent({
      onReady: this.onMapReady,
      mapOptions: this.mapOpt
    })
      .width('100%')
      .height('100%')
  }

  private pointOf(id: string): LatLng | undefined {
    for (let i = 0; i < this.intersections.length; i++) {
      if (this.intersections[i].id === id) {
        const it: Intersection = this.intersections[i];
        return BaiduMapView.bd09(it.longitude, it.latitude);
      }
    }
    return undefined;
  }

  private drawSegments(): void {
    const ctrl: MapController | null = this.controller;
    if (ctrl === null) {
      return;
    }
    // 先清掉旧折线再画，保证 segments 更新后不残留
    this.polylines.forEach((line: Polyline) => ctrl.removeOverlay(line));
    this.polylines.clear();
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const a: LatLng | undefined = this.pointOf(seg.fromId);
      const b: LatLng | undefined = this.pointOf(seg.toId);
      if (a === undefined || b === undefined) {
        continue;
      }
      const level: number = this.levels.get(seg.id) ?? 0;
      const line: Polyline = new Polyline({
        points: [a, b],
        fillcolor: TrafficUtil.colorOfRoadLevel(level),
        width: seg.lanes >= 3 ? 10 : 6,
        join: SysEnum.LineJoinType.ROUND,
        cap: SysEnum.LineCapType.ROUND
      });
      this.polylines.set(seg.id, line);
      this.linePoints.set(seg.id, [a, b]);
      ctrl.addOverlay(line);
    }
    // 视野对准城墙片区
    const all: LatLng[] = [];
    this.linePoints.forEach((pts: LatLng[]) => {
      for (let j = 0; j < pts.length; j++) {
        all.push(pts[j]);
      }
    });
    if (all.length > 0) {
      ctrl.setViewport(all);
    }
  }

  @Monitor('levels')
  onLevelsChange(): void {
    this.drawSegments();
  }

  @Monitor('segments')
  onSegmentsChange(): void {
    this.drawSegments();
  }
}
