/**
 * 全局配置：所有可调参数集中在此，避免在业务代码里出现魔法数字。
 *
 * ★ 口径必须与端侧保持一致：
 *   - 端侧算法：entry/src/main/ets/mock/XianWallMock.ets
 *   - 端侧指标：entry/src/main/ets/common/utils/TrafficUtil.ets
 *   任一侧修改参数，另一侧必须同步，否则前后端算出的周期会不一致。
 */

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/** 研究区域 */
export const AREA = {
  NAME: '西安城墙内',
  DESC: '约 11.3 km²，20 个信号路口'
} as const;

/** 交通流与指标参数 */
export const TRAFFIC = {
  /** 单车道饱和流率（辆/h） */
  SATURATION_FLOW: 1650,
  /** 展示用绿信比：饱和度与配时互为因果，这里取典型值解耦（已知近似，见设计文档 §10.7） */
  DISPLAY_GREEN_RATIO: 0.48,
  /** 排队长度拟合系数：queue = saturation² × 14 */
  QUEUE_COEFF: 14,
  /** 延误拟合：delay = saturation × 45 + 6 */
  DELAY_COEFF: 45,
  DELAY_BASE: 6,
  /** 自由流车速（km/h），用于由饱和度换算平均车速 */
  FREE_FLOW_SPEED: 45,
  /** 饱和度达到该值时车速归零 */
  SPEED_SAT_THRESHOLD: 1.6,
  /** 拥堵指数上限 */
  MAX_INDEX: 10
} as const;

/** 信号配时参数（Webster） */
export const SIGNAL = {
  /** 总损失时间 L = 4 相位 ×(黄灯 3s + 全红 1s) = 16s */
  LOST_TIME: 16,
  YELLOW: 3,
  ALL_RED: 1,
  /** 周期上下限 */
  MIN_CYCLE: 60,
  MAX_CYCLE: 150,
  /** 最小绿灯：直行 10s、左转 8s */
  MIN_GREEN_THROUGH: 10,
  MIN_GREEN_LEFT: 8,
  /** 流量比之和上限，过饱和保护 */
  Y_MAX: 0.92,
  /** 左转流量比按直行的比例折算（仿真未拆分转向流量） */
  LEFT_TURN_RATIO: 0.3,
  /** 优化前基线：固定配时周期与绿信比（演示性基线，见设计文档 §10.7） */
  BEFORE_CYCLE: 120,
  BEFORE_GREEN_RATIO: 0.42
} as const;

/** 时段场景 → 仿真小时数（不传场景时按系统当前时间） */
export const SCENARIO_HOURS: Readonly<Record<string, number>> = {
  早高峰: 8,
  平峰: 13,
  晚高峰: 18
};

export const SERVER = {
  PORT: Number(process.env.PORT ?? 8080),
  HOST: process.env.HOST ?? '0.0.0.0',
  /** 接口前缀 */
  API_PREFIX: '/api/v1'
} as const;

/**
 * 读取 server/.env（零依赖，仅本地开发用；生产环境用系统环境变量）
 * 只填充 process.env 中尚不存在的键，系统环境变量优先。
 */
function loadLocalEnv(): void {
  try {
    const content: string = readFileSync(join(process.cwd(), '.env'), 'utf-8');
    for (const line of content.split(/\r?\n/)) {
      const m: RegExpMatchArray | null = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m !== null && process.env[m[1]] === undefined) {
        process.env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
      }
    }
  } catch {
    // 无 .env 文件时忽略
  }
}
loadLocalEnv();

/** 百度地图实时路况（/traffic/v1/road，按道路名 + 城市查询） */
export const BAIDU = {
  BASE: 'https://api.map.baidu.com',
  /** AK 从 server/.env 读取（BAIDU_AK=xxx），.env 不进 Git */
  AK: process.env.BAIDU_AK ?? '',
  /** 查询城市（可用城市名或 adcode 610113 等，城墙内统一用市名） */
  CITY: '西安',
  /** 路况缓存毫秒：全量 20 条道路一次，1 分钟内直接复用，避免打爆配额 */
  CACHE_MS: 60_000,
  /** 单请求超时 */
  TIMEOUT_MS: 5_000
} as const;
