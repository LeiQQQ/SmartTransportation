import type { ApproachDir, Intersection, RealtimeRoad, RealtimeSection, RoadSegment } from '../types/index.js';
import {
  FREE_SATURATION, applyTrend, boundByStatus, congestionWeight, matchSectionSegment,
  queueFromDistance, saturationFromSpeed
} from './reverse.js';

/**
 * 单段实测反推结果
 *
 * 从 HybridDataSource 里拆出来的原因：这一段是纯换算（车速→饱和度、距离→排队、
 * 方向→进口道），不依赖数据源状态，可以单独验证；数据源那边只保留"怎么用"。
 */
export interface MeasuredSegment {
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
export const CLEAR_LOW: number = 0.2;
export const CLEAR_HIGH: number = 0.55;
/** 畅通时排队车辆数上限（辆） */
export const CLEAR_QUEUE_MAX: number = 8;

/**
 * 单段反推：车速 → 饱和度，拥堵距离 → 排队，方向 → 进口道
 *
 * @param segLength 路段长度（米），用于把"只堵了一小段"折成整段平均影响
 */
export function resolveMeasured(road: RealtimeRoad, seg: RoadSegment, segLength: number): MeasuredSegment {
  if (road.sections.length === 0) {
    // 百度仅在存在拥堵区段时返回该数组：空 = 整段畅通
    return { saturation: FREE_SATURATION, clear: true, queue: 0, approach: null, note: '实测畅通' };
  }

  // 长道路被切成多段播报时，用方位词（东段/西段…）把拥堵落到具体路段
  let target: RealtimeSection | undefined = road.sections.find((item) => matchSectionSegment(item.desc, seg.name));
  if (target === undefined) {
    // 描述未指明方位：取最拥堵的一段，按长度占比分摊影响
    target = road.sections.reduce((worst, item) => (item.status > worst.status ? item : worst));
  }

  const raw: number = saturationFromSpeed(target.speed);
  const bounded: number = boundByStatus(raw, target.status);
  const withTrend: number = applyTrend(bounded, target.trend);
  // 只堵一小段时整段平均饱和度不该被拉满
  const weight: number = congestionWeight(target.congestionDistance, segLength);
  const saturation: number = FREE_SATURATION + (withTrend - FREE_SATURATION) * weight;

  return {
    saturation: Number(saturation.toFixed(2)),
    clear: false,
    queue: queueFromDistance(target.congestionDistance * weight),
    approach: target.approach,
    note: sectionNote(target)
  };
}

/** 实测细节文案：方向 · 拥堵长度 · 趋势 · 车速 */
export function sectionNote(section: RealtimeSection): string {
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

/**
 * 相邻路口相对本路口的方位 → 本路口对应的进口道
 *
 * 例：邻居在东侧 → 车辆从东边驶入 → EAST 进口
 */
export function approachTo(origin: Intersection, neighbor: Intersection): ApproachDir {
  const dx: number = neighbor.longitude - origin.longitude;
  const dy: number = neighbor.latitude - origin.latitude;
  if (Math.abs(dx) >= Math.abs(dy)) {
    return dx < 0 ? 'WEST' : 'EAST';
  }
  return dy < 0 ? 'SOUTH' : 'NORTH';
}
