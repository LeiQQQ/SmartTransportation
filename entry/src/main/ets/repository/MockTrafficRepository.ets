import { ITrafficRepository } from './ITrafficRepository';
import { Intersection, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';
import { SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';
import { CreateEventInput, TrafficEvent } from '../model/TrafficEvent';
import { XianWallMock } from '../mock/XianWallMock';

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
    const submitted: TrafficEvent[] = MockTrafficRepository.submitted;
    return submitted.concat(XianWallMock.getEvents());
  }

  /**
   * MOCK 模式下没有后端，上报的事件只能存内存：
   * 当次运行可见、重启即失效——要跨设备共享必须切 REMOTE（写后端 SQLite）
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
    MockTrafficRepository.submitted.unshift(event);
    return event;
  }

  private static submitted: TrafficEvent[] = [];
}
