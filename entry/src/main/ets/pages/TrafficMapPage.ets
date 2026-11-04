import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { CongestionModel } from '../common/utils/CongestionModel';
import { RefreshController } from '../common/utils/RefreshController';
import { CityMapRenderer } from '../common/render/CityMapRenderer';
import { MapRenderData } from '../common/render/MapCanvasBase';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection } from '../model/Intersection';
import { RoadSegment } from '../model/Intersection';
import { FlowRecord } from '../model/FlowRecord';
import { RealtimeRoad } from '../model/RealtimeRoad';

/**
 * 片区路况图
 *
 * 这一层只做三件事：拉数据、维护视图状态（尺寸/缩放/刷新）、组织布局。
 * 具体怎么画交给 CityMapRenderer（底图 + 道路 + 标注三层），
 * 路况怎么算交给 CongestionModel——页面不再是"什么都干"的巨型组件。
 */
@ComponentV2
export struct TrafficMapPage {
  @Local intersections: Intersection[] = [];
  @Local segments: RoadSegment[] = [];
  @Local flows: FlowRecord[] = [];
  @Local canvasW: number = 0;
  @Local canvasH: number = 0;
  @Local scaleValue: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local updateTime: string = '--:--:--';
  /** 非空 = 当前用百度实测路况着色 */
  @Local realSource: string = '';
  /** 百度实测路况：segId → 三档 level；空 Map = 用仿真 */
  @Local realLevels: Map<string, number> = new Map();
  /** 手动刷新中：按钮显示"刷新中"并禁止重复点击 */
  @Local refreshing: boolean = false;

  private baseScale: number = 1;
  private baseX: number = 0;
  private baseY: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private renderer: CityMapRenderer | undefined = undefined;
  private ready: boolean = false;
  private refresher: RefreshController | undefined = undefined;

  aboutToAppear(): void {
    this.loadAll();
    // 流量与路况统一半分钟拉一次（后端快照 45 s 更新）
    this.refresher = new RefreshController(AppConstants.REFRESH_DATA_MS, () => this.loadAll(),
      (busy: boolean) => {
        this.refreshing = busy;
      });
    this.refresher.start();
  }

  aboutToDisappear(): void {
    if (this.refresher !== undefined) {
      this.refresher.stop();
    }
  }

  async loadAll(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.intersections = await repo.getIntersections();
    this.segments = await repo.getSegments();
    await this.loadFlows();
    await this.loadRealtime();
  }

  async loadFlows(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.flows = await repo.getFlows();
    this.updateTime = this.timeText();
    this.draw();
  }

  /** 数据来源文案：有实测写明实测，没有就直说在跑仿真，避免被误读成实时数据 */
  private sourceText(): string {
    return this.realSource.length > 0 ? this.realSource : '仿真数据（未连接后端）';
  }

  /** 拉百度实测路况：非空时覆盖对应路段的三档颜色，空则保持仿真着色 */
  async loadRealtime(): Promise<void> {
    const roads: RealtimeRoad[] = await RepositoryFactory.getTrafficRepository().getRealtimeRoads();
    const next: Map<string, number> = new Map();
    for (let i = 0; i < roads.length; i++) {
      next.set(roads[i].segId, roads[i].level);
    }
    this.realLevels = next;
    this.updateTime = this.timeText();
    if (roads.length > 0) {
      const d: Date = new Date();
      const hh: string = this.pad(d.getHours());
      const mm: string = this.pad(d.getMinutes());
      this.realSource = '数据源：百度实时路况 ' + hh + ':' + mm;
    } else {
      this.realSource = '';
    }
    this.draw();
  }

  private pad(value: number): string {
    return value < 10 ? '0' + value : '' + value;
  }

  private timeText(): string {
    const d: Date = new Date();
    return this.pad(d.getHours()) + ':' + this.pad(d.getMinutes()) + ':' + this.pad(d.getSeconds());
  }

  private nodeX(it: Intersection): number {
    return AreaConstants.lonToX(it.longitude, this.canvasW);
  }

  private nodeY(it: Intersection): number {
    return AreaConstants.latToY(it.latitude, this.canvasH);
  }

  private ensureRenderer(): CityMapRenderer {
    if (this.renderer === undefined) {
      this.renderer = new CityMapRenderer(this.ctx);
    }
    return this.renderer;
  }

