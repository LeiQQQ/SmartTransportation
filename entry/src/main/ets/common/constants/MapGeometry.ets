/**
 * 地图几何数据：城墙轮廓、绿地、道路走向折线
 *
 * 用途：仅用于「片区路况」页的 Canvas 绘制，让路网呈现真实地图形态，不参与任何算法计算。
 * 坐标系：与 AreaConstants 一致（近似 WGS84），随 AreaConstants 边界变化自动适配。
 *
 * 说明：道路折线按实际走向给出拐点（尤其环城路沿城墙绕行为矩形），
 * 未定义折线的路段自动回退为「起点—终点」直线，因此新增路段不会导致绘制失败。
 */

/** 经纬度点 */
export interface LonLat {
  lon: number;
  lat: number;
}

/** 面状要素（绿地、广场等） */
interface Shape {
  name: string;
  points: LonLat[];
}

/** 道路折线 */
interface RoadGeom {
  id: string;
  points: LonLat[];
}

export class MapGeometry {
  /** 城墙围合区域（顺时针：西南→东南→东北→西北），略内于环城路 */
  static readonly WALL: LonLat[] = [
    MapGeometry.point(108.9320, 34.2520),
    MapGeometry.point(108.9675, 34.2520),
    MapGeometry.point(108.9675, 34.2732),
    MapGeometry.point(108.9320, 34.2732)
  ];

  /** 环城公园外缘：先填绿，再被城墙内地块覆盖，形成一圈绿化带 */
  static readonly PARK_BELT: LonLat[] = [
    MapGeometry.point(108.9275, 34.2478),
    MapGeometry.point(108.9718, 34.2478),
    MapGeometry.point(108.9718, 34.2775),
    MapGeometry.point(108.9275, 34.2775)
  ];

  /** 城内绿地与广场 */
  static readonly GREENS: Shape[] = [
    {
      name: '莲湖公园',
      points: [
        MapGeometry.point(108.9360, 34.2660),
        MapGeometry.point(108.9425, 34.2660),
        MapGeometry.point(108.9425, 34.2698),
        MapGeometry.point(108.9360, 34.2698)
      ]
    } as Shape,
    {
      name: '碑林·书院门',
      points: [
        MapGeometry.point(108.9500, 34.2515),
        MapGeometry.point(108.9575, 34.2515),
        MapGeometry.point(108.9575, 34.2565),
        MapGeometry.point(108.9500, 34.2565)
      ]
    } as Shape,
    {
      name: '钟楼广场',
      points: [
        MapGeometry.point(108.9486, 34.2608),
        MapGeometry.point(108.9504, 34.2608),
        MapGeometry.point(108.9504, 34.2622),
        MapGeometry.point(108.9486, 34.2622)
      ]
    } as Shape,
    {
      name: '南门广场',
      points: [
        MapGeometry.point(108.9478, 34.2502),
        MapGeometry.point(108.9506, 34.2502),
        MapGeometry.point(108.9506, 34.2524),
        MapGeometry.point(108.9478, 34.2524)
      ]
    } as Shape
  ];

