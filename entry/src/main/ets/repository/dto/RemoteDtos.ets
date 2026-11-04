import { Intersection, RoadSegment } from '../../model/Intersection';
import { RealtimeRoad } from '../../model/RealtimeRoad';
import { AreaTrafficIndex, FlowRecord } from '../../model/FlowRecord';
import { SignalPlan } from '../../model/SignalPlan';
import { Evaluation } from '../../model/Evaluation';
import { TrafficEvent } from '../../model/TrafficEvent';

/**
 * 远程接口的响应体包装类型
 * 与后端 server/src/routes/*.ts 返回结构一致，仅用于解析，不参与页面渲染
 */

export interface IntersectionsData {
  intersections: Intersection[];
}

export interface SegmentsData {
  segments: RoadSegment[];
}

export interface FlowsData {
  flows: FlowRecord[];
}

/** /road/realtime 返回体 */
export interface RealtimeRoadsData {
  ok: boolean;
  configured: boolean;
  ts: number;
  roads: RealtimeRoad[];
  failedRoads: string[];
}

export interface EventsData {
  events: TrafficEvent[];
  total: number;
}

export interface OptimizeData {
  plan: SignalPlan;
  evaluation: Evaluation;
}

export interface CreateEventData {
  id: string;
}

/** /health 返回体 */
export interface HealthData {
  status: string;
  dataSource: string;
  algoVersion: string;
  serverTime: number;
}
