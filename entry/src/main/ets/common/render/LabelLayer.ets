import { Intersection, RoadSegment } from '../../model/Intersection';
import { LonLat, MapGeometry } from '../constants/MapGeometry';
import { MapCanvasBase } from './MapCanvasBase';
import { MapPalette } from './MapPalette';

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
 * 标注层：路口点、路名、路口名
 *
 * 这一层的核心不是"画字"，是**排布**：谁先占位、冲突了往哪挪。
 * 优先级设计成"拥堵 > 畅通"，因为用户看这张图的第一问题就是"哪条堵了"，
 * 拥堵路名必须保证出现，畅通路名可以让位。
 */
export class LabelLayer extends MapCanvasBase {
  /** 本帧已占用的区域，后画的标签不能压上去 */
  private boxes: Box[] = [];

  /** 顺序：先画点并占位 → 路名（拥堵优先）→ 节点名，三者互不压字 */
  draw(): void {
    this.boxes = [];
    this.drawNodeDots();
    this.drawRoadLabels();
    this.drawNodeLabels();
  }

  private levelOf(seg: RoadSegment): number {
    return this.data.levels.get(seg.id) ?? 0;
  }

  /** 路口点：小而中性，可点击但不抢路况视觉 */
  private drawNodeDots(): void {
    const nodes: Intersection[] = this.data.intersections;
    for (let i = 0; i < nodes.length; i++) {
      const it: Intersection = nodes[i];
      const x: number = this.xOf(it.longitude);
      const y: number = this.yOf(it.latitude);
      this.ctx.beginPath();
      this.ctx.arc(x, y, this.isMainNode(it.id) ? 3.4 : 2.6, 0, Math.PI * 2);
      this.ctx.fillStyle = MapPalette.NODE_FILL;
      this.ctx.fill();
      this.ctx.lineWidth = 1.3;
      this.ctx.strokeStyle = MapPalette.NODE_EDGE;
      this.ctx.stroke();
      // 占住圆点位置，后画的标签不会压在点上
      this.occupy({ left: x - 4.5, top: y - 4.5, right: x + 4.5, bottom: y + 4.5 });
    }
  }

  /**
   * 路名：沿道路方向旋转（百度地图样式），同名道路只标一次
   *
   * 排序策略是"能看出哪条堵"的关键：拥堵路段先标并优先落在路段正中间，
   * 即使图面拥挤也一定要有名字；畅通路段后标，落点被占用就换位置。
   */
  private drawRoadLabels(): void {
    const segments: RoadSegment[] = this.data.segments;
    const merged: Map<string, LabelJob> = new Map();
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      // 支路不标名：小比例尺下百度地图也不显示支路名，图面更干净
      if (!MapGeometry.isTrunk(seg.id)) {
        continue;
      }
      const pts: LonLat[] = this.pointsOf(seg);
      if (pts.length < 2) {
        continue;
      }
      const len: number = this.screenLengthOf(pts);
      const level: number = this.levelOf(seg);
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
      const minLen: number = alert ? MapPalette.MIN_ALERT_LABEL_LEN : MapPalette.MIN_LABEL_LEN;
      if (job.len < minLen) {
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
    const textW: number = this.textWidth(job.name);
    const cos: number = Math.abs(Math.cos(angle));
    const sin: number = Math.abs(Math.sin(angle));
    const halfW: number = (textW * cos + 14 * sin) / 2 + 2;
    const halfH: number = (textW * sin + 14 * cos) / 2 + 2;
    // 拥堵段优先落正中间（堵的就是这一段），畅通段错开路口
    const ts: number[] = alert ? [0.5, 0.4, 0.6, 0.3, 0.7] : [0.38, 0.5, 0.62, 0.28, 0.72];
    for (let k = 0; k < ts.length; k++) {
      const p: LonLat = this.pointAt(pts, ts[k]);
      const x: number = this.xOf(p.lon);
      const y: number = this.yOf(p.lat);
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
      const x: number = this.xOf(p.lon);
      const y: number = this.yOf(p.lat);
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
    this.ctx.strokeStyle = MapPalette.LABEL_HALO;
    this.ctx.fillStyle = alert ? MapPalette.LABEL_ALERT : MapPalette.LABEL_TEXT;
    this.ctx.strokeText(text, 0, 0);
    this.ctx.fillText(text, 0, 0);
    this.ctx.restore();
  }

  /**
   * 路口名：主路口全部标名，拥堵路段的两端优先标
   *
   * 先标拥堵端点的原因：知道"从哪个路口堵到哪个路口"，才能判断堵的是哪一段，
   * 只给路名的话，一条长路中间红一块仍然不知道起止位置。
   */
  private drawNodeLabels(): void {
    const segments: RoadSegment[] = this.data.segments;
    const targets: Intersection[] = [];
    const added: Map<string, boolean> = new Map();

    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      if (!MapGeometry.isTrunk(seg.id) || this.levelOf(seg) < 2) {
        continue;
      }
      const ends: string[] = [seg.fromId, seg.toId];
      for (let e = 0; e < ends.length; e++) {
        if (added.get(ends[e]) === true) {
          continue;
        }
        const it: Intersection | undefined = this.findNode(ends[e]);
        if (it !== undefined) {
          added.set(ends[e], true);
          targets.push(it);
        }
      }
    }

    for (let i = 0; i < MapGeometry.MAIN_NODES.length; i++) {
      const id: string = MapGeometry.MAIN_NODES[i];
      if (added.get(id) === true) {
        continue;
      }
      const it: Intersection | undefined = this.findNode(id);
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
    const halfW: number = this.textWidth(it.name) / 2 + 2;
    const halfH: number = 7;
    const cx: number = this.xOf(it.longitude);
    const cy: number = this.yOf(it.latitude);
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
      this.ctx.strokeStyle = MapPalette.LABEL_HALO;
      this.ctx.fillStyle = alert ? MapPalette.LABEL_ALERT : MapPalette.NODE_TEXT;
      this.ctx.strokeText(it.name, x, y);
      this.ctx.fillText(it.name, x, y);
      return;
    }
  }

  /** 该路口是否有拥堵路段接入 */
  private nodeIsCongested(id: string): boolean {
    const segments: RoadSegment[] = this.data.segments;
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      if (seg.fromId !== id && seg.toId !== id) {
        continue;
      }
      if (this.levelOf(seg) >= 2) {
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
}
