import { ThemeConstants } from '../constants/ThemeConstants';

/**
 * 交通指标换算工具
 */
export class TrafficUtil {
  /**
   * 饱和度 → 拥堵等级
   * 0 畅通 / 1 基本畅通 / 2 轻度 / 3 中度 / 4 严重
   */
  static levelOfSaturation(saturation: number): number {
    if (saturation < 0.4) {
      return 0;
    }
    if (saturation < 0.6) {
      return 1;
    }
    if (saturation < 0.75) {
      return 2;
    }
    if (saturation < 0.9) {
      return 3;
    }
    return 4;
  }

  static colorOfLevel(level: number): string {
    switch (level) {
      case 0:
        return ThemeConstants.LEVEL_CLEAR;
      case 1:
        return ThemeConstants.LEVEL_BASIC;
      case 2:
        return ThemeConstants.LEVEL_LIGHT;
      case 3:
        return ThemeConstants.LEVEL_MODERATE;
      case 4:
        return ThemeConstants.LEVEL_SEVERE;
      default:
        return ThemeConstants.LEVEL_CLEAR;
    }
  }

  static colorOfSaturation(saturation: number): string {
    return TrafficUtil.colorOfLevel(TrafficUtil.levelOfSaturation(saturation));
  }

  static levelName(level: number): string {
    const names: string[] = ['畅通', '基本畅通', '轻度拥堵', '中度拥堵', '严重拥堵'];
    if (level < 0 || level > 4) {
      return '畅通';
    }
    return names[level];
  }

  /**
   * 拥堵指数（0~10）→ 等级
   */
  static levelOfIndex(index: number): number {
    if (index < 2) {
      return 0;
    }
    if (index < 4) {
      return 1;
    }
    if (index < 6) {
      return 2;
    }
    if (index < 8) {
      return 3;
    }
    return 4;
  }

  /**
   * 由流量、饱和流率、绿信比估算通行能力与饱和度
   */
  static capacityOf(saturationFlow: number, lanes: number, greenRatio: number): number {
    return saturationFlow * lanes * greenRatio;
  }

  static saturationOf(volume: number, capacity: number): number {
    if (capacity <= 0) {
      return 1;
    }
    return volume / capacity;
  }

  /**
   * 由排队长度与流量粗估平均等待时间（秒），仅用于用户端展示
   */
  static estimateWaitSeconds(queueLength: number, volumePerHour: number): number {
    const passRate: number = volumePerHour <= 0 ? 0.3 : volumePerHour / 3600;
    if (passRate <= 0) {
      return 0;
    }
    return Math.round(queueLength / passRate);
  }

  /**
   * 绿信比保留两位小数
   */
  static greenRatioOf(green: number, cycle: number): string {
    if (cycle <= 0) {
      return '0.00';
    }
    return (green / cycle).toFixed(2);
  }
}