  /**
   * 道路折线（与 XianWallMock / server network.ts 的 SEG 编号一一对应）
   * 环城路给出拐点，使其沿城墙绕行；其余按实际走向的直线或折线
   */
  private static readonly ROADS: RoadGeom[] = [
    // —— 中轴：北大街—南大街 ——
    { id: 'SEG_01', points: [MapGeometry.point(108.9487, 34.2752), MapGeometry.point(108.9488, 34.2712)] } as RoadGeom,
    { id: 'SEG_02', points: [MapGeometry.point(108.9488, 34.2712), MapGeometry.point(108.9495, 34.2615)] } as RoadGeom,
    { id: 'SEG_03', points: [MapGeometry.point(108.9495, 34.2615), MapGeometry.point(108.9490, 34.2532)] } as RoadGeom,
    { id: 'SEG_04', points: [MapGeometry.point(108.9490, 34.2532), MapGeometry.point(108.9492, 34.2498)] } as RoadGeom,

    // —— 横轴：西大街—东大街 ——
    { id: 'SEG_05', points: [MapGeometry.point(108.9495, 34.2615), MapGeometry.point(108.9432, 34.2622)] } as RoadGeom,
    { id: 'SEG_06', points: [MapGeometry.point(108.9432, 34.2622), MapGeometry.point(108.9366, 34.2622)] } as RoadGeom,
    { id: 'SEG_07', points: [MapGeometry.point(108.9366, 34.2622), MapGeometry.point(108.9297, 34.2622)] } as RoadGeom,
    { id: 'SEG_08', points: [MapGeometry.point(108.9495, 34.2615), MapGeometry.point(108.9540, 34.2613)] } as RoadGeom,
    { id: 'SEG_09', points: [MapGeometry.point(108.9540, 34.2613), MapGeometry.point(108.9598, 34.2612)] } as RoadGeom,

    // —— 北部：莲湖路—西五路—东五路 ——
    { id: 'SEG_10', points: [MapGeometry.point(108.9297, 34.2706), MapGeometry.point(108.9332, 34.2708)] } as RoadGeom,
    { id: 'SEG_11', points: [MapGeometry.point(108.9332, 34.2708), MapGeometry.point(108.9488, 34.2712)] } as RoadGeom,
    { id: 'SEG_12', points: [MapGeometry.point(108.9488, 34.2712), MapGeometry.point(108.9578, 34.2710)] } as RoadGeom,
    { id: 'SEG_13', points: [MapGeometry.point(108.9578, 34.2710), MapGeometry.point(108.9696, 34.2698)] } as RoadGeom,

    // —— 东侧纵向 ——
    { id: 'SEG_14', points: [MapGeometry.point(108.9578, 34.2710), MapGeometry.point(108.9598, 34.2612)] } as RoadGeom,
    { id: 'SEG_15', points: [MapGeometry.point(108.9598, 34.2612), MapGeometry.point(108.9556, 34.2498)] } as RoadGeom,
    {
      id: 'SEG_16',
      points: [MapGeometry.point(108.9490, 34.2532), MapGeometry.point(108.9520, 34.2552), MapGeometry.point(108.9540, 34.2613)]
    } as RoadGeom,

    // —— 西侧纵向 ——
    { id: 'SEG_17', points: [MapGeometry.point(108.9332, 34.2708), MapGeometry.point(108.9366, 34.2622)] } as RoadGeom,
    {
      id: 'SEG_18',
      points: [MapGeometry.point(108.9366, 34.2622), MapGeometry.point(108.9382, 34.2560), MapGeometry.point(108.9416, 34.2498)]
    } as RoadGeom,

    // —— 回坊支路 ——
    { id: 'SEG_19', points: [MapGeometry.point(108.9432, 34.2622), MapGeometry.point(108.9436, 34.2650)] } as RoadGeom,
    { id: 'SEG_20', points: [MapGeometry.point(108.9436, 34.2650), MapGeometry.point(108.9495, 34.2615)] } as RoadGeom,

    // —— 环城路：沿城墙绕行 ——
    {
      id: 'SEG_21',
      points: [MapGeometry.point(108.9297, 34.2706), MapGeometry.point(108.9300, 34.2752), MapGeometry.point(108.9487, 34.2752)]
    } as RoadGeom,
    {
      id: 'SEG_22',
      points: [MapGeometry.point(108.9487, 34.2752), MapGeometry.point(108.9696, 34.2752), MapGeometry.point(108.9696, 34.2698)]
    } as RoadGeom,
    { id: 'SEG_23', points: [MapGeometry.point(108.9297, 34.2706), MapGeometry.point(108.9297, 34.2622)] } as RoadGeom,
    {
      id: 'SEG_24',
      points: [MapGeometry.point(108.9297, 34.2622), MapGeometry.point(108.9297, 34.2498), MapGeometry.point(108.9416, 34.2498)]
    } as RoadGeom,
    { id: 'SEG_25', points: [MapGeometry.point(108.9416, 34.2498), MapGeometry.point(108.9440, 34.2498)] } as RoadGeom,
    {
      id: 'SEG_28',
      points: [MapGeometry.point(108.9440, 34.2498), MapGeometry.point(108.9492, 34.2498)]
    } as RoadGeom,
    {
      id: 'SEG_26',
      points: [MapGeometry.point(108.9492, 34.2498), MapGeometry.point(108.9528, 34.2498)]
    } as RoadGeom,
    {
      id: 'SEG_29',
      points: [MapGeometry.point(108.9528, 34.2498), MapGeometry.point(108.9556, 34.2498)]
    } as RoadGeom,
    {
      id: 'SEG_27',
      points: [MapGeometry.point(108.9556, 34.2498), MapGeometry.point(108.9696, 34.2498), MapGeometry.point(108.9696, 34.2612)]
    } as RoadGeom,
    {
      // 东大街东延：大差市出城至东门长乐门
      id: 'SEG_31',
      points: [MapGeometry.point(108.9598, 34.2612), MapGeometry.point(108.9696, 34.2612)]
    } as RoadGeom,
    {
      // 环城东路北段：长乐门沿东墙北上至朝阳门
      id: 'SEG_32',
      points: [MapGeometry.point(108.9696, 34.2612), MapGeometry.point(108.9696, 34.2698)]
    } as RoadGeom,
    {
      // 南广济街：西大街广济街口向南至南城墙湘子庙街口
      id: 'SEG_30',
      points: [
        MapGeometry.point(108.9432, 34.2622),
        MapGeometry.point(108.9445, 34.2560),
        MapGeometry.point(108.9440, 34.2498)
      ]
    } as RoadGeom
  ];

