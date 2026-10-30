import { ITrafficRepository } from './ITrafficRepository';
import { Intersection, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, FlowRecord } from '../model/FlowRecord';
import { SignalPlan } from '../model/SignalPlan';
import { Evaluation } from '../model/Evaluation';
import { TrafficEvent } from '../model/TrafficEvent';
import { HttpUtil } from '../common/utils/HttpUtil';
import { LogUtil } from '../common/utils/LogUtil';
import { XianWallMock } from '../mock/XianWallMock';
import { EventsData, FlowsData, IntersectionsData, SegmentsData } from './dto/RemoteDtos';

/**
 * 远程数据源实现：调用后端 /api/v1 接口
 *
 * 降级策略：任一请求失败时回落到本地仿真 XianWallMock，
 * 保证后端不可用时 App 仍可完整演示（答辩现场服务没起来也不白屏）。
 * 失败原因由 HttpUtil 打印，这里只记录降级动作。
 */
export class RemoteTrafficRepository implements ITrafficRepository {
  private static readonly TAG: string = 'RemoteRepo';

  async getIntersections(): Promise<Intersection[]> {
    try {
      const response = await HttpUtil.get<IntersectionsData>('/area/intersections');
      return response.data?.intersections ?? [];
    } catch (error) {
      RemoteTrafficRepository.logFallback('getIntersections');
      return XianWallMock.getIntersections();
    }
  }

  async getSegments(): Promise<RoadSegment[]> {
    try {
      const response = await HttpUtil.get<SegmentsData>('/area/segments');
      return response.data?.segments ?? [];
    } catch (error) {
      RemoteTrafficRepository.logFallback('getSegments');
      return XianWallMock.getSegments();
    }
  }

  async getFlows(): Promise<FlowRecord[]> {
    try {
      const response = await HttpUtil.get<FlowsData>('/traffic/flow');
      return response.data?.flows ?? [];
    } catch (error) {
      RemoteTrafficRepository.logFallback('getFlows');
      return XianWallMock.getFlows();
    }
  }

  async getFlow(intersectionId: string): Promise<FlowRecord | undefined> {
    try {
      const response = await HttpUtil.get<FlowRecord>('/traffic/flow/' + intersectionId);
      return response.data;
    } catch (error) {
      RemoteTrafficRepository.logFallback('getFlow');
      return XianWallMock.getFlowOf(intersectionId);
    }
  }

  async getAreaIndex(): Promise<AreaTrafficIndex> {
    try {
      const response = await HttpUtil.get<AreaTrafficIndex>('/traffic/index');
      return response.data;
    } catch (error) {
      RemoteTrafficRepository.logFallback('getAreaIndex');
      return XianWallMock.getAreaIndex();
    }
  }

  async getSignalPlan(intersectionId: string): Promise<SignalPlan> {
    try {
      const response = await HttpUtil.get<SignalPlan>('/signal/plan/' + intersectionId);
      return response.data;
    } catch (error) {
      RemoteTrafficRepository.logFallback('getSignalPlan');
      return XianWallMock.getSignalPlan(intersectionId);
    }
  }

  async getEvaluation(intersectionId: string, scenario: string): Promise<Evaluation> {
    // 场景为中文，需编码后拼在 URL 上（ArkTS 不允许裸对象字面量传参）
    const query: string = '?scenario=' + encodeURIComponent(scenario);
    try {
      const response = await HttpUtil.get<Evaluation>('/signal/evaluation/' + intersectionId + query);
      return response.data;
    } catch (error) {
      RemoteTrafficRepository.logFallback('getEvaluation');
      return XianWallMock.getEvaluation(intersectionId, scenario);
    }
  }

  async getEvents(): Promise<TrafficEvent[]> {
    try {
      const response = await HttpUtil.get<EventsData>('/events');
      return response.data?.events ?? [];
    } catch (error) {
      RemoteTrafficRepository.logFallback('getEvents');
      return XianWallMock.getEvents();
    }
  }

  /** 记录降级动作；具体失败原因见 HttpUtil 的 warn 日志 */
  private static logFallback(method: string): void {
    LogUtil.warn(RemoteTrafficRepository.TAG, `${method} 远程请求失败，回落本地仿真数据`);
  }
}
