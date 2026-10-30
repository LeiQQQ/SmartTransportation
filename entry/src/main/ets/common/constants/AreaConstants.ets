/**
 * 研究区域：西安城墙内片区
 * 用于经纬度与画布坐标的线性映射
 */
export class AreaConstants {
  static readonly AREA_NAME: string = '西安城墙内';
  static readonly AREA_DESC: string = '约 11.3 km²，20 个信号路口';

  /** 路网规模：仅用于界面展示文案，必须与 `mock/XianWallMock.ets` 及后端 `data/network.ts` 同步 */
  static readonly INTERSECTION_COUNT: number = 20;
  static readonly SEGMENT_COUNT: number = 32;

  /** 区域边界：城墙外扩约 300~400m，覆盖环城路一圈 */
  static readonly MIN_LON: number = 108.9262;
  static readonly MAX_LON: number = 108.9730;
  static readonly MIN_LAT: number = 34.2462;
  static readonly MAX_LAT: number = 34.2788;

  /** 中心点：钟楼 */
  static readonly CENTER_LON: number = 108.9495;
  static readonly CENTER_LAT: number = 34.2615;

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
