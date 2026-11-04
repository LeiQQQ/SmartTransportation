import { AreaConstants } from '../constants/AreaConstants';
import { LonLat, MapGeometry } from '../constants/MapGeometry';
import { Intersection, RoadSegment } from '../../model/Intersection';

/**
 * 一帧地图渲染所需的全部数据
 *
 * 关键设计：路况档位在进渲染层之前就算好（levels），
 * 图层只负责"按档位画成什么颜色"，不再各自去查实测表或仿真值，
 * 这样底图/道路/标注三层不会出现口径不一致。
 */
export interface MapRenderData {
  canvasW: number;
  canvasH: number;
  intersections: Intersection[];
  segments: RoadSegment[];
  /** segId → 三档路况（0 畅通 / 1 缓行 / 2 拥堵），已合并实测与仿真 */
  levels: Map<string, number>;
}

/** 空场景：构造图层时占位，避免大量判空 */
export const EMPTY_RENDER_DATA: MapRenderData = {
  canvasW: 0,
  canvasH: 0,
  intersections: [],
  segments: [],
  levels: new Map<string, number>()
};

/**
 * 画布基类
 *
 * 把"经纬度 → 屏幕坐标"的换算、折线/多边形、文字测量这些基础图元收在一处。
 * 三个图层（底图、道路、标注）都继承它，任何一个图层都不必再重复这些代码。
 */
export class MapCanvasBase {
  protected ctx: CanvasRenderingContext2D;
  protected data: MapRenderData = EMPTY_RENDER_DATA;
  protected w: number = 0;
  protected h: number = 0;

  constructor(ctx: CanvasRenderingContext2D) {
    this.ctx = ctx;
  }

  /** 每帧把数据与画布尺寸推进来 */
  setData(data: MapRenderData): void {
    this.data = data;
    this.w = data.canvasW;
    this.h = data.canvasH;
  }

  protected xOf(lon: number): number {
    return AreaConstants.lonToX(lon, this.w);
  }

  protected yOf(lat: number): number {
    return AreaConstants.latToY(lat, this.h);
  }

  protected findNode(id: string): Intersection | undefined {
    for (let i = 0; i < this.data.intersections.length; i++) {
      if (this.data.intersections[i].id === id) {
        return this.data.intersections[i];
      }
    }
    return undefined;
  }

  /** 路段折线：优先取几何数据，缺失时回退为两端点直线 */
  protected pointsOf(seg: RoadSegment): LonLat[] {
    const pts: LonLat[] = MapGeometry.pointsOf(seg.id);
    if (pts.length >= 2) {
      return pts;
    }
    const a: Intersection | undefined = this.findNode(seg.fromId);
    const b: Intersection | undefined = this.findNode(seg.toId);
    if (a === undefined || b === undefined) {
      return [];
    }
    return [MapGeometry.point(a.longitude, a.latitude), MapGeometry.point(b.longitude, b.latitude)];
  }

  /** 折线描边 */
  protected strokePolyline(pts: LonLat[], width: number, color: string, closed: boolean): void {
    if (pts.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.strokeStyle = color;
    this.ctx.lineWidth = width;
    this.ctx.lineCap = 'round';
    this.ctx.lineJoin = 'round';
    for (let i = 0; i < pts.length; i++) {
      const x: number = this.xOf(pts[i].lon);
      const y: number = this.yOf(pts[i].lat);
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
  protected fillPolygon(pts: LonLat[], color: string): void {
    if (pts.length < 2) {
      return;
    }
    this.ctx.beginPath();
    this.ctx.fillStyle = color;
    for (let i = 0; i < pts.length; i++) {
      const x: number = this.xOf(pts[i].lon);
      const y: number = this.yOf(pts[i].lat);
      if (i === 0) {
        this.ctx.moveTo(x, y);
      } else {
        this.ctx.lineTo(x, y);
      }
    }
    this.ctx.closePath();
    this.ctx.fill();
  }

  /** 文字宽度（vp）；measureText 异常时按字数估算，保证避让逻辑不失效 */
  protected textWidth(text: string): number {
    const m: TextMetrics = this.ctx.measureText(text);
    return m.width > 0 ? m.width : text.length * 10.5;
  }

  /** 折线在屏幕上的总长（vp） */
  protected screenLengthOf(pts: LonLat[]): number {
    let total: number = 0;
    for (let i = 1; i < pts.length; i++) {
      const dx: number = this.xOf(pts[i].lon) - this.xOf(pts[i - 1].lon);
      const dy: number = this.yOf(pts[i].lat) - this.yOf(pts[i - 1].lat);
      total += Math.sqrt(dx * dx + dy * dy);
    }
    return total;
  }

  /** 折线主方向（最长线段的屏幕角度，弧度），保证文字不倒置 */
  protected screenAngleOf(pts: LonLat[]): number {
    let angle: number = 0;
    let longest: number = -1;
    for (let i = 1; i < pts.length; i++) {
      const dx: number = this.xOf(pts[i].lon) - this.xOf(pts[i - 1].lon);
      const dy: number = this.yOf(pts[i].lat) - this.yOf(pts[i - 1].lat);
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

  /**
   * 折线上按长度比例取点（0.5 为中点）
   * 路名用 0.38 而非中点：略微偏离路口，避免与路口名、多条路名在中心区叠字
   */
  protected pointAt(pts: LonLat[], ratio: number): LonLat {
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
        const r: number = spans[i] === 0 ? 0 : half / spans[i];
        const lon: number = pts[i].lon + (pts[i + 1].lon - pts[i].lon) * r;
        const lat: number = pts[i].lat + (pts[i + 1].lat - pts[i].lat) * r;
        return MapGeometry.point(lon, lat);
      }
      half -= spans[i];
    }
    return pts[pts.length - 1];
  }

  /** 路缘宽度（含路肩，比路面略宽，形成灰色边线） */
  protected curbWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 10.8;
    }
    return lanes === 2 ? 8.4 : 5.6;
  }

  /** 路面宽度（主干道偏宽，便于承载路况色带） */
  protected roadWidthOf(lanes: number): number {
    if (lanes >= 3) {
      return 8.6;
    }
    return lanes === 2 ? 6.2 : 3.4;
  }
}
