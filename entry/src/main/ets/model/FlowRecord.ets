import { ApproachDir } from './Intersection';

/** 单进口道的实时交通状态 */
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
}

/** 单路口实时流量记录 */
export interface FlowRecord {
  intersectionId: string;
  /** 时间戳（毫秒） */
  timestamp: number;
  flows: ApproachFlow[];
}

/** 片区级拥堵指数 */
export interface AreaTrafficIndex {
  areaName: string;
  /** 0~10 */
  index: number;
  /** 平均车速 km/h */
  avgSpeed: number;
  /** 更新时间戳 */
  updateTime: number;
}
