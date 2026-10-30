import { TRAFFIC } from '../config.js';
import type { Approach, ApproachDir, Intersection, IntersectionType, RoadSegment } from '../types/index.js';

/**
 * 西安城墙内路网静态数据（20 个信号路口 + 32 条路段）
 * 四门：安远门（北）/ 长乐门（东）/ 永宁门（南）/ 安定门（西）
 *
 * 建模依据：依据公开地图（西安城墙内片区）目视核对主骨架道路，
 * 覆盖「四门 + 四条大街 + 环城路 + 莲湖路/西五路/东五路 + 解放路 + 和平路」等主干。
 *
 * 坐标说明：为主干路口中心点的近似值，用于拓扑展示与相对位置，非测绘级精度；
 * 地图底图为 GCJ-02 偏移坐标，本文件为近似 WGS84，两者差异在本项目尺度下不影响布局。
 *
 * ★ 与端侧 entry/src/main/ets/mock/XianWallMock.ets 的路口清单严格一致，id 不可随意改动。
 *   修改任一侧必须同步另一侧，否则前后端算出的流量与周期会对不上。
 */

const APPROACH_DIRS: readonly ApproachDir[] = ['EAST', 'WEST', 'SOUTH', 'NORTH'];

/** 构造路口：按进口道数量与车道数生成进口道列表 */
function buildIntersection(id: string, name: string, longitude: number, latitude: number,
  type: IntersectionType, approachCount: number, lanes: number): Intersection {
  const approaches: Approach[] = [];
  for (let i = 0; i < approachCount; i++) {
    approaches.push({ dir: APPROACH_DIRS[i], lanes: lanes, saturationFlow: TRAFFIC.SATURATION_FLOW });
  }
  return { id: id, name: name, longitude: longitude, latitude: latitude, type: type, approaches: approaches };
}

/**
 * [id, 名称, 经度, 纬度, 类型, 进口道数, 车道数]
 *
 * 进口道数按该路口实际受信号控制的方向数取值（含未单独建模的次要支路/出城道路），
 * 与路段连接数不必严格相等。
 */
const RAW_INTERSECTIONS: readonly (readonly [string, string, number, number, IntersectionType, number, number])[] = [
  // —— 四条大街交汇与中轴 ——
  ['INT_01', '钟楼', 108.9495, 34.2615, 'RING', 4, 3],
  ['INT_02', '北门·安远门', 108.9487, 34.2752, 'RING', 4, 3],
  ['INT_03', '北门十字', 108.9488, 34.2712, 'CROSS', 4, 3],
  ['INT_12', '南门·永宁门', 108.9492, 34.2498, 'RING', 4, 3],

  // —— 西大街沿线 ——
  ['INT_05', '西门·安定门', 108.9297, 34.2622, 'RING', 4, 2],
  ['INT_06', '桥梓口', 108.9366, 34.2622, 'CROSS', 4, 2],
  ['INT_07', '广济街', 108.9432, 34.2622, 'CROSS', 4, 2],

  // —— 东大街沿线（东端即东门长乐门）——
  ['INT_08', '端履门', 108.9540, 34.2613, 'CROSS', 4, 2],
  ['INT_09', '大差市', 108.9598, 34.2612, 'CROSS', 4, 3],
  ['INT_20', '长乐门', 108.9696, 34.2612, 'RING', 4, 3],

  // —— 北部横向 ——
  ['INT_04', '玉祥门', 108.9297, 34.2706, 'CROSS', 4, 2],
  ['INT_17', '洒金桥', 108.9332, 34.2708, 'CROSS', 4, 2],
  ['INT_10', '五路口', 108.9578, 34.2710, 'CROSS', 4, 3],
  ['INT_11', '朝阳门', 108.9696, 34.2698, 'CROSS', 4, 2],

  // —— 南部与环城路 ——
  ['INT_13', '书院门', 108.9490, 34.2532, 'T_SHAPE', 3, 2],
  ['INT_14', '朱雀门', 108.9416, 34.2498, 'CROSS', 3, 2],
  ['INT_18', '湘子庙街口', 108.9440, 34.2498, 'CROSS', 4, 2],
  ['INT_19', '文昌门', 108.9528, 34.2498, 'CROSS', 4, 2],
  ['INT_15', '和平门', 108.9556, 34.2498, 'CROSS', 4, 2],

  // —— 回坊 ——
  ['INT_16', '北院门', 108.9436, 34.2650, 'T_SHAPE', 3, 1]
];

