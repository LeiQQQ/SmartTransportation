/**
 * 百度实时路况接入 · 路段映射
 *
 * 百度 /traffic/v1/road 按「道路名 + 城市」查询整条道路，
 * 项目内 32 条路段是分段的（北大街（北段）/（南段）…），多段共享一条道路的查询结果。
 * 映射口径：SEG 前缀 → 西安真实路名（百度库中的名字）。
 */

/**
 * SEG 编号 → 百度候选道路名（按序尝试，首个命中即用）
 * 2026-11-04 实测：北大街/南大街/西大街/东大街/莲湖路/解放路/和平路/西华门大街/
 * 环城北路/环城西路/环城东路/南广济街/西五路/东五路 直接命中；
 * 柏树林街/洒金桥/南四府街/北院门街 在百度库中写法不同，配候选名。
 */
export const SEG_TO_BAIDU_ROADS: Readonly<Record<string, readonly string[]>> = {
  SEG_01: ['北大街'], SEG_02: ['北大街'],
  SEG_03: ['南大街'], SEG_04: ['南大街'],
  SEG_05: ['西大街'], SEG_06: ['西大街'], SEG_07: ['西大街'],
  SEG_08: ['东大街'], SEG_09: ['东大街'],
  SEG_31: ['东关正街'],
  SEG_10: ['莲湖路'], SEG_11: ['莲湖路'],
  SEG_12: ['西五路'], SEG_13: ['东五路'],
  SEG_14: ['解放路'], SEG_15: ['和平路'],
  SEG_16: ['柏树林', '柏树林街'],
  SEG_17: ['洒金桥路'],
  SEG_18: ['四府街', '南四府街'],
  SEG_19: ['北院门', '北院门街'],
  SEG_20: ['西华门大街', '西华门'],
  SEG_21: ['环城北路'], SEG_22: ['环城北路'],
  SEG_23: ['环城西路'], SEG_24: ['环城西路'],
  SEG_25: ['环城南路'], SEG_26: ['环城南路'], SEG_28: ['环城南路'], SEG_29: ['环城南路'],
  SEG_27: ['环城东路'], SEG_32: ['环城东路'],
  SEG_30: ['南广济街']
};

/** 兼容旧引用：首候选名 */
export const SEG_TO_BAIDU_ROAD: Readonly<Record<string, string>> =
  Object.fromEntries(Object.entries(SEG_TO_BAIDU_ROADS).map(([seg, names]) => [seg, names[0]]));

/** 去重后的查询清单（每条道路的首候选名，20 条） */
export const BAIDU_ROADS: readonly string[] =
  [...new Set(Object.values(SEG_TO_BAIDU_ROADS).map((names) => names[0]))];
