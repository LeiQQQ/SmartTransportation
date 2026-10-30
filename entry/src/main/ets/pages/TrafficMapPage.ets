import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection, RoadSegment } from '../model/Intersection';
import { FlowRecord } from '../model/FlowRecord';
import { LonLat, MapGeometry } from '../common/constants/MapGeometry';

/** 地图配色：仅本页绘制使用，模拟导航地图的观感 */
const MAP_BG: string = '#F4F1EA';
const MAP_GRID: string = '#E8E3D8';
const MAP_PARK: string = '#DCEBD2';
const MAP_GREEN: string = '#CFE3C0';
const MAP_INNER: string = '#F1EEE6';
const MAP_WALL: string = '#9A8F7A';
const ROAD_CURB: string = '#DAD4C8';
const ROAD_SURFACE: string = '#FFFFFF';
const ROAD_CENTER: string = '#F0C34E';
const LABEL_TEXT: string = '#6B7280';
const LABEL_HALO: string = '#FFFFFF';
const NODE_TEXT: string = '#2B2B2B';
/** 路口节点描边：拥堵信息画在道路上，节点本身保持中性 */
const NODE_EDGE: string = '#6B7280';

/**
 * 片区路况图：仿真实地图绘制（城墙、绿地、道路走向、路况色带）+ 绝对定位节点
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

  private baseScale: number = 1;
  private baseX: number = 0;
  private baseY: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private timerId: number = -1;
  /** 每条路段的拥堵度（与 segments 同序），含邻路传播 */
  private congestion: number[] = [];

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

  /**
   * 分层绘制，顺序即叠放顺序：
   * 底图 → 绿地 → 城墙 → 道路 → 路况色带 → 路名 → 路口名 → 指北针
   */
  private draw(): void {
    if (!this.ready || this.canvasW <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    this.drawBase();
    this.drawGreens();
    this.drawWall();
    this.congestion = this.computeCongestion();
    this.drawRoads();
    this.drawTraffic();
    this.drawRoadLabels();
    this.drawNodeLabels();
    this.drawCompass();
  }

  /** 底图：地块底色 + 淡网格，模拟街区肌理 */
  private drawBase(): void {
    this.ctx.fillStyle = MAP_BG;
    this.ctx.fillRect(0, 0, this.canvasW, this.canvasH);

    this.ctx.beginPath();
    this.ctx.strokeStyle = MAP_GRID;
    this.ctx.lineWidth = 0.6;
    const step: number = 0.006;
    for (let lon: number = 108.926; lon <= 108.974; lon += step) {
      const x: number = AreaConstants.lonToX(lon, this.canvasW);
      this.ctx.moveTo(x, 0);
      this.ctx.lineTo(x, this.canvasH);
    }
    for (let lat: number = 34.246; lat <= 34.279; lat += step) {
      const y: number = AreaConstants.latToY(lat, this.canvasH);
      this.ctx.moveTo(0, y);
      this.ctx.lineTo(this.canvasW, y);
    }
    this.ctx.stroke();
  }

  /** 绿化：环城公园带 + 城内绿地广场 */
  private drawGreens(): void {
    this.fillPolygon(MapGeometry.PARK_BELT, MAP_PARK);
    for (let i = 0; i < MapGeometry.GREENS.length; i++) {
      this.fillPolygon(MapGeometry.GREENS[i].points, MAP_GREEN);
    }
  }

  /** 城墙：城内底色 + 墙体轮廓 + 垛口 */
  private drawWall(): void {
    this.fillPolygon(MapGeometry.WALL, MAP_INNER);
    this.strokePolyline(MapGeometry.WALL, 3.2, MAP_WALL, true);
    this.drawBattlements();
  }

  /** 垛口：沿墙体外侧等距画短竖线，模拟城墙齿状轮廓 */
  private drawBattlements(): void {
    const cx: number = 108.9498;
    const cy: number = 34.2626;
    const steps: number = 22;
    this.ctx.beginPath();
    this.ctx.strokeStyle = MAP_WALL;
    this.ctx.lineWidth = 2;
    this.ctx.lineCap = 'butt';
    for (let i = 0; i < MapGeometry.WALL.length; i++) {
      const a: LonLat = MapGeometry.WALL[i];
      const b: LonLat = MapGeometry.WALL[(i + 1) % MapGeometry.WALL.length];
      for (let k = 0; k <= steps; k++) {
        const t: number = k / steps;
        const lon: number = a.lon + (b.lon - a.lon) * t;
        const lat: number = a.lat + (b.lat - a.lat) * t;
        const dx: number = lon > cx + 0.0005 ? 1 : (lon < cx - 0.0005 ? -1 : 0);
        const dy: number = lat > cy + 0.0005 ? 1 : (lat < cy - 0.0005 ? -1 : 0);
        const x1: number = AreaConstants.lonToX(lon, this.canvasW);
        const y1: number = AreaConstants.latToY(lat, this.canvasH);
        this.ctx.moveTo(x1, y1);
        this.ctx.lineTo(x1 + dx * 3, y1 - dy * 3);
      }
    }
    this.ctx.stroke();
  }

  /** 道路：先路缘后路面，形成带边线的道路带 */
  private drawRoads(): void {
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      // 主干按车道数给足宽度，次干与支路画细，主次分明
      const trunk: boolean = MapGeometry.isTrunk(seg.id);
      this.strokePolyline(pts, trunk ? this.curbWidthOf(seg.lanes) : 4.2, ROAD_CURB, false);
      this.strokePolyline(pts, trunk ? this.roadWidthOf(seg.lanes) : 2.8, ROAD_SURFACE, false);
    }
  }

  /**
   * 路况：把拥堵色带画在道路上（不是节点上），导航地图风格
   * 拥堵档位越高色带越宽，便于一眼看出堵点
   */
  private drawTraffic(): void {
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      // 只在主干上标路况，支路保持素面
      if (pts.length < 2 || !MapGeometry.isTrunk(seg.id)) {
        continue;
      }
      const congestion: number = i < this.congestion.length ? this.congestion[i] : 0;
      const level: number = TrafficUtil.roadLevelOf(congestion);
      const width: number = this.roadWidthOf(seg.lanes) * (0.62 + level * 0.1);
      this.ctx.globalAlpha = 0.88;
      this.strokePolyline(pts, width, TrafficUtil.colorOfRoadLevel(level), false);
      this.ctx.globalAlpha = 1;
      if (seg.lanes >= 3) {
        this.strokePolyline(pts, 0.7, ROAD_CENTER, false);
      }
    }
  }

  /**
   * 路段拥堵度（0~1）：本路段两端路口的饱和度 + 邻路传播
   *
   * 现实中一条路堵了，相连的路也会跟着堵（排队溢出），所以不能只看本路段。
   * 做法：先算本路段基础值，再取「相邻路段拥堵度 × 衰减系数」的最大值，
   * 迭代两轮，让拥堵沿路网传播两跳；衰减保证越远影响越小。
   */
  private computeCongestion(): number[] {
    const spread: number = 0.6;
    const base: number[] = [];
    for (let i = 0; i < this.segments.length; i++) {
      base.push(this.baseCongestionOf(this.segments[i]));
    }
    const result: number[] = [];
    for (let i = 0; i < base.length; i++) {
      result.push(base[i]);
    }
    for (let round = 0; round < 2; round++) {
      for (let i = 0; i < this.segments.length; i++) {
        let nearMax: number = 0;
        for (let j = 0; j < this.segments.length; j++) {
          if (i !== j && this.isAdjacent(this.segments[i], this.segments[j]) && result[j] > nearMax) {
            nearMax = result[j];
          }
        }
        result[i] = Math.max(base[i], nearMax * spread);
      }
    }
    return result;
  }

  /**
   * 本路段基础拥堵度：两端路口饱和度，向较堵的一端倾斜
   * 不用均值的理由：一段路只要一端堵死，排队就会往这段路上溢，
   * 取均值会被畅通的一端稀释，明明堵了却显示绿色
   */
  private baseCongestionOf(seg: RoadSegment): number {
    const a: Intersection | undefined = this.find(seg.fromId);
    const b: Intersection | undefined = this.find(seg.toId);
    if (a === undefined || b === undefined) {
      return 0;
    }
    const sa: number = this.saturationOf(a.id);
    const sb: number = this.saturationOf(b.id);
    const high: number = sa > sb ? sa : sb;
    const low: number = sa > sb ? sb : sa;
    return high * 0.65 + low * 0.35;
  }

  /** 两段路是否相邻（共用一个路口） */
  private isAdjacent(a: RoadSegment, b: RoadSegment): boolean {
    return a.fromId === b.fromId || a.fromId === b.toId || a.toId === b.fromId || a.toId === b.toId;
  }

  /** 路名：白描边保证在色带上可读 */
  private drawRoadLabels(): void {
    this.ctx.font = '10vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.lineWidth = 3;
    this.ctx.strokeStyle = LABEL_HALO;
    this.ctx.fillStyle = LABEL_TEXT;
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2 || !MapGeometry.isTrunk(seg.id) || this.lengthOf(pts) < 0.004) {
        continue;
      }
      const mid: LonLat = this.midPoint(pts);
      const x: number = AreaConstants.lonToX(mid.lon, this.canvasW);
      const y: number = AreaConstants.latToY(mid.lat, this.canvasH) - 7;
      this.ctx.strokeText(seg.name, x, y);
      this.ctx.fillText(seg.name, x, y);
    }
  }

  /** 路口名：只标主要路口，避免拥挤 */
  private drawNodeLabels(): void {
    this.ctx.font = '10vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.lineWidth = 3;
    this.ctx.strokeStyle = LABEL_HALO;
    this.ctx.fillStyle = NODE_TEXT;
    for (let i = 0; i < MapGeometry.MAIN_NODES.length; i++) {
      const it: Intersection | undefined = this.find(MapGeometry.MAIN_NODES[i]);
      if (it === undefined) {
        continue;
      }
      const x: number = this.nodeX(it);
      const y: number = this.nodeY(it) + 22;
      this.ctx.strokeText(it.name, x, y);
      this.ctx.fillText(it.name, x, y);
    }
  }

  /** 指北针 */
  private drawCompass(): void {
    const x: number = this.canvasW - 26;
    const y: number = 30;
    this.ctx.beginPath();
    this.ctx.strokeStyle = MAP_WALL;
    this.ctx.lineWidth = 1.2;
    this.ctx.arc(x, y, 11, 0, Math.PI * 2);
    this.ctx.stroke();
    this.ctx.fillStyle = MAP_WALL;
    this.ctx.font = 'bold 10vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.fillText('N', x, y - 15);
    this.ctx.beginPath();
    this.ctx.moveTo(x, y - 7);
    this.ctx.lineTo(x - 4, y + 5);
    this.ctx.lineTo(x + 4, y + 5);
    this.ctx.closePath();
    this.ctx.fill();
  }

  /** 折线描边 */
  private strokePolyline(pts: LonLat[], width: number, color: string, closed: boolean): void {
    if (pts.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = width;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    for (let i = 0; i < pts.length; i++) {
      const x: number = AreaConstants.lonToX(pts[i].lon, this.canvasW);
      const y: number = AreaConstants.latToY(pts[i].lat, this.canvasH);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    if (closed) {
      this.ctx.closePath();
    }
    this.ctx.stroke();
  }

  /** 多边形填充 */
  private fillPolygon(pts: LonLat[], color: string): void {
    if (pts.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.fillStyle = color;
    for (let i = 0; i < pts.length; i++) {
      const x: number = AreaConstants.lonToX(pts[i].lon, this.canvasW);
      const y: number = AreaConstants.latToY(pts[i].lat, this.canvasH);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    this.ctx.closePath();
    this.ctx.fill();
  }

  /** 路段折线：优先取几何数据，缺失时回退为两端点直线 */
  private pointsOf(seg: RoadSegment): LonLat[] {
    const pts: LonLat[] = MapGeometry.pointsOf(seg.id);
    if (pts.length >= 2) {
      return pts;
    }
    const a: Intersection | undefined = this.find(seg.fromId);
    const b: Intersection | undefined = this.find(seg.toId);
    if (a === undefined || b === undefined) {
      return [];
    }
    const list: LonLat[] = [MapGeometry.point(a.longitude, a.latitude)];
    list.push(MapGeometry.point(b.longitude, b.latitude));
    return list;
  }

  /** 折线总长（曼哈顿距离，仅用于判断是否值得标注） */
  private lengthOf(pts: LonLat[]): number {
    let total: number = 0;
    for (let i = 1; i < pts.length; i++) {
      total += Math.abs(pts[i].lon - pts[i - 1].lon) + Math.abs(pts[i].lat - pts[i - 1].lat);
    }
    return total;
  }

  /** 折线中点（按累计长度取半，用于放置路名） */
  private midPoint(pts: LonLat[]): LonLat {
    let total: number = 0;
    const spans: number[] = [];
    for (let i = 1; i < pts.length; i++) {
      const d: number = Math.abs(pts[i].lon - pts[i - 1].lon) + Math.abs(pts[i].lat - pts[i - 1].lat);
      spans.push(d);
      total += d;
    }
    let half: number = total / 2;
    for (let i = 0; i < spans.length; i++) {
      if (half <= spans[i]) {
        const ratio: number = spans[i] === 0 ? 0 : half / spans[i];
        const lon: number = pts[i].lon + (pts[i + 1].lon - pts[i].lon) * ratio;
        const lat: number = pts[i].lat + (pts[i + 1].lat - pts[i].lat) * ratio;
        return MapGeometry.point(lon, lat);
      }
      half -= spans[i];
    }
    return pts[pts.length - 1];
  }

  /** 路缘宽度（含路肩，比路面略宽） */
  private curbWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 9.5;
    }
    if (lanes === 2) {
      return 7;
    }
    return 5;
  }

  /** 路面宽度 */
  private roadWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 7.5;
    }
    if (lanes === 2) {
      return 5.2;
    }
    return 3.4;
  }

  /** 主要路口画大一点，次要路口画小一点，避免视觉喧宾夺主 */
  private nodeSize(id: string): number {
    for (let i = 0; i < MapGeometry.MAIN_NODES.length; i++) {
      if (MapGeometry.MAIN_NODES[i] === id) {
        return 13;
      }
    }
    return 10;
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
          Text('更新于 ' + this.updateTime + ' · 路况显示在道路，堵点会向相邻路段蔓延')
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
              .width(this.nodeSize(item.id))
              .height(this.nodeSize(item.id))
              .fill(ThemeConstants.BG_CARD)
              .stroke(NODE_EDGE)
              .strokeWidth(1.6)
          }
          .width(24)
          .height(24)
          .position({
            x: this.nodeX(item) - 12,
            y: this.nodeY(item) - 12
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
        Text('道路路况')
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
