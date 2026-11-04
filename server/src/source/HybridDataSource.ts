import type { IDataSource } from './IDataSource.js';
import { INTERSECTIONS, SEGMENTS, findIntersection } from '../data/network.js';
import { TRAFFIC } from '../config.js';
import { buildAreaIndex, buildFlowRecord, hourOf } from '../algo/simulator.js';
import { capacityOf } from '../util/metric.js';
import {
  FREE_SATURATION, applyTrend, boundByStatus, clamp, congestionWeight, distanceMeters,
  matchSectionSegment, queueFromDistance, saturationFromSpeed
} from '../algo/reverse.js';
import type { BaiduTrafficService } from '../service/BaiduTrafficService.js';
import type {
  ApproachDir, ApproachFlow, AreaTrafficIndex, FlowRecord, Intersection, RealtimeRoad,
  RealtimeSection, RealtimeSnapshot, RoadSegment
} from '../types/index.js';

/**
 * 混合数据源：百度实测反推优先，缺失时回落确定性仿真
 *
 * 为什么需要它：
 *   地图开放平台不给进口道分方向流量，但给了「车速 / 拥堵距离 / 方向 / 趋势」。
 *   本数据源把这些实测参数反推成饱和度与排队长度，让信号配时由真实路况驱动，
 *   而不是纯伪随机仿真。未能覆盖的路口/进口道仍用仿真，保证任何情况下都有数据。
 *
 * 反推链条：
 *   congestion_sections[].speed                → BPR 反函数 → 饱和度
 *   congestion_sections[].congestion_distance  → 车头间距换算 → 排队车辆数
 *   congestion_sections[].section_desc 的方向   → 只作用于终点路口的对应进口道
 *   congestion_sections[].status/trend          → 约束区间与趋势微调
 */

/** 单段实测反推结果 */
interface MeasuredSegment {
  /** 实测反推的饱和度（拥堵/缓行时有意义） */
  saturation: number;
  /**
   * 百度未返回拥堵区段 = 该段畅通：只约束上限，不覆盖仿真差异
   * （若直接写死低值，所有非拥堵进口道会变成同一个数字，反而失真）
   */
  clear: boolean;
  queue: number;
  /** 实测方向对应的进口道；null 表示双向都适用 */
  approach: ApproachDir | null;
  /** 实测明细文案，端侧用于标注「这个数字从哪来」 */
  note: string;
}

/** 畅通区间的饱和度上下限（实测判定畅通时的约束范围） */
const CLEAR_LOW: number = 0.2;
const CLEAR_HIGH: number = 0.55;
/** 畅通时排队车辆数上限（辆） */
const CLEAR_QUEUE_MAX: number = 8;

export class HybridDataSource implements IDataSource {
  private readonly baidu: BaiduTrafficService;
  /** 按快照时间戳缓存的段级反推结果，避免每次请求重复计算 */
  private measured: { ts: number; bySeg: Map<string, MeasuredSegment> } | null = null;

  constructor(baidu: BaiduTrafficService) {
    this.baidu = baidu;
  }

  /** 数据源标识：拿到实测时为 BAIDU+SIM，否则纯仿真（/health 会透出） */
  get name(): string {
    const snap: RealtimeSnapshot | null = this.baidu.lastSnapshot();
    return snap !== null && snap.ok ? 'BAIDU+SIM' : 'SIMULATION';
  }

  getIntersections(): Intersection[] {
    return [...INTERSECTIONS];
  }

  getSegments(): RoadSegment[] {
    return [...SEGMENTS];
  }

  getFlows(hour?: number): FlowRecord[] {
    const h: number = hour ?? hourOf();
    return INTERSECTIONS.map((item) => this.recordOf(item, h));
  }

  getFlowOf(intersectionId: string, hour?: number): FlowRecord | undefined {
    const intersection: Intersection | undefined = findIntersection(intersectionId);
    if (intersection === undefined) {
      return undefined;
    }
    return this.recordOf(intersection, hour ?? hourOf());
  }

