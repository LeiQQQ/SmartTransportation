import { Intersection, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';
import { SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';
import { CreateEventInput, TrafficEvent } from '../model/TrafficEvent';
import { RealtimeRoad } from '../model/RealtimeRoad';

/**
 * 交通数据仓库抽象
 * Remote 与 Mock 两种实现可互换，页面只依赖此接口
 */
export interface ITrafficRepository {
  getIntersections(): Promise<Intersection[]>;

  getSegments(): Promise<RoadSegment[]>;

  getFlows(): Promise<FlowRecord[]>;

  getFlow(intersectionId: string): Promise<FlowRecord | undefined>;

  getAreaIndex(): Promise<AreaTrafficIndex>;

  getSignalPlan(intersectionId: string): Promise<SignalPlan>;

  getEvaluation(intersectionId: string, scenario: string): Promise<Evaluation>;

  getEvents(): Promise<TrafficEvent[]>;

  /** 上报事件：REMOTE 落后端数据库，MOCK 存内存（仅当次运行可见） */
  createEvent(input: CreateEventInput): Promise<TrafficEvent>;

  /**
   * 路段级实时路况（百度实测，后端聚合）
   * 返回空数组 = 无真实数据（AK 未配置/查询失败），调用方回落仿真
   */
  getRealtimeRoads(): Promise<RealtimeRoad[]>;
}
