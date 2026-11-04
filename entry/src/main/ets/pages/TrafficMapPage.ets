import { ThemeConstants } from '../common/constants/ThemeConstants';
import { AreaConstants } from '../common/constants/AreaConstants';
import { AppConstants } from '../common/constants/AppConstants';
import { NavRouter } from '../common/base/NavRouter';
import { TrafficUtil } from '../common/utils/TrafficUtil';
import { RepositoryFactory } from '../repository/RepositoryFactory';
import { Intersection, RoadSegment } from '../model/Intersection';
import { FlowRecord } from '../model/FlowRecord';
import { RealtimeRoad } from '../model/RealtimeRoad';
import { LonLat, MapGeometry } from '../common/constants/MapGeometry';

/**
 * 地图配色：对齐百度地图瓦片观感
 * 底色浅灰白、道路白面灰边、公园浅绿、护城河浅蓝、城墙深灰、路名深灰白描边
 */
const MAP_BG: string = '#F6F5F2';
const MAP_INNER: string = '#F3F2ED';
const MAP_PARK: string = '#D6EAC9';
const MAP_GREEN: string = '#CFE7C1';
const MAP_GREEN_EDGE: string = '#BFDCAC';
const MAP_WATER: string = '#ABD3F0';
const MAP_WALL: string = '#B5B0A8';
const MAP_WALL_EDGE: string = '#9A948C';
const ROAD_SURFACE: string = '#FFFFFF';
/** 主干道边线 */
const ROAD_CURB: string = '#CFCBC2';
/** 支路边线（更浅，避免图面发脏） */
const ROAD_CURB_MINOR: string = '#E1DED7';
const LABEL_TEXT: string = '#3F3F3F';
const LABEL_HALO: string = '#FFFFFF';
const NODE_TEXT: string = '#4A4A4A';
const NODE_FILL: string = '#FFFFFF';
/** 路口节点描边：拥堵信息画在道路上，节点本身保持中性 */
const NODE_EDGE: string = '#8E8A83';
/** 路名标注的最短屏幕长度（vp）：太短的路段不标，避免文字压过道路 */
const MIN_LABEL_LEN: number = 32;
/** 拥堵路段的最短标注长度：比普通路段放宽，保证"哪条堵了"一定有名字 */
const MIN_ALERT_LABEL_LEN: number = 16;
/** 拥堵路名与拥堵节点名：深红加粗，从满图灰字里跳出来 */
const LABEL_ALERT: string = '#B3261E';
/** 拥堵色带外描边：和白色路面拉开对比，红色区域边界更清楚 */
const TRAFFIC_EDGE: string = 'rgba(150, 32, 26, 0.5)';

/** 标签占位矩形（屏幕坐标），用于路名、节点名互相避让 */
interface Box {
  left: number;
  top: number;
  right: number;
  bottom: number;
}