  getAreaIndex(hour?: number): AreaTrafficIndex {
    const records: FlowRecord[] = this.getFlows(hour);
    const base: AreaTrafficIndex = buildAreaIndex(records);
    const snap: RealtimeSnapshot | null = this.baidu.lastSnapshot();
    if (snap === null || !snap.ok) {
      return base;
    }
    // 平均车速优先用实测（按路段长度加权）；全城畅通时 speed 缺省，取自由流车速
    let sum: number = 0;
    let weight: number = 0;
    for (const road of snap.roads) {
      const seg: RoadSegment | undefined = SEGMENTS.find((item) => item.id === road.segId);
      if (seg === undefined) {
        continue;
      }
      const len: number = this.lengthOf(seg);
      sum += (road.speed ?? TRAFFIC.FREE_FLOW_SPEED) * len;
      weight += len;
    }
    return {
      areaName: base.areaName,
      index: base.index,
      avgSpeed: weight > 0 ? Math.round(sum / weight) : base.avgSpeed,
      updateTime: base.updateTime
    };
  }

  /** 单路口：仿真打底，命中的进口道用实测反推值覆盖 */
  private recordOf(intersection: Intersection, hour: number): FlowRecord {
    const base: FlowRecord = buildFlowRecord(intersection, hour);
    const snap: RealtimeSnapshot | null = this.baidu.lastSnapshot();
    if (snap === null || !snap.ok) {
      return base;
    }
    const bySeg: Map<string, MeasuredSegment> = this.measuredMap(snap);

    const flows: ApproachFlow[] = [];
    for (let i = 0; i < intersection.approaches.length; i++) {
      const approach = intersection.approaches[i];
      const measured: MeasuredSegment | null = this.measuredOf(intersection, approach.dir, bySeg);
      if (measured === null) {
        flows.push({ ...base.flows[i], source: 'SIM' });
        continue;
      }
      const capacity: number = capacityOf(approach.saturationFlow, approach.lanes, TRAFFIC.DISPLAY_GREEN_RATIO);
      const baseFlow: ApproachFlow = base.flows[i];
      if (measured.clear) {
        // 实测畅通：把仿真值约束在畅通区间内，保留不同路口/时段的差异
        const x: number = clamp(baseFlow.saturation, CLEAR_LOW, CLEAR_HIGH);
        flows.push({
          dir: approach.dir,
          volume: Math.round(x * capacity),
          queueLength: Math.min(baseFlow.queueLength, CLEAR_QUEUE_MAX),
          delay: Math.round(x * TRAFFIC.DELAY_COEFF + TRAFFIC.DELAY_BASE),
          saturation: Number(x.toFixed(2)),
          source: 'BAIDU',
          note: measured.note
        });
        continue;
      }
      // 实测拥堵/缓行：以实测反推值为主
      flows.push({
        dir: approach.dir,
        volume: Math.round(measured.saturation * capacity),
        queueLength: measured.queue,
        delay: Math.round(measured.saturation * TRAFFIC.DELAY_COEFF + TRAFFIC.DELAY_BASE),
        saturation: Number(measured.saturation.toFixed(2)),
        source: 'BAIDU',
        note: measured.note
      });
    }
    return { intersectionId: intersection.id, timestamp: Date.now(), flows: flows };
  }

  /** 找出「进入该路口、且来源方向等于 dir」的路段实测值 */
  private measuredOf(intersection: Intersection, dir: ApproachDir,
    bySeg: Map<string, MeasuredSegment>): MeasuredSegment | null {
    for (const seg of SEGMENTS) {
      if (seg.fromId !== intersection.id && seg.toId !== intersection.id) {
        continue;
      }
      const neighborId: string = seg.fromId === intersection.id ? seg.toId : seg.fromId;
      if (this.approachOf(intersection, neighborId) !== dir) {
        continue;
      }
      const measured: MeasuredSegment | undefined = bySeg.get(seg.id);
      if (measured === undefined) {
        continue;
      }
      // 实测方向与该进口不一致（如该段只堵了反方向），不覆盖
      if (measured.approach !== null && measured.approach !== dir) {
        continue;
      }
      return measured;
    }
    return null;
  }

