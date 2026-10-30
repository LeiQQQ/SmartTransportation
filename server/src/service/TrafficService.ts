import { IDataSource } from '../source/IDataSource.js';
import { SCENARIO_HOURS } from '../config.js';
import { hourOf } from '../algo/simulator.js';
import type { AreaTrafficIndex, FlowRecord, Intersection, RoadSegment } from '../types/index.js';

/**
 * 交通流业务：路网查询、流量查询、片区拥堵指数
 * 只依赖数据源抽象，不关心数据来自仿真还是真实平台
 */
export class TrafficService {
  private readonly source: IDataSource;

  constructor(source: IDataSource) {
    this.source = source;
  }

  getIntersections(): Intersection[] {
    return this.source.getIntersections();
  }

  getSegments(): RoadSegment[] {
    return this.source.getSegments();
  }

  /** @param codes 指定路口 id 列表，为空返回全部 */
  getFlows(codes: string[] = [], scenario?: string): FlowRecord[] {
    const all: FlowRecord[] = this.source.getFlows(this.hourOfScenario(scenario));
    if (codes.length === 0) {
      return all;
    }
    return all.filter((record) => codes.includes(record.intersectionId));
  }

  getFlow(intersectionId: string, scenario?: string): FlowRecord | undefined {
    return this.source.getFlowOf(intersectionId, this.hourOfScenario(scenario));
  }

  getAreaIndex(scenario?: string): AreaTrafficIndex {
    return this.source.getAreaIndex(this.hourOfScenario(scenario));
  }

  /** 场景转仿真小时数：早高峰 8 点 / 平峰 13 点 / 晚高峰 18 点；不传按当前时间 */
  private hourOfScenario(scenario?: string): number | undefined {
    if (scenario === undefined || scenario === '') {
      return hourOf();
    }
    return SCENARIO_HOURS[scenario];
  }
}