/** 一条待标注的路名（同名道路合并后） */
interface LabelJob {
  name: string;
  seg: RoadSegment;
  level: number;
  len: number;
}

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
  /** 非空 = 当前用百度实测路况着色 */
  @Local realSource: string = '';

  private baseScale: number = 1;
  private baseX: number = 0;
  private baseY: number = 0;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;
  private timerId: number = -1;
  private realTimerId: number = -1;
  /** 每条路段的拥堵度（与 segments 同序），含邻路传播 */
  private congestion: number[] = [];
  /** 百度实测路况：segId → 三档 level；空 Map = 用仿真 */
  @Local realLevels: Map<string, number> = new Map();
  /** 手动刷新中：按钮显示"刷新中"并禁止重复点击 */
  @Local refreshing: boolean = false;
  /** 本帧已占用的标签区域：路名与节点名互相避让，避免压字 */
  private boxes: Box[] = [];

  aboutToAppear(): void {
    this.loadAll();
    // 流量与路况统一半分钟拉一次（后端快照 45 s 更新）
    this.timerId = setInterval(() => {
      this.loadFlows();
    }, AppConstants.REFRESH_FLOW_MS);
    this.realTimerId = setInterval(() => {
      this.loadRealtime();
    }, AppConstants.REFRESH_DATA_MS);
  }

  aboutToDisappear(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    if (this.realTimerId !== -1) {
      clearInterval(this.realTimerId);
      this.realTimerId = -1;
    }
  }

  async loadAll(): Promise<void> {
    const repo = RepositoryFactory.getTrafficRepository();
    this.intersections = await repo.getIntersections();
    this.segments = await repo.getSegments();
    await this.loadFlows();
    this.loadRealtime();
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

  /** 拉百度实测路况：非空时覆盖对应路段的三档颜色，空则保持仿真着色 */
  async loadRealtime(): Promise<void> {
    const roads: RealtimeRoad[] = await RepositoryFactory.getTrafficRepository().getRealtimeRoads();
    const next: Map<string, number> = new Map();
    for (let i = 0; i < roads.length; i++) {
      next.set(roads[i].segId, roads[i].level);
    }
    this.realLevels = next;
    if (roads.length > 0) {
      const d: Date = new Date();
      const hh: string = d.getHours() < 10 ? '0' + d.getHours() : '' + d.getHours();
      const mm: string = d.getMinutes() < 10 ? '0' + d.getMinutes() : '' + d.getMinutes();
      this.updateTime = hh + ':' + mm + ':' + (d.getSeconds() < 10 ? '0' + d.getSeconds() : '' + d.getSeconds());
      this.realSource = '数据源：百度实时路况 ' + hh + ':' + mm;
    } else {
      this.realSource = '';
    }
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
   * 底色 → 护城河 → 公园绿地 → 城内底 → 城墙 → 道路 → 路况带 → 路名 → 路口 → 指北针
   */
  private draw(): void {
    if (!this.ready || this.canvasW <= 0) {
      return;
    }
    this.ctx.clearRect(0, 0, this.canvasW, this.canvasH);
    this.boxes = [];
    this.drawBase();
    this.drawRiver();
    this.drawGreens();
    this.drawWall();
    this.congestion = this.computeCongestion();
    this.drawRoads();
    this.drawTraffic();
    // 顺序：先画点并占位 → 再画路名（拥堵优先）→ 最后画节点名，三者互不压字
    this.drawNodeDots();
    this.drawRoadLabels();
    this.drawNodeLabels();
    this.drawCompass();
  }

  /** 底图：整片浅灰白（百度地图城区底色，不画网格） */
  private drawBase(): void {
    this.ctx.fillStyle = MAP_BG;
    this.ctx.fillRect(0, 0, this.canvasW, this.canvasH);
  }

  /** 护城河：沿城墙外一圈矩形描粗线，得到环状水面 */
  private drawRiver(): void {
    this.ctx.globalAlpha = 0.92;
    this.strokePolyline(MapGeometry.RIVER, 7.5, MAP_WATER, true);
    this.ctx.globalAlpha = 1;
  }

  /** 绿化：环城公园带 + 城内绿地广场 */
  private drawGreens(): void {
    this.fillPolygon(MapGeometry.PARK_BELT, MAP_PARK);
    for (let i = 0; i < MapGeometry.GREENS.length; i++) {
      this.fillPolygon(MapGeometry.GREENS[i].points, MAP_GREEN);
      this.strokePolyline(MapGeometry.GREENS[i].points, 1, MAP_GREEN_EDGE, true);
    }
  }

  /** 城墙：城内底色 + 墙体（外深内浅做出厚度）+ 四门地标 */
  private drawWall(): void {
    this.fillPolygon(MapGeometry.WALL, MAP_INNER);
    this.strokePolyline(MapGeometry.WALL, 5.4, MAP_WALL_EDGE, true);
    this.strokePolyline(MapGeometry.WALL, 3.6, MAP_WALL, true);
    this.drawGates();
  }

  /** 城门：城墙上的门洞地标（长乐门/永宁门/安定门/安远门） */
  private drawGates(): void {
    for (let i = 0; i < MapGeometry.GATES.length; i++) {
      const x: number = AreaConstants.lonToX(MapGeometry.GATES[i].lon, this.canvasW);
      const y: number = AreaConstants.latToY(MapGeometry.GATES[i].lat, this.canvasH);
      this.ctx.fillStyle = MAP_WALL_EDGE;
      this.ctx.fillRect(x - 3.4, y - 3.4, 6.8, 6.8);
      this.ctx.fillStyle = MAP_INNER;
      this.ctx.fillRect(x - 1.5, y - 1.5, 3, 3);
    }
  }

  /**
   * 道路：先边线后路面，形成"白路灰边"的百度地图道路观感
   * 主干按车道数分级，支路更细更浅，主次分明
   */
  private drawRoads(): void {
    // 先铺所有边线，再铺所有路面，避免相邻路段的边线压在前一段的路面上
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const trunk: boolean = MapGeometry.isTrunk(seg.id);
      this.strokePolyline(pts, trunk ? this.curbWidthOf(seg.lanes) : 4.6,
        trunk ? ROAD_CURB : ROAD_CURB_MINOR, false);
    }
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const trunk: boolean = MapGeometry.isTrunk(seg.id);
      this.strokePolyline(pts, trunk ? this.roadWidthOf(seg.lanes) : 3.2, ROAD_SURFACE, false);
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
      // 百度实测优先，未覆盖的路段回落仿真
      const level: number = this.realLevels.get(seg.id) ?? TrafficUtil.roadLevelOf(congestion);
      // 分级宽度：畅通只留一条淡绿细带（避免整图泛绿），缓行/拥堵逐级加宽突出堵点
      const factor: number = level === 0 ? 0.34 : (level === 1 ? 0.56 : 0.7);
      const width: number = this.roadWidthOf(seg.lanes) * factor;
      // 拥堵段先描一圈深色外缘，红带边界更明确，和白色路面拉得开
      if (level === 2) {
        this.ctx.globalAlpha = 0.5;
        this.strokePolyline(pts, width + 3.4, TRAFFIC_EDGE, false);
      }
      this.ctx.globalAlpha = level === 0 ? 0.7 : 0.92;
      this.strokePolyline(pts, width, TrafficUtil.colorOfRoadLevel(level), false);
      this.ctx.globalAlpha = 1;
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

  /**
   * 路名：沿道路方向旋转（百度地图样式），同名道路只标一次。
   *
   * 排序策略是"能看出哪条堵"的关键：
   * 拥堵路段先标并优先落在路段正中间，即使图面拥挤也一定要有名字；
   * 畅通路段后标，落点被占用就换位置，实在挤不下才放弃。
   */
  private drawRoadLabels(): void {
    const merged: Map<string, LabelJob> = new Map();
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      // 支路不标名：小比例尺下百度地图也不显示支路名，图面更干净
      if (!MapGeometry.isTrunk(seg.id)) {
        continue;
      }
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const len: number = this.screenLengthOf(pts);
      const level: number = this.levelOfSeg(seg);
      const prev: LabelJob | undefined = merged.get(seg.name);
      // 同名道路取"更堵、更长"的一段作为代表
      if (prev === undefined || level > prev.level || (level === prev.level && len > prev.len)) {
        merged.set(seg.name, { name: seg.name, seg: seg, level: level, len: len });
      }
    }
    const jobs: LabelJob[] = [];
    merged.forEach((job: LabelJob) => {
      jobs.push(job);
    });
    jobs.sort((a: LabelJob, b: LabelJob) => (b.level - a.level) || (b.len - a.len));

    for (let i = 0; i < jobs.length; i++) {
      const job: LabelJob = jobs[i];
      const alert: boolean = job.level >= 2;
      if (job.len < (alert ? MIN_ALERT_LABEL_LEN : MIN_LABEL_LEN)) {
        continue;
      }
      this.placeRoadLabel(job, alert);
    }
  }

  /** 沿路段试多个落点，找到第一个不与已有标签冲突的位置 */
  private placeRoadLabel(job: LabelJob, alert: boolean): void {
    const pts: LonLat[] = this.pointsOf(job.seg);
    const angle: number = this.screenAngleOf(pts);
    this.ctx.font = alert ? 'bold 11.5vp sans-serif' : '10.5vp sans-serif';
    const textW: number = this.textWidthOf(job.name);
    const cos: number = Math.abs(Math.cos(angle));
    const sin: number = Math.abs(Math.sin(angle));
    const halfW: number = (textW * cos + 14 * sin) / 2 + 2;
    const halfH: number = (textW * sin + 14 * cos) / 2 + 2;
    // 拥堵段优先落正中间（堵的就是这一段），畅通段错开路口
    const ts: number[] = alert ? [0.5, 0.4, 0.6, 0.3, 0.7] : [0.38, 0.5, 0.62, 0.28, 0.72];
    for (let k = 0; k < ts.length; k++) {
      const p: LonLat = this.pointAt(pts, ts[k]);
      const x: number = AreaConstants.lonToX(p.lon, this.canvasW);
      const y: number = AreaConstants.latToY(p.lat, this.canvasH);
      const box: Box = { left: x - halfW, top: y - halfH, right: x + halfW, bottom: y + halfH };
      if (!this.isFree(box)) {
        continue;
      }
      this.occupy(box);
      this.drawRotatedLabel(job.name, x, y, angle, alert);
      return;
    }
    // 拥堵路段所有落点都被占也要画：压一点字，总比"不知道哪条堵"强
    if (alert) {
      const p: LonLat = this.pointAt(pts, 0.5);
      const x: number = AreaConstants.lonToX(p.lon, this.canvasW);
      const y: number = AreaConstants.latToY(p.lat, this.canvasH);
      this.occupy({ left: x - halfW, top: y - halfH, right: x + halfW, bottom: y + halfH });
      this.drawRotatedLabel(job.name, x, y, angle, true);
    }
  }

  private drawRotatedLabel(text: string, x: number, y: number, angle: number, alert: boolean): void {
    this.ctx.save();
    this.ctx.translate(x, y);
    this.ctx.rotate(angle);
    this.ctx.font = alert ? 'bold 11.5vp sans-serif' : '10.5vp sans-serif';
    this.ctx.textAlign = 'center';
    this.ctx.textBaseline = 'middle';
    this.ctx.lineWidth = alert ? 4.2 : 3.4;
    this.ctx.strokeStyle = LABEL_HALO;
    this.ctx.fillStyle = alert ? LABEL_ALERT : LABEL_TEXT;
    this.ctx.strokeText(text, 0, 0);
    this.ctx.fillText(text, 0, 0);
    this.ctx.restore();
  }

  /** 路口点：小而中性，可点击但不抢路况视觉 */
  private drawNodeDots(): void {
    for (let i = 0; i < this.intersections.length; i++) {
      const it: Intersection = this.intersections[i];
      const x: number = this.nodeX(it);
      const y: number = this.nodeY(it);
      this.ctx.beginPath();
      this.ctx.arc(x, y, this.isMainNode(it.id) ? 3.4 : 2.6, 0, Math.PI * 2);
      this.ctx.fillStyle = NODE_FILL;
      this.ctx.fill();
      this.ctx.lineWidth = 1.3;
      this.ctx.strokeStyle = NODE_EDGE;
      this.ctx.stroke();
      // 占住圆点位置，后画的标签不会压在点上
      this.occupy({ left: x - 4.5, top: y - 4.5, right: x + 4.5, bottom: y + 4.5 });
    }
  }

  /**
   * 路口名：主路口全部标名，拥堵路段的两端优先标
   *
   * 先标拥堵端点的原因：知道"从哪个路口堵到哪个路口"，才能判断堵的是哪一段，
   * 只给路名的话，一条长路中间红一块仍然不知道起止位置。
   */
  private drawNodeLabels(): void {
    const targets: Intersection[] = [];
    const added: Map<string, boolean> = new Map();

    // 1) 拥堵路段两端
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      if (!MapGeometry.isTrunk(seg.id) || this.levelOfSeg(seg) < 2) {
        continue;
      }
      const ends: string[] = [seg.fromId, seg.toId];
      for (let e = 0; e < ends.length; e++) {
        if (added.get(ends[e]) === true) {
          continue;
        }
        const it: Intersection | undefined = this.find(ends[e]);
        if (it !== undefined) {
          added.set(ends[e], true);
          targets.push(it);
        }
      }
    }

    // 2) 其余主干节点
    for (let i = 0; i < MapGeometry.MAIN_NODES.length; i++) {
      const id: string = MapGeometry.MAIN_NODES[i];
      if (added.get(id) === true) {
        continue;
      }
      const it: Intersection | undefined = this.find(id);
      if (it !== undefined) {
        added.set(id, true);
        targets.push(it);
      }
    }

    for (let i = 0; i < targets.length; i++) {
      this.placeNodeLabel(targets[i]);
    }
  }

  /** 节点名依次试下、上、右、左四个位置，避开已占用的标签 */
  private placeNodeLabel(it: Intersection): void {
    const alert: boolean = this.nodeIsCongested(it.id);
    this.ctx.font = alert ? 'bold 9.5vp sans-serif' : '9vp sans-serif';
    const halfW: number = this.textWidthOf(it.name) / 2 + 2;
    const halfH: number = 7;
    const cx: number = this.nodeX(it);
    const cy: number = this.nodeY(it);
    // 钟楼在四路交汇中心，上下都压路名，改放左上
    const cands: number[][] = it.id === 'INT_01'
      ? [[0, -13], [0, 13], [halfW + 10, 0], [-(halfW + 10), 0]]
      : [[0, 13], [0, -13], [halfW + 10, 0], [-(halfW + 10), 0]];
    for (let k = 0; k < cands.length; k++) {
      const x: number = cx + cands[k][0];
      const y: number = cy + cands[k][1];
      const box: Box = { left: x - halfW - 2, top: y - halfH, right: x + halfW + 2, bottom: y + halfH };
      if (!this.isFree(box)) {
        continue;
      }
      this.occupy(box);
      this.ctx.textAlign = 'center';
      this.ctx.textBaseline = 'middle';
      this.ctx.lineWidth = alert ? 4 : 3.2;
      this.ctx.strokeStyle = LABEL_HALO;
      this.ctx.fillStyle = alert ? LABEL_ALERT : NODE_TEXT;
      this.ctx.strokeText(it.name, x, y);
      this.ctx.fillText(it.name, x, y);
      return;
    }
  }

  /** 该路口是否有拥堵路段接入 */
  private nodeIsCongested(id: string): boolean {
    for (let i = 0; i < this.segments.length; i++) {
      const seg: RoadSegment = this.segments[i];
      if (seg.fromId !== id && seg.toId !== id) {
        continue;
      }
      if (this.levelOfSeg(seg) >= 2) {
        return true;
      }
    }
    return false;
  }

  private isMainNode(id: string): boolean {
    for (let i = 0; i < MapGeometry.MAIN_NODES.length; i++) {
      if (MapGeometry.MAIN_NODES[i] === id) {
        return true;
      }
    }
    return false;
  }

  /** 路段拥堵档位：百度实测优先，未覆盖回落仿真 */
  private levelOfSeg(seg: RoadSegment): number {
    const idx: number = this.segments.indexOf(seg);
    const c: number = idx >= 0 && idx < this.congestion.length ? this.congestion[idx] : 0;
    return this.realLevels.get(seg.id) ?? TrafficUtil.roadLevelOf(c);
  }

  /** 文字宽度（vp）；measureText 异常时按字数估算，保证避让逻辑不失效 */
  private textWidthOf(text: string): number {
    const m: TextMetrics = this.ctx.measureText(text);
    return m.width > 0 ? m.width : text.length * 10.5;
  }

  /** 该矩形是否与已占用区域冲突 */
  private isFree(box: Box): boolean {
    for (let i = 0; i < this.boxes.length; i++) {
      const b: Box = this.boxes[i];
      if (box.left < b.right && box.right > b.left && box.top < b.bottom && box.bottom > b.top) {
        return false;
      }
    }
    return true;
  }

  private occupy(box: Box): void {
    this.boxes.push(box);
  }

  /** 折线在屏幕上的总长（vp），用于判断是否值得标注 */
  private screenLengthOf(pts: LonLat[]): number {
    let total: number = 0;
    for (let i = 1; i < pts.length; i++) {
      const dx: number = AreaConstants.lonToX(pts[i].lon, this.canvasW)
        - AreaConstants.lonToX(pts[i - 1].lon, this.canvasW);
      const dy: number = AreaConstants.latToY(pts[i].lat, this.canvasH)
        - AreaConstants.latToY(pts[i - 1].lat, this.canvasH);
      total += Math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  /** 折线主方向（最长线段的屏幕角度，弧度），顺时针旋转且保证文字不倒置 */
  private screenAngleOf(pts: LonLat[]): number {
    let angle: number = 0;
    let longest: number = -1;
    for (let i = 1; i < pts.length; i++) {
      const dx: number = AreaConstants.lonToX(pts[i].lon, this.canvasW)
        - AreaConstants.lonToX(pts[i - 1].lon, this.canvasW);
      const dy: number = AreaConstants.latToY(pts[i].lat, this.canvasH)
        - AreaConstants.latToY(pts[i - 1].lat, this.canvasH);
      const len: number = Math.sqrt(dx * dx + dy * dy);
      if (len > longest) {
        longest = len;
        angle = Math.atan2(dy, dx);
      }
    }
    if (angle > Math.PI / 2) {
      angle -= Math.PI;
    } else if (angle < -Math.PI / 2) {
      angle += Math.PI;
    }
    return angle;
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

  /**
   * 折线上按长度比例取点（0.5 为中点）
   * 路名用 0.38 而非中点：略微偏离路口，避免与路口名、多条路名在中心区叠字
   */
  private pointAt(pts: LonLat[], ratio: number): LonLat {
    let total: number = 0;
    const spans: number[] = [];
    for (let i = 1; i < pts.length; i++) {
      const d: number = Math.abs(pts[i].lon - pts[i - 1].lon) + Math.abs(pts[i].lat - pts[i - 1].lat);
      spans.push(d);
      total += d;
    }
    let half: number = total * ratio;
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

  /** 路缘宽度（含路肩，比路面略宽，形成灰色边线） */
  private curbWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 10.8;
    }
    if (lanes === 2) {
      return 8.4;
    }
    return 5.6;
  }

  /** 路面宽度（百度地图主干道偏宽，便于承载路况色带） */
  private roadWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 8.6;
    }
    if (lanes === 2) {
      return 6.2;
    }
    return 3.4;
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
          Text((this.realSource.length > 0 ? this.realSource + ' · ' : '')
            + '更新于 ' + this.updateTime + ' · 路况显示在道路，堵点会向相邻路段蔓延')
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
            if (this.refreshing) {
              return;
            }
            this.refreshing = true;
            this.loadAll().then(() => {
              this.refreshing = false;
            });
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