  /** 整帧重绘：数据先合并成唯一口径的路况档位，再交给渲染器 */
  private draw(): void {
    if (!this.ready || this.canvasW <= 0) {
      return;
    }
    const data: MapRenderData = {
      canvasW: this.canvasW,
      canvasH: this.canvasH,
      intersections: this.intersections,
      segments: this.segments,
      levels: CongestionModel.levels(this.segments, this.flows, this.realLevels)
    };
    this.ensureRenderer().render(data);
  }

  build() {
    Column() {
      // 标题栏
      Row() {
        Column() {
          Text('片区路况')
            .fontSize(ThemeConstants.FONT_TITLE)
            .fontWeight(FontWeight.Bold)
            .fontColor(ThemeConstants.TEXT_MAIN)
          Text(this.sourceText() + ' · 更新于 ' + this.updateTime + ' · 路况显示在道路，堵点会向相邻路段蔓延')
            .fontSize(ThemeConstants.FONT_CAPTION)
            .fontColor(ThemeConstants.TEXT_SUB)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.refreshing ? '刷新中' : '刷新')
          .fontSize(13)
          .fontColor(this.refreshing ? ThemeConstants.TEXT_SUB : ThemeConstants.PRIMARY)
          .margin({ right: 16 })
          .onClick(() => {
            if (this.refresher !== undefined) {
              this.refresher.trigger();
            }
          })

        Text('复位')
          .fontSize(13)
          .fontColor(ThemeConstants.PRIMARY)
          .onClick(() => {
            this.scaleValue = 1;
            this.offsetX = 0;
            this.offsetY = 0;
            this.baseScale = 1;
            this.baseX = 0;
            this.baseY = 0;
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // Canvas 自绘仿真实地图（零地图 SDK 依赖）
      Stack({ alignContent: Alignment.TopStart }) {
        Canvas(this.ctx)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.ready = true;
            this.draw();
          })

        // 路口点击热区（视觉由 Canvas 绘制的小圆点承担，这里只做透明热区）
        ForEach(this.intersections, (item: Intersection) => {
          Stack() {
            Circle()
              .width('100%')
              .height('100%')
              .fill(Color.Transparent)
          }
          .width(26)
          .height(26)
          .position({
            x: this.nodeX(item) - 13,
            y: this.nodeY(item) - 13
          })
          .onClick(() => {
            NavRouter.toIntersection(item.id);
          })
        }, (item: Intersection) => item.id)
      }
      .width('100%')
      .layoutWeight(1)
      .scale({ x: this.scaleValue, y: this.scaleValue })
      .translate({ x: this.offsetX, y: this.offsetY })
      .gesture(
        GestureGroup(GestureMode.Parallel,
          PinchGesture({ fingers: 2 })
            .onActionStart(() => {
              this.baseScale = this.scaleValue;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.scaleValue = Math.max(0.8, Math.min(3, this.baseScale * event.scale));
            }),
          PanGesture({ fingers: 1 })
            .onActionStart(() => {
              this.baseX = this.offsetX;
              this.baseY = this.offsetY;
            })
            .onActionUpdate((event: GestureEvent) => {
              this.offsetX = this.baseX + event.offsetX;
              this.offsetY = this.baseY + event.offsetY;
            })
        )
      )
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.canvasW = newArea.width as number;
        this.canvasH = newArea.height as number;
        this.draw();
      })

      // 图例
      Row() {
        Text('路况 · 堵段标红加粗')
          .fontSize(11)
          .fontColor(ThemeConstants.TEXT_SUB)
        this.legendItem('畅通', ThemeConstants.LEVEL_CLEAR)
        this.legendItem('缓行', ThemeConstants.LEVEL_LIGHT)
        this.legendItem('拥堵', ThemeConstants.LEVEL_SEVERE)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(ThemeConstants.BG_CARD)
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ThemeConstants.BG_CARD)
  }

  @Builder
  legendItem(name: string, color: string) {
    Row() {
      Circle()
        .width(8)
        .height(8)
        .fill(color)
      Text(name)
        .fontSize(11)
        .fontColor(ThemeConstants.TEXT_SUB)
        .margin({ left: 4 })
    }
  }
}
