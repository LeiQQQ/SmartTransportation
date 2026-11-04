import { ApproachDir } from './intersection.js';

/** 单进口道实时状态（对应端侧 ApproachFlow） */
export interface ApproachFlow {
  dir: ApproachDir;
  /** 流量（辆/h） */
  volume: number;
  /** 排队长度（辆） */
  queueLength: number;
  /** 平均延误（秒/辆） */
  delay: number;
  /** 饱和度 v/c */
  saturation: number;
  /**
   * 数据来源：BAIDU 由实测反推，SIM 为确定性仿真
   * 端侧据此标注可信度，避免把仿真数字当成实测（两者会明显不同）
   */
  source?: 'BAIDU' | 'SIM';
  /** 实测明细，如「东向西 · 590m · 加重 · 6km/h」；仿真时无此字段 */
  note?: string;
}

/** 单路口流量记录 */
export interface FlowRecord {
  intersectionId: string;
  /** 时间戳（毫秒） */
  timestamp: number;
  flows: ApproachFlow[];
}

/** 片区拥堵指数 */
export interface AreaTrafficIndex {
  areaName: string;
  /** 0~10 */
  index: number;
  /** 平均车速 km/h */
  avgSpeed: number;
  updateTime: number;
}
