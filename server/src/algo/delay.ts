/**
 * Webster 延误模型
 *
 * d = C(1-λ)² / [2(1-λx)]  +  x² / [2q(1-x)]
 *     └── 均匀延误 ──┘       └── 随机附加延误 ──┘
 *
 * ★ 与端侧 XianWallMock.websterDelay() 口径一致（x ≤ 0.95、q ≥ 0.05 截断）
 *
 * @param cycleLength 周期（秒）
 * @param greenRatio  绿信比 λ
 * @param saturation  饱和度 v/c
 * @param volumePerHour 流量（辆/h）
 */
export function websterDelay(cycleLength: number, greenRatio: number,
  saturation: number, volumePerHour: number): number {
  const x: number = Math.min(0.95, saturation);
  const q: number = Math.max(0.05, volumePerHour / 3600); // 辆/s

  const uniform: number = (cycleLength * Math.pow(1 - greenRatio, 2)) / (2 * (1 - greenRatio * x));
  const random: number = Math.pow(x, 2) / (2 * q * (1 - x));
  return uniform + random;
}
