import { IDataSource } from './IDataSource.js';
import { INTERSECTIONS, SEGMENTS, findIntersection } from '../data/network.js';
import { buildAreaIndex, buildFlowRecord, hourOf } from '../algo/simulator.js';
import type { AreaTrafficIndex, FlowRecord, Intersection, RoadSegment } from '../types/index.js';

/**
 * 仿真数据源
 *
 * 配时算法的唯一数据来源。地图开放平台不提供进口道分方向流量与信号配时参数，
 * 因此本项目流量必须由仿真产生（详见后端技术方案 §2）。
 */
export class SimulationDataSource implements IDataSource {
  readonly name: string = 'SIMULATION';

  getIntersections(): Intersection[] {
    return [...INTERSECTIONS];
  }

  getSegments(): RoadSegment[] {
    return [...SEGMENTS];
  }

  getFlows(hour?: number): FlowRecord[] {
    const h: number = hour ?? hourOf();
    const timestamp: number = Date.now();
    return INTERSECTIONS.map((item) => buildFlowRecord(item, h, timestamp));
  }

  getFlowOf(intersectionId: string, hour?: number): FlowRecord | undefined {
    const intersection: Intersection | undefined = findIntersection(intersectionId);
    if (intersection === undefined) {
      return undefined;
    }
    return buildFlowRecord(intersection, hour ?? hourOf());
  }

  getAreaIndex(hour?: number): AreaTrafficIndex {
    return buildAreaIndex(this.getFlows(hour));
  }
}
