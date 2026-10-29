/**
 * 研究区域：西安城墙内片区
 * 用于经纬度与画布坐标的线性映射
 */
export class AreaConstants {
  static readonly AREA_NAME: string = '西安城墙内';
  static readonly AREA_DESC: string = '约 11.3 km²，15 个信号路口';

  /** 区域边界 */
  static readonly MIN_LON: number = 108.9286;
  static readonly MAX_LON: number = 108.9774;
  static readonly MIN_LAT: number = 34.2478;
  static readonly MAX_LAT: number = 34.2768;

  /** 中心点：钟楼 */
  static readonly CENTER_LON: number = 108.9470;
  static readonly CENTER_LAT: number = 34.2606;

  /** 画布内边距（vp） */
  static readonly CANVAS_PADDING: number = 28;

  /**
   * 经纬度 → 画布坐标
   * 纬度方向需翻转：纬度越大越靠北，画布 y 越小
   */
  static lonToX(lon: number, width: number): number {
    const ratio: number = (lon - AreaConstants.MIN_LON) / (AreaConstants.MAX_LON - AreaConstants.MIN_LON);
    return AreaConstants.CANVAS_PADDING + ratio * (width - AreaConstants.CANVAS_PADDING * 2);
  }

  static latToY(lat: number, height: number): number {
    const ratio: number = (lat - AreaConstants.MIN_LAT) / (AreaConstants.MAX_LAT - AreaConstants.MIN_LAT);
    return height - AreaConstants.CANVAS_PADDING - ratio * (height - AreaConstants.CANVAS_PADDING * 2);
  }
}
