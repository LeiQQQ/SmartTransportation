import type { ApproachDir } from './intersection.js';

/**
 * 百度实时路况的对外结构（含拥堵区段明细）
 *
 * 字段来源：GET /traffic/v1/road 的 congestion_sections[]
 * 文档要点：该数组**仅在存在拥堵路段时返回**；无拥堵说明整条路畅通。
 */

/** 拥堵区段明细（对应百度 congestion_sections[]） */
export interface RealtimeSection {
  /** 区段路况等级：1 畅通 / 2 缓行 / 3 拥堵 / 4 严重拥堵 */
  status: number;
  /** 区段平均通行速度 km/h */
  speed: number;
  /** 拥堵距离 m */
  congestionDistance: number;
  /** 较 10 分钟前趋势：持平 / 缓解 / 加重 */
  trend: string;
  /** 语义化描述，如 "西向东,环城南路东段附近" */
  desc: string;
  /** 由 desc 解析出的进口道（到达端路口），无方向信息时为 null */
  approach: ApproachDir | null;
}

/** 端侧需要的单路段实时路况 */
export interface RealtimeRoad {
  segId: string;
  segName: string;
  /** 百度库中的道路名 */
  roadName: string;
  /** 三档：0 畅通 / 1 缓行 / 2 拥堵（与端侧着色口径一致） */
  level: number;
  /** 百度原始状态码 0~4，端侧可用于展示细节 */
  baiduStatus: number;
  /** 区段平均车速 km/h，无拥堵区段时为 null */
  speed: number | null;
  /** 拥堵距离 m */
  congestionDistance: number | null;
  /** 百度语义化描述（道路整体） */
  desc: string;
  /** 拥堵区段明细，畅通时为空数组 */
  sections: RealtimeSection[];
  /** 最差区段的趋势（持平/缓解/加重），无拥堵时为空串 */
  trend: string;
}

/** 一次全量快照 */
export interface RealtimeSnapshot {
  /** 是否拿到至少一条真实数据 */
  ok: boolean;
  /** AK 是否已配置（未配置时端侧应直接走仿真） */
  configured: boolean;
  ts: number;
  roads: RealtimeRoad[];
  /** 查询失败的道路（含"百度库无此路名"），排查映射用 */
  failedRoads: string[];
  /** 有拥堵区段的道路数（用于判断反推可信度） */
  congestedRoads: number;
}
