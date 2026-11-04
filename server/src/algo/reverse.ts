import { TRAFFIC } from '../config.js';
import type { ApproachDir } from '../types/index.js';

/**
 * 实测反推：把百度路况的「车速 / 拥堵距离 / 方向」换算成仿真所需的
 * 「饱和度 / 排队长度 / 进口道」，从而让信号配时由真实路况驱动。
 *
 * 依据（百度《道路实时路况查询》文档）：
 *   congestion_sections[].speed               区段平均通行速度 km/h
 *   congestion_sections[].congestion_distance 拥堵距离 m
 *   congestion_sections[].status              1 畅通 / 2 缓行 / 3 拥堵 / 4 严重拥堵
 *   congestion_sections[].congestion_trend    较 10 分钟前：持平 / 缓解 / 加重
 *   congestion_sections[].section_desc        "西向东,环城南路东段附近"
 */

/**
 * BPR 阻抗函数的标定参数
 *
 * 标准 BPR：t = t0 · (1 + α·x^β)，速度形式 v = v0 / (1 + α·x^β)
 * α 取 0.15 是高速路标定值，城市道路低速段过于陡峭（40 km/h 就算出 x≈0.96），
 * 这里取 α=0.5 使反推结果与实测拥堵感受一致：
 *   40 km/h → x≈0.71（接近畅通）  25 km/h → x≈1.12（缓行偏饱和）  14 km/h → x≈1.45（拥堵）
 */
const BPR_ALPHA: number = 0.5;
const BPR_BETA: number = 4;

/** 平均车头间距（米/辆）：拥堵车流约 7~8 米一辆，用于拥堵距离 → 排队车辆数 */
const HEADWAY_M: number = 7.5;

/** 畅通时的饱和度基线（百度不返回畅通区段车速，只能取经验值） */
export const FREE_SATURATION: number = 0.4;

/** 趋势因子：加重则略微上调饱和度，缓解则下调，用于体现"路况在变化" */
const TREND_DELTA: number = 0.05;

export function clamp(value: number, low: number, high: number): number {
  return value < low ? low : (value > high ? high : value);
}

/**
 * 由实测车速反推饱和度（BPR 反函数）
 *
 * x = ((v0 / v - 1) / α)^(1/β)
 */
export function saturationFromSpeed(speed: number): number {
  if (!Number.isFinite(speed) || speed <= 0) {
    return TRAFFIC.SPEED_SAT_THRESHOLD; // 车速缺失/为 0：按最饱和处理
  }
  const ratio: number = TRAFFIC.FREE_FLOW_SPEED / speed;
  if (ratio <= 1) {
    return FREE_SATURATION; // 达到或超过自由流车速
  }
  const x: number = Math.pow((ratio - 1) / BPR_ALPHA, 1 / BPR_BETA);
  return clamp(x, 0.2, TRAFFIC.SPEED_SAT_THRESHOLD);
}

/**
 * 用百度路况等级给饱和度设合理区间
 * 车速偶有异常（如隧道/桥梁无信号），等级是更稳的先验
 */
export function boundByStatus(x: number, status: number): number {
  let low: number = 0.2;
  let high: number = TRAFFIC.SPEED_SAT_THRESHOLD;
  if (status <= 1) {
    low = 0.2;
    high = 0.55;
  } else if (status === 2) {
    low = 0.55;
    high = 1.0;
  } else if (status === 3) {
    low = 1.0;
    high = 1.35;
  } else if (status >= 4) {
    low = 1.35;
    high = TRAFFIC.SPEED_SAT_THRESHOLD;
  }
  return clamp(x, low, high);
}

/** 拥堵距离 → 排队车辆数 */
export function queueFromDistance(meters: number): number {
  if (!Number.isFinite(meters) || meters <= 0) {
    return 0;
  }
  return Math.round(meters / HEADWAY_M);
}

/** 趋势调整：加重 +0.05，缓解 -0.05，持平/未知不变 */
export function applyTrend(x: number, trend: string): number {
  if (trend.includes('加重')) {
    return clamp(x + TREND_DELTA, 0.2, TRAFFIC.SPEED_SAT_THRESHOLD);
  }
  if (trend.includes('缓解')) {
    return clamp(x - TREND_DELTA, 0.2, TRAFFIC.SPEED_SAT_THRESHOLD);
  }
  return x;
}

/**
 * 解析 section_desc 中的行驶方向，返回到达端路口对应的进口道
 *
 * "东向西" = 车向西行驶，从东侧驶入西端路口 → 该路口的 EAST 进口
 * "南向北" = 车向北行驶，从南侧驶入北端路口 → SOUTH 进口
 */
export function approachFromDesc(desc: string): ApproachDir | null {
  const m: RegExpMatchArray | null = desc.match(/(东|西|南|北)\s*向\s*(东|西|南|北)/);
  if (m === null) {
    return null;
  }
  const to: string = m[2];
  if (to === '西') {
    return 'EAST';
  }
  if (to === '东') {
    return 'WEST';
  }
  if (to === '南') {
    return 'NORTH';
  }
  return 'SOUTH';
}

/** 两点间距离（米），Haversine */
export function distanceMeters(lon1: number, lat1: number, lon2: number, lat2: number): number {
  const R: number = 6371000;
  const toRad = (deg: number): number => (deg * Math.PI) / 180;
  const dLat: number = toRad(lat2 - lat1);
  const dLon: number = toRad(lon2 - lon1);
  const a: number = Math.sin(dLat / 2) * Math.sin(dLat / 2)
    + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) * Math.sin(dLon / 2);
  return 2 * R * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * 区段描述与路段名的方向匹配
 * 百度 "环城南路东段附近" ↔ 项目 "环城南路（东段）"
 * 长道路会被百度切成多段播报，靠方位词把拥堵落到具体路段上
 */
export function matchSectionSegment(desc: string, segName: string): boolean {
  const dirs: string[] = ['东段', '西段', '南段', '北段', '中段'];
  const inDesc: string = dirs.find((d) => desc.includes(d)) ?? '';
  if (inDesc === '') {
    return false; // 描述没给方位词，无法精确匹配到某一段
  }
  return segName.includes(inDesc);
}

/**
 * 局部拥堵对整段的影响权重：拥堵距离占路段全长的比例（上限 1）
 * 只堵一小段时，整段的平均饱和度不该被拉满
 */
export function congestionWeight(distance: number, segmentLength: number): number {
  if (segmentLength <= 0) {
    return 1;
  }
  return clamp(distance / segmentLength, 0.15, 1);
}
