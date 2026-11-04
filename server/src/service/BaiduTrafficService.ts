import { BAIDU } from '../config.js';
import { SEG_TO_BAIDU_ROADS } from '../data/baiduRoads.js';
import { SEGMENTS } from '../data/network.js';
import type { RoadSegment } from '../types/intersection.js';

/**
 * 百度地图实时路况服务
 *
 * 接口：GET https://api.map.baidu.com/traffic/v1/road?road_name=&city=&ak=
 * 状态码：0 未知 / 1 畅通 / 2 缓行 / 3 拥堵 / 4 严重拥堵
 * 映射：百度 1 → 端侧 0（畅通），2 → 1（缓行），3/4 → 2（拥堵）
 *
 * 降级策略：某条道路查询失败只记 failedRoads，不影响其余道路；
 * AK 未配置或全部失败时 ok=false，端侧继续用确定性仿真数据。
 */

/** 百度拥堵路段（无拥堵时 congestion_sections 可能缺省） */
interface BaiduSection {
  status?: number;
  speed?: number;
  congestion_distance?: number;
  section_desc?: string;
}

/** 百度道路响应体（只声明用到的字段） */
interface BaiduRoadResponse {
  status: number;
  message?: string;
  description?: string;
  evaluation?: { status?: number; status_desc?: string };
  road_traffic?: Array<{ road_name?: string; congestion_sections?: BaiduSection[] }>;
}

/** 端侧需要的单路段实时路况 */
export interface RealtimeRoad {
  segId: string;
  segName: string;
  roadName: string;
  /** 三档：0 畅通 / 1 缓行 / 2 拥堵（与端侧着色口径一致） */
  level: number;
  /** 百度原始状态码 0~4，端侧可用于展示细节 */
  baiduStatus: number;
  /** 区段平均车速 km/h，无拥堵路段时为 null */
  speed: number | null;
  /** 拥堵距离 m */
  congestionDistance: number | null;
  /** 百度语义化描述（道路整体） */
  desc: string;
}

export interface RealtimeSnapshot {
  /** 是否拿到至少一条真实数据 */
  ok: boolean;
  /** AK 是否已配置（未配置时端侧应直接走仿真） */
  configured: boolean;
  ts: number;
  roads: RealtimeRoad[];
  /** 查询失败的道路（含"百度库无此路名"），排查映射用 */
  failedRoads: string[];
}

/** 百度状态 → 端侧三档 */
function toLevel(baiduStatus: number): number {
  if (baiduStatus <= 1) {
    return 0;
  }
  return baiduStatus === 2 ? 1 : 2;
}

/** 缓存：60 s 内全量复用，控制配额消耗 */
let cache: { ts: number; snapshot: RealtimeSnapshot } | null = null;

/** 限流等待重试参数 */
const RATE_LIMIT_RETRY_MS: number = 2000;
const RATE_LIMIT_RETRY_MAX: number = 2;
const SERIAL_GAP_MS: number = 250;

function isRateLimited(resp: BaiduRoadResponse | null): boolean {
  return resp !== null && resp.status !== 0 && (resp.message ?? '').includes('并发');
}

/** 单条道路查询（按候选名顺序尝试；限流时等待重试；失败返回 null） */
async function fetchRoad(candidates: readonly string[]): Promise<BaiduRoadResponse | null> {
  for (const roadName of candidates) {
    const url: string = `${BAIDU.BASE}/traffic/v1/road?road_name=${encodeURIComponent(roadName)}`
      + `&city=${encodeURIComponent(BAIDU.CITY)}&ak=${BAIDU.AK}`;
    for (let retry = 0; retry <= RATE_LIMIT_RETRY_MAX; retry++) {
      try {
        const response: Response = await fetch(url, { signal: AbortSignal.timeout(BAIDU.TIMEOUT_MS) });
        if (!response.ok) {
          break;
        }
        const json = (await response.json()) as BaiduRoadResponse;
        if (json.status === 0) {
          return json;
        }
        if (!isRateLimited(json)) {
          break; // road_name 错误等，换下一个候选名
        }
        // 限流：等待后重试
        await new Promise((resolve) => setTimeout(resolve, RATE_LIMIT_RETRY_MS));
      } catch {
        break; // 网络/超时，换下一个候选名
      }
    }
    await new Promise((resolve) => setTimeout(resolve, SERIAL_GAP_MS));
  }
  return null;
}