  /** 相邻路口相对本路口的方位 → 本路口对应的进口道 */
  private approachOf(intersection: Intersection, neighborId: string): ApproachDir | null {
    const neighbor: Intersection | undefined = findIntersection(neighborId);
    if (neighbor === undefined) {
      return null;
    }
    const dx: number = neighbor.longitude - intersection.longitude;
    const dy: number = neighbor.latitude - intersection.latitude;
    if (Math.abs(dx) >= Math.abs(dy)) {
      return dx < 0 ? 'WEST' : 'EAST';
    }
    return dy < 0 ? 'SOUTH' : 'NORTH';
  }

  /** 段级反推：同一快照只算一次 */
  private measuredMap(snap: RealtimeSnapshot): Map<string, MeasuredSegment> {
    if (this.measured !== null && this.measured.ts === snap.ts) {
      return this.measured.bySeg;
    }
    const bySeg: Map<string, MeasuredSegment> = new Map();
    for (const road of snap.roads) {
      const seg: RoadSegment | undefined = SEGMENTS.find((item) => item.id === road.segId);
      if (seg === undefined) {
        continue;
      }
      const measured: MeasuredSegment | null = this.reverseOf(road, seg);
      if (measured !== null) {
        bySeg.set(seg.id, measured);
      }
    }
    this.measured = { ts: snap.ts, bySeg: bySeg };
    return bySeg;
  }

  /** 单段反推：车速 → 饱和度，拥堵距离 → 排队，方向 → 进口道 */
  private reverseOf(road: RealtimeRoad, seg: RoadSegment): MeasuredSegment | null {
    if (road.sections.length === 0) {
      // 百度仅在存在拥堵区段时返回该数组：空 = 整段畅通
      return { saturation: FREE_SATURATION, clear: true, queue: 0, approach: null, note: '实测畅通' };
    }

    // 长道路被切成多段播报时，用方位词（东段/西段…）把拥堵落到具体路段
    let target = road.sections.find((item) => matchSectionSegment(item.desc, seg.name));
    if (target === undefined) {
      // 描述未指明方位：取最拥堵的一段，按长度占比分摊影响
      target = road.sections.reduce((worst, item) => (item.status > worst.status ? item : worst));
    }

    const raw: number = saturationFromSpeed(target.speed);
    const bounded: number = boundByStatus(raw, target.status);
    const withTrend: number = applyTrend(bounded, target.trend);
    // 只堵一小段时整段平均饱和度不该被拉满
    const weight: number = congestionWeight(target.congestionDistance, this.lengthOf(seg));
    const saturation: number = FREE_SATURATION + (withTrend - FREE_SATURATION) * weight;

    return {
      saturation: Number(saturation.toFixed(2)),
      clear: false,
      queue: queueFromDistance(target.congestionDistance * weight),
      approach: target.approach,
      note: this.sectionNote(target)
    };
  }

  /** 实测细节文案：方向 · 拥堵长度 · 趋势 · 车速 */
  private sectionNote(section: RealtimeSection): string {
    const parts: string[] = [];
    const head: string = section.desc.split(',')[0].trim();
    if (head.length > 0) {
      parts.push(head);
    }
    if (section.congestionDistance > 0) {
      parts.push(section.congestionDistance + 'm');
    }
    if (section.trend.length > 0) {
      parts.push(section.trend);
    }
    if (section.speed > 0) {
      parts.push(section.speed.toFixed(0) + 'km/h');
    }
    return parts.length > 0 ? parts.join(' · ') : '实测拥堵';
  }

  /** 路段长度（米）：两端路口直线距离，用于拥堵占比与车速加权 */
  private lengthOf(seg: RoadSegment): number {
    const from: Intersection | undefined = findIntersection(seg.fromId);
    const to: Intersection | undefined = findIntersection(seg.toId);
    if (from === undefined || to === undefined) {
      return 600;
    }
    return Math.max(100, distanceMeters(from.longitude, from.latitude, to.longitude, to.latitude));
  }
}
