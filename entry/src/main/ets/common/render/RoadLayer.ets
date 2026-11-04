import { RoadSegment } from '../../model/Intersection';
import { TrafficUtil } from '../utils/TrafficUtil';
import { MapGeometry, LonLat } from '../constants/MapGeometry';
import { MapCanvasBase } from './MapCanvasBase';
import { MapPalette } from './MapPalette';

/**
 * 道路层：路面、路缘、路况色带
 *
 * 只负责"拿到档位后画成什么"，不再判断数据来源——
 * 实测与仿真的合并已在 CongestionModel.levels 里完成。
 */
export class RoadLayer extends MapCanvasBase {
  draw(): void {
    this.drawRoads();
    this.drawTraffic();
  }

  /**
   * 道路：先边线后路面，形成"白路灰边"的百度地图观感
   * 主干按车道数分级，支路更细更浅，主次分明
   */
  private drawRoads(): void {
    const segments: RoadSegment[] = this.data.segments;
    // 先铺所有边线，再铺所有路面，避免相邻路段的边线压在前一段的路面上
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const trunk: boolean = MapGeometry.isTrunk(seg.id);
      this.strokePolyline(pts, trunk ? this.curbWidthOf(seg.lanes) : 4.6,
        trunk ? MapPalette.CURB : MapPalette.CURB_MINOR, false);
    }
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const trunk: boolean = MapGeometry.isTrunk(seg.id);
      this.strokePolyline(pts, trunk ? this.roadWidthOf(seg.lanes) : 3.2, MapPalette.ROAD, false);
    }
  }

  /**
   * 路况：把拥堵色带画在道路上（不是节点上），导航地图风格
   * 档位越高色带越宽，便于一眼看出堵点
   */
  private drawTraffic(): void {
    const segments: RoadSegment[] = this.data.segments;
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      // 只在主干上标路况，支路保持素面
      if (pts.length < 2 || !MapGeometry.isTrunk(seg.id)) {
        continue;
      }
      const level: number = this.data.levels.get(seg.id) ?? 0;
      // 分级宽度：畅通只留一条淡绿细带（避免整图泛绿），缓行/拥堵逐级加宽突出堵点
      const factor: number = level === 0 ? 0.34 : (level === 1 ? 0.56 : 0.7);
      const width: number = this.roadWidthOf(seg.lanes) * factor;
      // 拥堵段先描一圈深色外缘，红带边界更明确，和白色路面拉得开
      if (level === 2) {
        this.ctx.globalAlpha = 0.5;
        this.strokePolyline(pts, width + 3.4, MapPalette.TRAFFIC_EDGE, false);
      }
      this.ctx.globalAlpha = level === 0 ? 0.7 : 0.92;
      this.strokePolyline(pts, width, TrafficUtil.colorOfRoadLevel(level), false);
      this.ctx.globalAlpha = 1;
    }
  }
}