/** 道路响应 → 该道路的level/status/speed 聚合（取最差区段） */
function summarizeRoad(resp: BaiduRoadResponse, roadName: string): Omit<RealtimeRoad, 'segId' | 'segName'> {
  const sections: BaiduSection[] = resp.road_traffic?.[0]?.congestion_sections ?? [];
  let worst: number = resp.evaluation?.status ?? 0;
  let speed: number | null = null;
  let distance: number | null = null;
  for (const section of sections) {
    const s: number = section.status ?? 0;
    if (s > worst) {
      worst = s;
    }
    if (s >= 2) {
      // 只取拥堵区段的车速；更堵的优先
      if (worst === s && section.speed !== undefined) {
        speed = section.speed;
      }
      if (section.congestion_distance !== undefined) {
        distance = (distance ?? 0) + section.congestion_distance;
      }
    }
  }
  return {
    roadName: roadName,
    level: toLevel(worst),
    baiduStatus: worst,
    speed: speed,
    congestionDistance: distance,
    desc: resp.description ?? resp.evaluation?.status_desc ?? ''
  };
}

const SEG_NAME: Readonly<Record<string, string>> =
  Object.fromEntries(SEGMENTS.map((seg: RoadSegment) => [seg.id, seg.name]));

export class BaiduTrafficService {
  /** 全量实时路况：20 条道路分批并发 → 聚合回 32 条路段 */
  async getRealtimeRoads(force: boolean = false): Promise<RealtimeSnapshot> {
    const configured: boolean = BAIDU.AK.length > 0;
    if (!configured) {
      return { ok: false, configured: false, ts: Date.now(), roads: [], failedRoads: [] };
    }
    if (!force && cache !== null && Date.now() - cache.ts < BAIDU.CACHE_MS) {
      return cache.snapshot;
    }

    // 串行查询（个人 AK 的 QPS 配额低，2026-11-04 实测并发会触发限流）
    const failed: string[] = [];
    const roadInfo: Map<string, Omit<RealtimeRoad, 'segId' | 'segName'>> = new Map();
    const seen: Set<string> = new Set();
    for (const names of Object.values(SEG_TO_BAIDU_ROADS)) {
      const key: string = names[0];
      if (seen.has(key)) {
        continue;
      }
      seen.add(key);
      const resp: BaiduRoadResponse | null = await fetchRoad(names);
      if (resp === null) {
        failed.push(`${key}(未命中或失败)`);
        continue;
      }
      roadInfo.set(key, summarizeRoad(resp, key));
    }

    // 道路级 → 路段级
    const roads: RealtimeRoad[] = [];
    for (const seg of SEGMENTS) {
      const baiduName: string | undefined = SEG_TO_BAIDU_ROADS[seg.id]?.[0];
      if (baiduName === undefined) {
        continue;
      }
      const info = roadInfo.get(baiduName);
      if (info === undefined) {
        continue; // 该道路查询失败，端侧对此段回落仿真
      }
      roads.push({
        segId: seg.id,
        segName: seg.name,
        level: info.level,
        baiduStatus: info.baiduStatus,
        speed: info.speed,
        congestionDistance: info.congestionDistance,
        desc: info.desc,
        roadName: baiduName
      });
    }

    const snapshot: RealtimeSnapshot = {
      ok: roads.length > 0,
      configured: true,
      ts: Date.now(),
      roads: roads,
      failedRoads: failed
    };
    cache = { ts: snapshot.ts, snapshot: snapshot };
    return snapshot;
  }
}