/** [id, 名称, 起点路口, 终点路口, 车道数] */
const RAW_SEGMENTS: readonly (readonly [string, string, string, string, number])[] = [
  // 中轴：北大街—南大街
  ['SEG_01', '北大街（北段）', 'INT_02', 'INT_03', 3],
  ['SEG_02', '北大街（南段）', 'INT_03', 'INT_01', 3],
  ['SEG_03', '南大街（北段）', 'INT_01', 'INT_13', 2],
  ['SEG_04', '南大街（南段）', 'INT_13', 'INT_12', 2],

  // 横轴：西大街—东大街
  ['SEG_05', '西大街（东段）', 'INT_01', 'INT_07', 3],
  ['SEG_06', '西大街（中段）', 'INT_07', 'INT_06', 3],
  ['SEG_07', '西大街（西段）', 'INT_06', 'INT_05', 2],
  ['SEG_08', '东大街（西段）', 'INT_01', 'INT_08', 3],
  ['SEG_09', '东大街（东段）', 'INT_08', 'INT_09', 3],

  // 北部：莲湖路—西五路—东五路
  ['SEG_10', '莲湖路（西段）', 'INT_04', 'INT_17', 2],
  ['SEG_11', '莲湖路（东段）', 'INT_17', 'INT_03', 2],
  ['SEG_12', '西五路', 'INT_03', 'INT_10', 3],
  ['SEG_13', '东五路', 'INT_10', 'INT_11', 2],

  // 东侧：解放路、和平路、柏树林
  ['SEG_14', '解放路', 'INT_10', 'INT_09', 3],
  ['SEG_15', '和平路', 'INT_09', 'INT_15', 2],
  ['SEG_16', '书院门·柏树林', 'INT_13', 'INT_08', 1],

  // 西侧：洒金桥路、南四府街
  ['SEG_17', '洒金桥路', 'INT_17', 'INT_06', 2],
  ['SEG_18', '南四府街', 'INT_06', 'INT_14', 2],

  // 回坊支路
  ['SEG_19', '北院门街', 'INT_07', 'INT_16', 1],
  ['SEG_20', '西华门大街', 'INT_16', 'INT_01', 2],

  // 环城路（沿城墙一圈，段按城门切分）
  ['SEG_21', '环城北路（西段）', 'INT_04', 'INT_02', 3],
  ['SEG_22', '环城北路（东段）', 'INT_02', 'INT_11', 3],
  ['SEG_23', '环城西路', 'INT_04', 'INT_05', 3],
  ['SEG_24', '环城西路（南延）', 'INT_05', 'INT_14', 2],
  ['SEG_25', '环城南路（西段）', 'INT_14', 'INT_18', 3],
  ['SEG_26', '环城南路（中段东）', 'INT_12', 'INT_19', 3],
  ['SEG_27', '环城东路（南段）', 'INT_15', 'INT_20', 3],
  ['SEG_28', '环城南路（中段西）', 'INT_18', 'INT_12', 3],
  ['SEG_29', '环城南路（东段）', 'INT_19', 'INT_15', 3],
  ['SEG_30', '南广济街', 'INT_07', 'INT_18', 2],
  // 东门连接线：东大街东延出城 + 环城东路北段
  ['SEG_31', '东大街（东延）', 'INT_09', 'INT_20', 3],
  ['SEG_32', '环城东路（北段）', 'INT_20', 'INT_11', 3]
];

export const INTERSECTIONS: readonly Intersection[] = RAW_INTERSECTIONS.map((row) =>
  buildIntersection(row[0], row[1], row[2], row[3], row[4], row[5], row[6])
);

export const SEGMENTS: readonly RoadSegment[] = RAW_SEGMENTS.map((row) => ({
  id: row[0], name: row[1], fromId: row[2], toId: row[3], lanes: row[4]
}));

export function findIntersection(id: string): Intersection | undefined {
  return INTERSECTIONS.find((item) => item.id === id);
}
