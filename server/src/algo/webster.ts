import { SIGNAL } from '../config.js';

/**
 * Webster 最优周期与绿信比分配
 *
 * C₀ = (1.5L + 5) / (1 - Y)
 * g_i = (C₀ - L) × (y_i / Y)
 *
 * ★ 与端侧 XianWallMock.getSignalPlan() 口径一致：
 *   Y 上限 0.92、周期 clamp[60,150]、直行最小绿灯 10s、左转最小绿灯 8s、L=16
 */

export interface WebsterGreen {
  /** 相位1 东西直行 */
  throughEW: number;
  /** 相位2 东西左转 */
  leftEW: number;
  /** 相位3 南北直行 */
  throughNS: number;
  /** 相位4 南北左转 */
  leftNS: number;
}

export interface WebsterResult {
  cycleLength: number;
  lostTime: number;
  greens: WebsterGreen;
  /** 流量比之和（已做过饱和截断） */
  ySum: number;
}

/**
 * @param yEW 东西直行关键相位流量比
 * @param yNS 南北直行关键相位流量比
 */
export function calculate(yEW: number, yNS: number): WebsterResult {
  const yLeftEW: number = yEW * SIGNAL.LEFT_TURN_RATIO;
  const yLeftNS: number = yNS * SIGNAL.LEFT_TURN_RATIO;

  // 过饱和保护：Y 趋近 1 时周期趋于无穷，需截断
  const ySum: number = Math.min(SIGNAL.Y_MAX, yEW + yNS + yLeftEW + yLeftNS);

  const raw: number = (1.5 * SIGNAL.LOST_TIME + 5) / (1 - ySum);
  const cycleLength: number = Math.max(SIGNAL.MIN_CYCLE, Math.min(SIGNAL.MAX_CYCLE, Math.round(raw)));

  const effective: number = cycleLength - SIGNAL.LOST_TIME;
  const alloc = (y: number, minGreen: number): number =>
    Math.max(minGreen, Math.round((effective * y) / ySum));

  return {
    cycleLength: cycleLength,
    lostTime: SIGNAL.LOST_TIME,
    greens: {
      throughEW: alloc(yEW, SIGNAL.MIN_GREEN_THROUGH),
      leftEW: alloc(yLeftEW, SIGNAL.MIN_GREEN_LEFT),
      throughNS: alloc(yNS, SIGNAL.MIN_GREEN_THROUGH),
      leftNS: alloc(yLeftNS, SIGNAL.MIN_GREEN_LEFT)
    },
    ySum: ySum
  };
}
