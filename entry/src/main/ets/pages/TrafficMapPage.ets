import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection, RoadSegment } from '../model/Intersection';
import { FlowRecord } from '../model/FlowRecord';

/**
 * 片区路况图：Canvas 画路段 + 绝对定位节点，支持缩放与平移
 */
@Component
export struct TrafficMapPage {
  @State intersections: Intersection[] = [];
  @State segments: RoadSegment[] = [];
  @State flows: FlowRecord[] = [];
  @State canvasW: number = 0;
  @State canvasH: number = 0;
  @State scaleValue: number = 1;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State updateTime: string = '--:--:--';

  private baseScale: number = 1;
  private baseX: number = 0;
  private baseY: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private timerId: number = -1;

  aboutToAppear(): void {
    this.loadAll();
    this.timerId = setInterval(() => {
      this.loadFlows();
    }, AppConstants.REFRESH_FLOW_MS);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  async loadAll(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.intersections = await repo.getIntersections();
    this.segments = await repo.getSegments();
    await this.loadFlows();
  }

  async loadFlows(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.flows = await repo.getFlows();
    const d: Date = new Date();
    const hh: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours();
    const mm: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes();
    const ss: string = d.getSeconds() < 10 ? '0' + d.getSeconds() : '' + d.getSeconds();
    this.updateTime = hh + ':' + mm + ':' + ss;
    this.draw();
  }

  private saturationOf(id: string): number {
    for (let i = 0; i < this.flows.length; i++) {
      if (this.flows[i].intersectionId === id) {
        let maxSat: number = 0;
        for (let j = 0; j < this.flows[i].flows.length; j++) {
          maxSat = Math.max(maxSat, this.flows[i].flows[j].saturation);
        }
        return maxSat;
      }
    }
    return 0;
  }

  private nodeX(it: Intersection): number {
    return AreaConstants.lonToX(it.longitude, this.canvasW);
  }

  private nodeY(it: Intersection): number {
    return AreaConstants.latToY(it.latitude, this.canvasH);
  }

  private draw(): void {
    if (!this.ready || this.canvasW <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);

    // 画路段
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const a: Intersection | undefined = this.find(seg.fromId);
      const b: Intersection | undefined = this.find(seg.toId);
      if (a === undefined || b === undefined) {
        continue;
      }
      const sat: number = (this.saturationOf(a.id) + this.saturationOf(b.id)) / 2;
      this.ctx.beginPath();
      this.ctx.strokeStyle = TrafficUtil.colorOfSaturation(sat);
      this.ctx.lineWidth = seg.lanes;
      this.ctx.lineCap = 'round';
      this.ctx.moveTo(this.nodeX(a), this.nodeY(a));
      this.ctx.lineTo(this.nodeX(b), this.nodeY(b));
      this.ctx.stroke();
    }
  }

  private find(id: string): Intersection | undefined {
    for (let i = 0; i < this.intersections.length; i++) {
      if (this.intersections[i].id === id) {
        return this.intersections[i];
      }
    }
    return undefined;
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
          Text('更新于 ' + this.updateTime + ' · 每 5 秒刷新')
            .fontSize(ThemeConstants.FONT_CAPTION)
            .fontColor(ThemeConstants.TEXT_SUB)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

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

      Stack({ alignContent: Alignment.TopStart }) {
        Canvas(this.ctx)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.ready = true;
            this.draw();
          })

        // 路口节点（绝对定位，便于点击）
        ForEach(this.intersections, (item: Intersection) => {
          Stack() {
            Circle()
              .width(16)
              .height(16)
              .fill(TrafficUtil.colorOfSaturation(this.saturationOf(item.id)))
              .stroke(ThemeConstants.BG_CARD)
              .strokeWidth(2)
          }
          .width(28)
          .height(28)
          .position({
            x: this.nodeX(item) - 14,
            y: this.nodeY(item) - 14
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
        this.legendItem('畅通', ThemeConstants.LEVEL_CLEAR)
        this.legendItem('基本', ThemeConstants.LEVEL_BASIC)
        this.legendItem('轻度', ThemeConstants.LEVEL_LIGHT)
        this.legendItem('中度', ThemeConstants.LEVEL_MODERATE)
        this.legendItem('严重', ThemeConstants.LEVEL_SEVERE)
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
