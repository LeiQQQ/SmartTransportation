import { Intersection, RoadSegment } from '../../model/Intersection';
import { FlowRecord } from '../../model/FlowRecord';
import { TrafficUtil } from './TrafficUtil';

/**
 * 路况计算：把「路口进口道饱和度」换算成「路段三档颜色」
 *
 * 从 TrafficMapPage 里抽出来的原因：
 *   1. 这是纯计算，与 Canvas 无关，可单独验证；
 *   2. 原来 computeCongestion 在页面里每帧重算，且用 indexOf 反查下标（O(n²)），
 *      现在预先建索引，路段数和路口数增长时不会劣化。
 */
export class CongestionModel {
  /** 邻路传播的衰减系数：越远影响越小 */
  private static readonly SPREAD: number = 0.6;
  /** 传播轮次：两跳足够覆盖"堵到隔壁街"的观感 */
  private static readonly ROUNDS: number = 2;

  /**
   * 每个路口的最大进口道饱和度
   *
   * 取最大值而不是平均值：一个进口道过饱和，路口就该显示为堵；
   * 平均会把三条畅通车道摊薄，明明堵死却显示绿色。
   */
  static saturationByNode(flows: FlowRecord[]): Map<string, number> {
    const result: Map<string, number> = new Map();
    for (let i = 0; i < flows.length; i++) {
      const record: FlowRecord = flows[i];
      let max: number = 0;
      for (let j = 0; j < record.flows.length; j++) {
        if (record.flows[j].saturation > max) {
          max = record.flows[j].saturation;
        }
      }
      result.set(record.intersectionId, max);
    }
    return result;
  }

  /**
   * 路段拥堵度（0~1）：两端路口饱和度向较堵的一端倾斜 + 邻路传播
   *
   * 不用均值的理由：一段路只要一端堵死，排队就会往这段路上溢，
   * 取均值会被畅通的一端稀释，明明堵了却显示绿色。
   */
  static segmentCongestion(segments: RoadSegment[], satByNode: Map<string, number>): number[] {
    const base: number[] = [];
    for (let i = 0; i < segments.length; i++) {
      base.push(CongestionModel.baseOf(segments[i], satByNode));
    }
    const result: number[] = [];
    for (let i = 0; i < base.length; i++) {
      result.push(base[i]);
    }
    for (let round = 0; round < CongestionModel.ROUNDS; round++) {
      for (let i = 0; i < segments.length; i++) {
        let nearMax: number = 0;
        for (let j = 0; j < segments.length; j++) {
          if (i !== j && CongestionModel.isAdjacent(segments[i], segments[j]) && result[j] > nearMax) {
            nearMax = result[j];
          }
        }
        result[i] = Math.max(base[i], nearMax * CongestionModel.SPREAD);
      }
    }
    return result;
  }

  private static baseOf(seg: RoadSegment, satByNode: Map<string, number>): number {
    const sa: number = satByNode.get(seg.fromId) ?? 0;
    const sb: number = satByNode.get(seg.toId) ?? 0;
    const high: number = sa > sb ? sa : sb;
    const low: number = sa > sb ? sb : sa;
    return high * 0.65 + low * 0.35;
  }

  /** 两段路是否相邻（共用一个路口） */
  private static isAdjacent(a: RoadSegment, b: RoadSegment): boolean {
    return a.fromId === b.fromId || a.fromId === b.toId || a.toId === b.fromId || a.toId === b.toId;
  }

  /**
   * 渲染用档位：百度实测优先，未覆盖的路段回落仿真
   *
   * 这是"地图颜色唯一口径"：底图色带和路名标注都读这份结果，
   * 不会再出现"色带显示拥堵、标注却按畅通处理"的不一致。
   */
  static levels(segments: RoadSegment[], flows: FlowRecord[], realLevels: Map<string, number>): Map<string, number> {
    const satByNode: Map<string, number> = CongestionModel.saturationByNode(flows);
    const congestion: number[] = CongestionModel.segmentCongestion(segments, satByNode);
    const levels: Map<string, number> = new Map();
    for (let i = 0; i < segments.length; i++) {
      const seg: RoadSegment = segments[i];
      const real: number | undefined = realLevels.get(seg.id);
      levels.set(seg.id, real ?? TrafficUtil.roadLevelOf(congestion[i]));
    }
    return levels;
  }
}
