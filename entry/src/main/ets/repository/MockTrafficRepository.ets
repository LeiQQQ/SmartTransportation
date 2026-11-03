import { ITrafficRepository } from './ITrafficRepository';
import { Intersection, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';
import { SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';
import { CreateEventInput, TrafficEvent } from '../model/TrafficEvent';
import { XianWallMock } from '../mock/XianWallMock';
import { EventStore } from '../common/utils/EventStore';

/**
 * 本地仿真数据实现：无后端时保证全流程可用
 */
export class MockTrafficRepository implements ITrafficRepository {
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(() => resolve(), ms);
    });
  }

  async getIntersections(): Promise<Intersection[]> {
    await this.delay(60);
    return XianWallMock.getIntersections();
  }

  async getSegments(): Promise<RoadSegment[]> {
    await this.delay(30);
    return XianWallMock.getSegments();
  }

  async getFlows(): Promise<FlowRecord[]> {
    await this.delay(120);
    return XianWallMock.getFlows();
  }

  async getFlow(intersectionId: string): Promise<FlowRecord | undefined> {
    await this.delay(60);
    return XianWallMock.getFlowOf(intersectionId);
  }

  async getAreaIndex(): Promise<AreaTrafficIndex> {
    await this.delay(60);
    return XianWallMock.getAreaIndex();
  }

  async getSignalPlan(intersectionId: string): Promise<SignalPlan> {
    await this.delay(80);
    return XianWallMock.getSignalPlan(intersectionId);
  }

  async getEvaluation(intersectionId: string, scenario: string): Promise<Evaluation> {
    await this.delay(80);
    return XianWallMock.getEvaluation(intersectionId, scenario);
  }

  async getEvents(): Promise<TrafficEvent[]> {
    await this.delay(60);
    const local: TrafficEvent[] = await EventStore.list();
    return local.concat(XianWallMock.getEvents());
  }

  /**
   * MOCK 模式：写端侧 preferences（`local_reported_events`，上限 50 条）
   * 断网时"上报 → 重启仍在"，联网后仍会合并展示；在线上报只写服务端，不产生重复
   */
  async createEvent(input: CreateEventInput): Promise<TrafficEvent> {
    await this.delay(80);
    const event: TrafficEvent = {
      id: `L${Date.now()}`,
      type: input.type,
      title: input.title,
      description: input.description ?? '',
      roadName: input.roadName ?? '',
      longitude: input.longitude ?? 0,
      latitude: input.latitude ?? 0,
      impact: input.impact ?? 1,
      createTime: Date.now()
    };
    await EventStore.add(event);
    return event;
  }
}
