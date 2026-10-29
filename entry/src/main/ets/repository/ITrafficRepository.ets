import { Intersection, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';
import { SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';
import { TrafficEvent } from '../model/TrafficEvent';

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
}
