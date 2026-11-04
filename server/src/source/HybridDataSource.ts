import type { IDataSource } from './IDataSource.js';
import { INTERSECTIONS, SEGMENTS, findIntersection } from '../data/network.js';
import { TRAFFIC } from '../config.js';
import { buildAreaIndex, buildFlowRecord, hourOf } from '../algo/simulator.js';
import { capacityOf } from '../util/metric.js';
import { clamp, distanceMeters } from '../algo/reverse.js';
import {
  CLEAR_HIGH, CLEAR_LOW, CLEAR_QUEUE_MAX, MeasuredSegment, approachTo, resolveMeasured
} from '../algo/measured.js';
import type { BaiduTrafficService } from '../service/BaiduTrafficService.js';
import type {
  ApproachDir, ApproachFlow, AreaTrafficIndex, FlowRecord, Intersection, RealtimeSnapshot, RoadSegment
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
      const neighbor: Intersection | undefined = findIntersection(neighborId);
      if (neighbor === undefined || approachTo(intersection, neighbor) !== dir) {
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
      bySeg.set(seg.id, resolveMeasured(road, seg, this.lengthOf(seg)));
    }
    this.measured = { ts: snap.ts, bySeg: bySeg };
    return bySeg;
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