  /**
   * 取路段折线；未定义时返回空数组，调用方回退为「起点—终点」直线
   */
  static pointsOf(segmentId: string): LonLat[] {
    for (let i = 0; i < MapGeometry.ROADS.length; i++) {
      if (MapGeometry.ROADS[i].id === segmentId) {
        return MapGeometry.ROADS[i].points;
      }
    }
    return [];
  }

  /** 需要显示名称的主要路口（全部显示会过于拥挤） */
  static readonly MAIN_NODES: string[] = [
    'INT_01', 'INT_02', 'INT_04', 'INT_05', 'INT_09', 'INT_10', 'INT_12', 'INT_15', 'INT_20'
  ];

  /**
   * 主干道路段白名单：只有这些路段标注路况色带与路名
   * 次干与支路（书院门·柏树林、南四府街、北院门街、西华门大街）保持素面，避免图面花乱
   */
  private static readonly TRUNK_ROADS: string[] = [
    'SEG_01', 'SEG_02', 'SEG_03', 'SEG_04', 'SEG_05', 'SEG_06', 'SEG_07', 'SEG_08',
    'SEG_09', 'SEG_10', 'SEG_11', 'SEG_12', 'SEG_13', 'SEG_14', 'SEG_15',
    'SEG_17', 'SEG_21', 'SEG_22', 'SEG_23', 'SEG_24', 'SEG_25', 'SEG_26', 'SEG_27',
    'SEG_28', 'SEG_29', 'SEG_30', 'SEG_31', 'SEG_32'
  ];

  /** 是否主干路段（决定是否标注路况与路名） */
  static isTrunk(segmentId: string): boolean {
    for (let i = 0; i < MapGeometry.TRUNK_ROADS.length; i++) {
      if (MapGeometry.TRUNK_ROADS[i] === segmentId) {
        return true;
      }
    }
    return false;
  }

  /** 构造经纬度点 */
  static point(lon: number, lat: number): LonLat {
    return { lon: lon, lat: lat } as LonLat;
  }
}
