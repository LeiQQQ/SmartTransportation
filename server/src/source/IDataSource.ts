import type { AreaTrafficIndex, FlowRecord, Intersection, RoadSegment } from '../types/index.js';

/**
 * 数据源抽象
 *
 * 设计目的：把「数据从哪来」与「业务怎么算」解耦。
 * 目前只有仿真实现；后续接入 OSM 路网或地图 API 时，新增实现类即可，Service 层零改动。
 */
export interface IDataSource {
  /** 数据源标识，会通过 /health 返回给端侧 */
  readonly name: string;

  getIntersections(): Intersection[];

  getSegments(): RoadSegment[];

  /** 全部路口流量；传 hour 可按指定时段仿真，不传按当前时间 */
  getFlows(hour?: number): FlowRecord[];

  getFlowOf(intersectionId: string, hour?: number): FlowRecord | undefined;

  getAreaIndex(hour?: number): AreaTrafficIndex;
}
