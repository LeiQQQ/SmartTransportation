/** 配时优化评价指标 */
export interface Metrics {
  /** 平均延误（秒/辆） */
  avgDelay: number;
  /** 平均排队（辆） */
  avgQueue: number;
  /** 通行量（辆/h） */
  throughput: number;
  /** 平均停车次数 */
  stops: number;
}

/** 优化前后对比 */
export interface Evaluation {
  intersectionId: string;
  /** 场景：早高峰 / 平峰 / 晚高峰 */
  scenario: string;
  before: Metrics;
  after: Metrics;
  /** 改善百分比，负值表示下降 */
  improvement: Metrics;
}
