import { BAIDU } from '../config.js';
import { SEG_TO_BAIDU_ROADS } from '../data/baiduRoads.js';
import { SEGMENTS } from '../data/network.js';
import { approachFromDesc } from '../algo/reverse.js';
import type { RealtimeRoad, RealtimeSection, RealtimeSnapshot } from '../types/index.js';

/**
 * 百度地图实时路况服务
 *
 * 接口：GET https://api.map.baidu.com/traffic/v1/road?road_name=&city=&ak=
 * 返回：evaluation（整体评价）+ road_traffic[].congestion_sections（拥堵区段明细）
 * 状态码：0 未知 / 1 畅通 / 2 缓行 / 3 拥堵 / 4 严重拥堵
 * 映射：百度 1 → 端侧 0（畅通），2 → 1（缓行），3/4 → 2（拥堵）
 *
 * 降级策略：某条道路查询失败只记 failedRoads，不影响其余道路；
 * AK 未配置或全部失败时 ok=false，端侧继续用确定性仿真数据。
 */

/** 百度拥堵路段（无拥堵时 congestion_sections 缺省） */
interface BaiduSection {
  status?: number;
  speed?: number;
  congestion_distance?: number;
  congestion_trend?: string;
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

/** 拥堵区段 → 明细数组（解析方向，供进口道级反推使用） */
function parseSections(raw: BaiduSection[] | undefined): RealtimeSection[] {
  const list: RealtimeSection[] = [];
  for (const item of raw ?? []) {
    const desc: string = item.section_desc ?? '';
    list.push({
      status: item.status ?? 0,
      speed: item.speed ?? 0,
      congestionDistance: item.congestion_distance ?? 0,
      trend: item.congestion_trend ?? '',
      desc: desc,
      approach: approachFromDesc(desc)
    });
  }
  return list;
}

/** 道路响应 → 该道路的 level/status/speed 聚合（取最差区段） */
function summarizeRoad(resp: BaiduRoadResponse, roadName: string): Omit<RealtimeRoad, 'segId' | 'segName'> {
  const sections: RealtimeSection[] = parseSections(resp.road_traffic?.[0]?.congestion_sections);
  const overall: number = resp.evaluation?.status ?? 0;

  let worst: number = overall;
  let worstSpeed: number | null = null;
  let distance: number | null = null;
  let trend: string = '';
  for (const section of sections) {
    if (section.status > worst) {
      worst = section.status;
    }
  }
  for (const section of sections) {
    if (section.status >= 2) {
      // 车速取最堵区段的；拥堵距离累加（同一条路可能有多段拥堵）
      if (section.status === worst && section.speed > 0) {
        worstSpeed = section.speed;
      }
      distance = (distance ?? 0) + section.congestionDistance;
      if (section.trend !== '') {
        trend = section.trend;
      }
    }
  }

  return {
    roadName: roadName,
    level: toLevel(worst),
    baiduStatus: worst,
    speed: worstSpeed,
    congestionDistance: distance,
    desc: resp.description ?? resp.evaluation?.status_desc ?? '',
    sections: sections,
    trend: trend
  };
}

export class BaiduTrafficService {
  /** 上次成功快照（同步读取，供仿真数据源使用）；无数据时为 null */
  private latest: RealtimeSnapshot | null = null;

  lastSnapshot(): RealtimeSnapshot | null {
    return this.latest;
  }

  /** 全量实时路况：20 条道路串行 → 聚合回 32 条路段 */
  async getRealtimeRoads(force: boolean = false): Promise<RealtimeSnapshot> {
    const configured: boolean = BAIDU.AK.length > 0;
    if (!configured) {
      return { ok: false, configured: false, ts: Date.now(), roads: [], failedRoads: [], congestedRoads: 0 };
    }
    if (!force && cache !== null && Date.now() - cache.ts < BAIDU.CACHE_MS) {
      this.latest = cache.snapshot;
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
    let congested: number = 0;
    for (const seg of SEGMENTS) {
      const baiduName: string | undefined = SEG_TO_BAIDU_ROADS[seg.id]?.[0];
      if (baiduName === undefined) {
        continue;
      }
      const info = roadInfo.get(baiduName);
      if (info === undefined) {
        continue; // 该道路查询失败，端侧对此段回落仿真
      }
      if (info.sections.length > 0) {
        congested++;
      }
      roads.push({
        segId: seg.id,
        segName: seg.name,
        level: info.level,
        baiduStatus: info.baiduStatus,
        speed: info.speed,
        congestionDistance: info.congestionDistance,
        desc: info.desc,
        sections: info.sections,
        trend: info.trend,
        roadName: baiduName
      });
    }

    const snapshot: RealtimeSnapshot = {
      ok: roads.length > 0,
      configured: true,
      ts: Date.now(),
      roads: roads,
      failedRoads: failed,
      congestedRoads: congested
    };
    cache = { ts: snapshot.ts, snapshot: snapshot };
    this.latest = snapshot;
    return snapshot;
  }
}
