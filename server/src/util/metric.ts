/**
 * 指标换算工具
 * 与端侧 entry/src/main/ets/common/utils/TrafficUtil.ets 中的同名方法口径一致
 */

/** 通行能力 = 饱和流率 × 车道数 × 绿信比 */
export function capacityOf(saturationFlow: number, lanes: number, greenRatio: number): number {
  return saturationFlow * lanes * greenRatio;
}

/** 饱和度 = 流量 / 通行能力 */
export function saturationOf(volume: number, capacity: number): number {
  if (capacity <= 0) {
    return 1;
  }
  return volume / capacity;
}

/** 变化百分比：正值上升，负值下降；基数为 0 时返回 0 */
export function percent(before: number, after: number): number {
  if (before === 0) {
    return 0;
  }
  return Number((((after - before) / before) * 100).toFixed(1));
}

/** 保留一位小数 */
export function round1(value: number): number {
  return Number(value.toFixed(1));
}

/** 保留两位小数 */
export function round2(value: number): number {
  return Number(value.toFixed(2));
}
