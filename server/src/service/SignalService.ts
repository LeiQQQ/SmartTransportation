import { IDataSource } from '../source/IDataSource.js';
import { findIntersection } from '../data/network.js';
import { SIGNAL, SCENARIO_HOURS } from '../config.js';
import { hourOf, summarize } from '../algo/simulator.js';
import { calculate } from '../algo/webster.js';
import { websterDelay } from '../algo/delay.js';
import { percent, round1, round2 } from '../util/metric.js';
import type {
  Evaluation, FlowRecord, Intersection, Metrics, SignalPhase, SignalPlan
} from '../types/index.js';

/**
 * 信号配时业务：Webster 配时计算 + 优化前后评价
 *
 * ⚠️ 已知局限（与端侧相同，详见项目设计文档 §10.7）：
 *   - 通行量（before = 0.93V, after = V）与停车次数（before = 1.6x, after = 1.2x）为演示性构造值
 *   - 优化前基线固定为 C=120、λ=0.42
 *   后续若改为逐周期排队推演，端侧 XianWallMock.getEvaluation() 必须同步修改
 */
export class SignalService {
  private readonly source: IDataSource;

  constructor(source: IDataSource) {
    this.source = source;
  }

  /** 计算配时方案；找不到路口时返回默认方案 */
  getPlan(intersectionId: string, scenario?: string): SignalPlan {
    const intersection: Intersection | undefined = findIntersection(intersectionId);
    const flow: FlowRecord | undefined = this.source.getFlowOf(intersectionId, this.hourOfScenario(scenario));
    if (intersection === undefined || flow === undefined) {
      return this.fallbackPlan(intersectionId);
    }

    // 关键相位：取相位内两个进口道的较大流量与较大通行能力
    let qEW: number = 0;
    let qNS: number = 0;
    let capEW: number = 0;
    let capNS: number = 0;
    for (let i = 0; i < flow.flows.length; i++) {
      const volume: number = flow.flows[i].volume;
      const approach = intersection.approaches[i];
      const capacity: number = approach === undefined
        ? 0
        : approach.saturationFlow * approach.lanes;
      const dir: string = flow.flows[i].dir;
      if (dir === 'EAST' || dir === 'WEST') {
        qEW = Math.max(qEW, volume);
        capEW = Math.max(capEW, capacity);
      } else {
        qNS = Math.max(qNS, volume);
        capNS = Math.max(capNS, capacity);
      }
    }
    if (capEW === 0) {
      capEW = 3300;
    }
    if (capNS === 0) {
      capNS = 3300;
    }

    const result = calculate(qEW / capEW, qNS / capNS);

    return {
      intersectionId: intersectionId,
      planName: '流量自适应方案',
      cycleLength: result.cycleLength,
      lostTime: result.lostTime,
      phases: this.buildPhases(result.greens.throughEW, result.greens.leftEW,
        result.greens.throughNS, result.greens.leftNS),
      optimized: true,
      beforeCycleLength: SIGNAL.BEFORE_CYCLE
    };
  }

  /** 优化前后评价 */
  getEvaluation(intersectionId: string, scenario: string = '平峰'): Evaluation {
    const plan: SignalPlan = this.getPlan(intersectionId, scenario);
    const flow: FlowRecord | undefined = this.source.getFlowOf(intersectionId, this.hourOfScenario(scenario));
    const summary = summarize(flow === undefined ? [] : [flow]);
    const avgSat: number = summary.avgSaturation;
    const totalVolume: number = summary.totalVolume;

    const beforeRatio: number = SIGNAL.BEFORE_GREEN_RATIO;
    const afterRatio: number = ((plan.cycleLength - plan.lostTime) / plan.cycleLength) * 0.92;

    const beforeDelay: number = websterDelay(SIGNAL.BEFORE_CYCLE, beforeRatio, avgSat, totalVolume);
    const afterDelay: number = websterDelay(plan.cycleLength, afterRatio, avgSat * 0.9, totalVolume);

    const before: Metrics = {
      avgDelay: round1(beforeDelay),
      avgQueue: round1(avgSat * avgSat * 16),
      throughput: Math.round(totalVolume * 0.93),
      stops: round2(avgSat * 1.6)
    };
    const after: Metrics = {
      avgDelay: round1(afterDelay),
      avgQueue: round1(avgSat * 0.9 * avgSat * 0.9 * 16),
      throughput: Math.round(totalVolume),
      stops: round2(avgSat * 1.2)
    };

    return {
      intersectionId: intersectionId,
      scenario: scenario,
      before: before,
      after: after,
      improvement: {
        avgDelay: percent(before.avgDelay, after.avgDelay),
        avgQueue: percent(before.avgQueue, after.avgQueue),
        throughput: percent(before.throughput, after.throughput),
        stops: percent(before.stops, after.stops)
      }
    };
  }

  /** 触发一次优化：返回新方案与评价（当前实现等价于"按最新流量重算"） */
  optimize(intersectionId: string, scenario: string = '平峰'): { plan: SignalPlan; evaluation: Evaluation } {
    return {
      plan: this.getPlan(intersectionId, scenario),
      evaluation: this.getEvaluation(intersectionId, scenario)
    };
  }

  private buildPhases(throughEW: number, leftEW: number, throughNS: number, leftNS: number): SignalPhase[] {
    return [
      { phaseId: 1, name: '东西直行', green: throughEW, yellow: SIGNAL.YELLOW, allRed: SIGNAL.ALL_RED, movements: ['EAST', 'WEST'] },
      { phaseId: 2, name: '东西左转', green: leftEW, yellow: SIGNAL.YELLOW, allRed: SIGNAL.ALL_RED, movements: ['EAST', 'WEST'] },
      { phaseId: 3, name: '南北直行', green: throughNS, yellow: SIGNAL.YELLOW, allRed: SIGNAL.ALL_RED, movements: ['NORTH', 'SOUTH'] },
      { phaseId: 4, name: '南北左转', green: leftNS, yellow: SIGNAL.YELLOW, allRed: SIGNAL.ALL_RED, movements: ['NORTH', 'SOUTH'] }
    ];
  }

  /** 找不到路口时的兜底方案，与端侧 fallbackPlan 一致 */
  private fallbackPlan(intersectionId: string): SignalPlan {
    return {
      intersectionId: intersectionId,
      planName: '默认方案',
      cycleLength: 90,
      lostTime: SIGNAL.LOST_TIME,
      phases: this.buildPhases(30, 14, 26, 12),
      optimized: false,
      beforeCycleLength: 90
    };
  }

  private hourOfScenario(scenario?: string): number | undefined {
    if (scenario === undefined || scenario === '') {
      return hourOf();
    }
    return SCENARIO_HOURS[scenario];
  }
}
