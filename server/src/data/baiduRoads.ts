/**
 * 百度实时路况接入 · 路段映射
 *
 * 百度 /traffic/v1/road 按「道路名 + 城市」查询整条道路，
 * 项目内 32 条路段是分段的（北大街（北段）/（南段）…），多段共享一条道路的查询结果。
 * 映射口径：SEG 前缀 → 西安真实路名（百度库中的名字）。
 */

/** SEG 编号 → 百度道路名 */
export const SEG_TO_BAIDU_ROAD: Readonly<Record<string, string>> = {
  SEG_01: '北大街', SEG_02: '北大街',
  SEG_03: '南大街', SEG_04: '南大街',
  SEG_05: '西大街', SEG_06: '西大街', SEG_07: '西大街',
  SEG_08: '东大街', SEG_09: '东大街',
  SEG_31: '东关正街',
  SEG_10: '莲湖路', SEG_11: '莲湖路',
  SEG_12: '西五路', SEG_13: '东五路',
  SEG_14: '解放路', SEG_15: '和平路',
  SEG_16: '柏树林街', SEG_17: '洒金桥',
  SEG_18: '南四府街', SEG_19: '北院门街', SEG_20: '西华门大街',
  SEG_21: '环城北路', SEG_22: '环城北路',
  SEG_23: '环城西路', SEG_24: '环城西路',
  SEG_25: '环城南路', SEG_26: '环城南路', SEG_28: '环城南路', SEG_29: '环城南路',
  SEG_27: '环城东路', SEG_32: '环城东路',
  SEG_30: '南广济街'
};

/** 去重后的查询清单（20 条道路，每次全量刷新的请求数） */
export const BAIDU_ROADS: readonly string[] =
  [...new Set(Object.values(SEG_TO_BAIDU_ROAD))];
