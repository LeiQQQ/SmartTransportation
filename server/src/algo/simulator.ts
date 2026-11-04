import { TRAFFIC, AREA } from '../config.js';
import { capacityOf, saturationOf } from '../util/metric.js';
import type { ApproachFlow, AreaTrafficIndex, FlowRecord, Intersection } from '../types/index.js';

/**
 * 交通流仿真
 *
 * ★ 与端侧 entry/src/main/ets/mock/XianWallMock.ets 的
 *   pseudo / peakFactor / getFlows / getAreaIndex 逐条对应，口径必须一致。
 */

/**
 * 确定性伪随机：同一路口同一方向的结果稳定可复现
 * 避免每次请求数字乱跳，便于演示与调试
 */
export function pseudo(id: string, dir: string): number {
  const seed: string = `${id}_${dir}`;
  let hash: number = 7;
  for (let i = 0; i < seed.length; i++) {
    hash = (hash * 31 + seed.charCodeAt(i)) % 9973;
  }
  return hash / 9973;
}

/** 高斯双峰系数：早高峰 8 点、晚高峰 18 点 */
export function peakFactor(hour: number): number {
  const morning: number = Math.exp(-Math.pow(hour - 8, 2) / 4);
  const evening: number = Math.exp(-Math.pow(hour - 18, 2) / 4);
  return 0.35 + morning + evening;
}

/** 由时间戳取带小数的小时数，如 8.5 表示 8:30 */
export function hourOf(timestamp: number = Date.now()): number {
  const date: Date = new Date(timestamp);
  return date.getHours() + date.getMinutes() / 60;
}

/** 生成单个进口道的流量状态 */
export function buildApproachFlow(intersectionId: string, dir: string, saturationFlow: number,
  lanes: number, hour: number): ApproachFlow {
  const base: number = 480 + pseudo(intersectionId, dir) * 420; // 480 ~ 900 辆/h
  const volume: number = Math.round(base * peakFactor(hour));

  const capacity: number = capacityOf(saturationFlow, lanes, TRAFFIC.DISPLAY_GREEN_RATIO);
  const saturation: number = saturationOf(volume, capacity);

  return {
    dir: dir as ApproachFlow['dir'],
    volume: volume,
    queueLength: Math.round(saturation * saturation * TRAFFIC.QUEUE_COEFF),
    delay: Math.round(saturation * TRAFFIC.DELAY_COEFF + TRAFFIC.DELAY_BASE),
    saturation: saturation
  };
}

/** 生成单个路口的流量记录 */
export function buildFlowRecord(intersection: Intersection, hour: number,
  timestamp: number = Date.now()): FlowRecord {
  const flows: ApproachFlow[] = intersection.approaches.map((approach) =>
    buildApproachFlow(intersection.id, approach.dir, approach.saturationFlow, approach.lanes, hour)
  );
  return { intersectionId: intersection.id, timestamp: timestamp, flows: flows };
}

/** 片区拥堵指数：全部进口道饱和度的算术平均映射到 0~10 */
export function buildAreaIndex(records: FlowRecord[], timestamp: number = Date.now()): AreaTrafficIndex {
  let sum: number = 0;
  let count: number = 0;
  for (const record of records) {
    for (const flow of record.flows) {
      sum += flow.saturation;
      count++;
    }
  }
  const avg: number = count === 0 ? 0 : sum / count;
  return {
    areaName: AREA.NAME,
    index: Number(Math.min(TRAFFIC.MAX_INDEX, avg * 10).toFixed(1)),
    avgSpeed: Math.round(TRAFFIC.FREE_FLOW_SPEED * (1 - avg / TRAFFIC.SPEED_SAT_THRESHOLD)),
    updateTime: timestamp
  };
}

/**
 * 汇总若干进口道流量
 *
 * 同时给出平均值与最大值：
 * 配时看平均，**评价必须看关键进口道（最大饱和度）**——
 * 一条过饱和进口道被三条畅通进口道平均后会被稀释成"不堵"，
 * 导致优化效果被严重高估（实测驱动后尤其明显）。
 */
export function summarize(records: FlowRecord[]): {
  avgSaturation: number;
  maxSaturation: number;
  totalVolume: number;
} {
  let sum: number = 0;
  let max: number = 0;
  let volume: number = 0;
  let count: number = 0;
  for (const record of records) {
    for (const flow of record.flows) {
      sum += flow.saturation;
      volume += flow.volume;
      if (flow.saturation > max) {
        max = flow.saturation;
      }
      count++;
    }
  }
  return {
    avgSaturation: count === 0 ? 0.7 : sum / count,
    maxSaturation: count === 0 ? 0.7 : max,
    totalVolume: count === 0 ? 1200 : volume
  };
}
