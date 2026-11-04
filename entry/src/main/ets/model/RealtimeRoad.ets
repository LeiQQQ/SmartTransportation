/**
 * 路段级实时路况（来源：百度 /traffic/v1/road，经后端聚合）
 * 空数组表示无真实数据（AK 未配置/查询失败），端侧回落确定性仿真
 */
export interface RealtimeRoad {
  segId: string;
  segName: string;
  /** 命中的百度道路名 */
  roadName: string;
  /** 三档：0 畅通 / 1 缓行 / 2 拥堵（与着色口径一致） */
  level: number;
  /** 百度原始状态 0 未知 / 1 畅通 / 2 缓行 / 3 拥堵 / 4 严重拥堵 */
  baiduStatus: number;
  /** 拥堵区段平均车速 km/h（无拥堵为 undefined） */
  speed?: number;
  /** 拥堵距离 m */
  congestionDistance?: number;
  /** 百度语义化描述 */
  desc: string;
}
