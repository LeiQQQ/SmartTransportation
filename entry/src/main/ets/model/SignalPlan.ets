/** 信号相位 */
export interface SignalPhase {
  phaseId: number;
  name: string;
  /** 绿灯时长（秒） */
  green: number;
  /** 黄灯时长（秒） */
  yellow: number;
  /** 全红时长（秒） */
  allRed: number;
  /** 放行的进口道方向 */
  movements: string[];
}

/** 配时方案 */
export interface SignalPlan {
  intersectionId: string;
  planName: string;
  /** 周期时长（秒） */
  cycleLength: number;
  /** 总损失时间（秒） */
  lostTime: number;
  phases: SignalPhase[];
  /** 是否为优化后的方案 */
  optimized: boolean;
  /** 优化前周期，用于对比展示 */
  beforeCycleLength: number;
}
