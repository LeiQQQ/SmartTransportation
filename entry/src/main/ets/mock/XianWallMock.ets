import { Approach, ApproachDir, Intersection, IntersectionType, RoadSegment } from '../model/Intersection';
import { AreaTrafficIndex, ApproachFlow, FlowRecord } from '../model/FlowRecord';
import { SignalPhase, SignalPlan } from '../model/SignalPlan';
import { Evaluation, Metrics } from '../model/Evaluation';
import { TrafficEvent } from '../model/TrafficEvent';
import { AreaConstants } from '../common/constants/AreaConstants';
import { TrafficUtil } from '../common/utils/TrafficUtil';

/**
 * 西安城墙内片区仿真数据源
 * 路网按真实主干道路建模：20 个信号路口 + 32 条路段
 * 四门：安远门（北）/ 长乐门（东）/ 永宁门（南）/ 安定门（西）；四条大街、环城路、莲湖路—西五路—东五路、南广济街等
 * 流量按高斯双峰模型生成；与后端 server/src/data/network.ts 严格一致
 */
export class XianWallMock {
  private static intersections: Intersection[] | undefined = undefined;
  private static segments: RoadSegment[] | undefined = undefined;

  // ---------------- 路网 ----------------

  static getIntersections(): Intersection[] {
    if (XianWallMock.intersections !== undefined) {
      return XianWallMock.intersections;
    }
    const list: Intersection[] = [];
    // 四条大街交汇与中轴
    list.push(XianWallMock.build('INT_01', '钟楼', 108.9495, 34.2615, IntersectionType.RING, 4, 3));
    list.push(XianWallMock.build('INT_02', '北门·安远门', 108.9487, 34.2752, IntersectionType.RING, 4, 3));
    list.push(XianWallMock.build('INT_03', '北门十字', 108.9488, 34.2712, IntersectionType.CROSS, 4, 3));
    list.push(XianWallMock.build('INT_12', '南门·永宁门', 108.9492, 34.2498, IntersectionType.RING, 4, 3));
    // 西大街沿线
    list.push(XianWallMock.build('INT_05', '西门·安定门', 108.9297, 34.2622, IntersectionType.RING, 4, 2));
    list.push(XianWallMock.build('INT_06', '桥梓口', 108.9366, 34.2622, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_07', '广济街', 108.9432, 34.2622, IntersectionType.CROSS, 4, 2));
    // 东大街沿线
    list.push(XianWallMock.build('INT_08', '端履门', 108.9540, 34.2613, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_09', '大差市', 108.9598, 34.2612, IntersectionType.CROSS, 4, 3));
    // 东端即东门长乐门
    list.push(XianWallMock.build('INT_20', '长乐门', 108.9696, 34.2612, IntersectionType.RING, 4, 3));
    // 北部横向
    list.push(XianWallMock.build('INT_04', '玉祥门', 108.9297, 34.2706, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_17', '洒金桥', 108.9332, 34.2708, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_10', '五路口', 108.9578, 34.2710, IntersectionType.CROSS, 4, 3));
    list.push(XianWallMock.build('INT_11', '朝阳门', 108.9696, 34.2698, IntersectionType.CROSS, 4, 2));
    // 南部与环城路
    list.push(XianWallMock.build('INT_13', '书院门', 108.9490, 34.2532, IntersectionType.T_SHAPE, 3, 2));
    list.push(XianWallMock.build('INT_14', '朱雀门', 108.9416, 34.2498, IntersectionType.CROSS, 3, 2));
    list.push(XianWallMock.build('INT_18', '湘子庙街口', 108.9440, 34.2498, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_19', '文昌门', 108.9528, 34.2498, IntersectionType.CROSS, 4, 2));
    list.push(XianWallMock.build('INT_15', '和平门', 108.9556, 34.2498, IntersectionType.CROSS, 4, 2));
    // 回坊
    list.push(XianWallMock.build('INT_16', '北院门', 108.9436, 34.2650, IntersectionType.T_SHAPE, 3, 1));
    XianWallMock.intersections = list;
    return list;
  }

  private static build(id: string, name: string, lon: number, lat: number,
    type: IntersectionType, approachCount: number, lanes: number): Intersection {
    const approaches: Approach[] = [];
    const dirs: ApproachDir[] = [ApproachDir.EAST, ApproachDir.WEST, ApproachDir.SOUTH, ApproachDir.NORTH];
    for (let i = 0; i < approachCount; i++) {
      approaches.push({
        dir: dirs[i],
        lanes: lanes,
        saturationFlow: 1650
      } as Approach);
    }
    return {
      id: id,
      name: name,
      longitude: lon,
      latitude: lat,
      type: type.toString(),
      approaches: approaches
    } as Intersection;
  }

  static getSegments(): RoadSegment[] {
    if (XianWallMock.segments !== undefined) {
      return XianWallMock.segments;
    }
    // 与后端 server/src/data/network.ts 的 RAW_SEGMENTS 严格一致（顺序、id、端点、车道数）
    const raw: string[][] = [
      // 中轴：北大街—南大街
      ['SEG_01', '北大街（北段）', 'INT_02', 'INT_03', '3'],
      ['SEG_02', '北大街（南段）', 'INT_03', 'INT_01', '3'],
      ['SEG_03', '南大街（北段）', 'INT_01', 'INT_13', '2'],
      ['SEG_04', '南大街（南段）', 'INT_13', 'INT_12', '2'],
      // 横轴：西大街—东大街
      ['SEG_05', '西大街（东段）', 'INT_01', 'INT_07', '3'],
      ['SEG_06', '西大街（中段）', 'INT_07', 'INT_06', '3'],
      ['SEG_07', '西大街（西段）', 'INT_06', 'INT_05', '2'],
      ['SEG_08', '东大街（西段）', 'INT_01', 'INT_08', '3'],
      ['SEG_09', '东大街（东段）', 'INT_08', 'INT_09', '3'],
      // 北部：莲湖路—西五路—东五路
      ['SEG_10', '莲湖路（西段）', 'INT_04', 'INT_17', '2'],
      ['SEG_11', '莲湖路（东段）', 'INT_17', 'INT_03', '2'],
      ['SEG_12', '西五路', 'INT_03', 'INT_10', '3'],
      ['SEG_13', '东五路', 'INT_10', 'INT_11', '2'],
      // 东侧：解放路、和平路、柏树林
      ['SEG_14', '解放路', 'INT_10', 'INT_09', '3'],
      ['SEG_15', '和平路', 'INT_09', 'INT_15', '2'],
      ['SEG_16', '书院门·柏树林', 'INT_13', 'INT_08', '1'],
      // 西侧：洒金桥路、南四府街
      ['SEG_17', '洒金桥路', 'INT_17', 'INT_06', '2'],
      ['SEG_18', '南四府街', 'INT_06', 'INT_14', '2'],
      // 回坊支路
      ['SEG_19', '北院门街', 'INT_07', 'INT_16', '1'],
      ['SEG_20', '西华门大街', 'INT_16', 'INT_01', '2'],
      // 环城路
      ['SEG_21', '环城北路（西段）', 'INT_04', 'INT_02', '3'],
      ['SEG_22', '环城北路（东段）', 'INT_02', 'INT_11', '3'],
      ['SEG_23', '环城西路', 'INT_04', 'INT_05', '3'],
      ['SEG_24', '环城西路（南延）', 'INT_05', 'INT_14', '2'],
      ['SEG_25', '环城南路（西段）', 'INT_14', 'INT_18', '3'],
      ['SEG_28', '环城南路（中段西）', 'INT_18', 'INT_12', '3'],
      ['SEG_26', '环城南路（中段东）', 'INT_12', 'INT_19', '3'],
      ['SEG_29', '环城南路（东段）', 'INT_19', 'INT_15', '3'],
      ['SEG_27', '环城东路（南段）', 'INT_15', 'INT_20', '3'],
      ['SEG_30', '南广济街', 'INT_07', 'INT_18', '2'],
      ['SEG_31', '东大街（东延）', 'INT_09', 'INT_20', '3'],
      ['SEG_32', '环城东路（北段）', 'INT_20', 'INT_11', '3']
    ];
    const list: RoadSegment[] = [];
    for (let i = 0; i < raw.length; i++) {
      const r: string[] = raw[i];
      list.push({
        id: r[0], name: r[1], fromId: r[2], toId: r[3], lanes: Number(r[4])
      } as RoadSegment);
    }
    XianWallMock.segments = list;
    return list;
  }

  static findIntersection(id: string): Intersection | undefined {
    const list: Intersection[] = XianWallMock.getIntersections();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        return list[i];
      }
    }
    return undefined;
  }

  // ---------------- 流量仿真 ----------------

  /** 确定性伪随机（同一路口同一方向结果稳定） */
  private static pseudo(id: string, dir: string): number {
    const s: string = id + '_' + dir;
    let h: number = 7;
    for (let i = 0; i < s.length; i++) {
      h = (h * 31 + s.charCodeAt(i)) % 9973;
    }
    return h / 9973;
  }

  /** 高斯双峰系数：早高峰 8 点、晚高峰 18 点 */
  private static peakFactor(hour: number): number {
    const morning: number = Math.exp(-Math.pow(hour - 8, 2) / 4);
    const evening: number = Math.exp(-Math.pow(hour - 18, 2) / 4);
    return 0.35 + morning + evening;
  }

  static getFlows(): FlowRecord[] {
    const now: number = Date.now();
    const date: Date = new Date(now);
    const hour: number = date.getHours() + date.getMinutes() / 60;
    const peak: number = XianWallMock.peakFactor(hour);
    const list: Intersection[] = XianWallMock.getIntersections();
    const result: FlowRecord[] = [];

    for (let i = 0; i < list.length; i++) {
      const it: Intersection = list[i];
      const flows: ApproachFlow[] = [];
      for (let j = 0; j < it.approaches.length; j++) {
        const ap: Approach = it.approaches[j];
        const base: number = 480 + XianWallMock.pseudo(it.id, ap.dir.toString()) * 420;
        const volume: number = Math.round(base * peak);
        // 主干道（钟楼、大差市）通行能力更强
        const greenRatio: number = 0.48;
        const capacity: number = TrafficUtil.capacityOf(ap.saturationFlow, ap.lanes, greenRatio);
        const saturation: number = TrafficUtil.saturationOf(volume, capacity);
        const queueLength: number = Math.round(saturation * saturation * 14);
        const delay: number = Math.round(saturation * 45 + 6);
        flows.push({
          dir: ap.dir,
          volume: volume,
          queueLength: queueLength,
          delay: delay,
          saturation: saturation
        } as ApproachFlow);
      }
      result.push({
        intersectionId: it.id,
        timestamp: now,
        flows: flows
      } as FlowRecord);
    }
    return result;
  }

  static getFlowOf(intersectionId: string): FlowRecord | undefined {
    const flows: FlowRecord[] = XianWallMock.getFlows();
    for (let i = 0; i < flows.length; i++) {
      if (flows[i].intersectionId === intersectionId) {
        return flows[i];
      }
    }
    return undefined;
  }

  /** 片区拥堵指数：各进口道饱和度的加权平均映射到 0~10 */
  static getAreaIndex(): AreaTrafficIndex {
    const flows: FlowRecord[] = XianWallMock.getFlows();
    let sum: number = 0;
    let count: number = 0;
    for (let i = 0; i < flows.length; i++) {
      for (let j = 0; j < flows[i].flows.length; j++) {
        sum += flows[i].flows[j].saturation;
        count++;
      }
    }
    const avg: number = count === 0 ? 0 : sum / count;
    const index: number = Math.min(10, avg * 10);
    return {
      areaName: AreaConstants.AREA_NAME,
      index: Number(index.toFixed(1)),
      avgSpeed: Math.round(45 * (1 - avg / 1.6)),
      updateTime: Date.now()
    } as AreaTrafficIndex;
  }

  // ---------------- 配时与评价 ----------------

  /**
   * Webster 最优周期配时
   * C0 = (1.5L + 5) / (1 - Y)
   */
  static getSignalPlan(intersectionId: string): SignalPlan {
    const flow: FlowRecord | undefined = XianWallMock.getFlowOf(intersectionId);
    const it: Intersection | undefined = XianWallMock.findIntersection(intersectionId);
    if (flow === undefined || it === undefined) {
      return XianWallMock.fallbackPlan(intersectionId);
    }

    let qEW: number = 0;
    let qNS: number = 0;
    let capEW: number = 0;
    let capNS: number = 0;
    for (let i = 0; i < flow.flows.length; i++) {
      const f: ApproachFlow = flow.flows[i];
      const ap: Approach = it.approaches[i];
      const cap: number = ap.saturationFlow * ap.lanes;
      if (f.dir === ApproachDir.EAST || f.dir === ApproachDir.WEST) {
        qEW = Math.max(qEW, f.volume);
        capEW = Math.max(capEW, cap);
      } else {
        qNS = Math.max(qNS, f.volume);
        capNS = Math.max(capNS, cap);
      }
    }
    if (capEW === 0) {
      capEW = 3300;
    }
    if (capNS === 0) {
      capNS = 3300;
    }

    const yEW: number = qEW / capEW;
    const yNS: number = qNS / capNS;
    const yEWLeft: number = yEW * 0.3;
    const yNSLeft: number = yNS * 0.3;
    const Y: number = Math.min(0.92, yEW + yNS + yEWLeft + yNSLeft);
    const lostTime: number = 16;
    let cycle: number = (1.5 * lostTime + 5) / (1 - Y);
    cycle = Math.max(60, Math.min(150, Math.round(cycle)));

    const effective: number = cycle - lostTime;
    const greenEW: number = Math.max(10, Math.round(effective * (yEW / Y)));
    const greenNS: number = Math.max(10, Math.round(effective * (yNS / Y)));
    const greenEWLeft: number = Math.max(8, Math.round(effective * (yEWLeft / Y)));
    const greenNSLeft: number = Math.max(8, Math.round(effective * (yNSLeft / Y)));

    const phases: SignalPhase[] = [
      { phaseId: 1, name: '东西直行', green: greenEW, yellow: 3, allRed: 1, movements: ['EAST', 'WEST'] } as SignalPhase,
      { phaseId: 2, name: '东西左转', green: greenEWLeft, yellow: 3, allRed: 1, movements: ['EAST', 'WEST'] } as SignalPhase,
      { phaseId: 3, name: '南北直行', green: greenNS, yellow: 3, allRed: 1, movements: ['NORTH', 'SOUTH'] } as SignalPhase,
      { phaseId: 4, name: '南北左转', green: greenNSLeft, yellow: 3, allRed: 1, movements: ['NORTH', 'SOUTH'] } as SignalPhase
    ];

    return {
      intersectionId: intersectionId,
      planName: '流量自适应方案',
      cycleLength: cycle,
      lostTime: lostTime,
      phases: phases,
      optimized: true,
      beforeCycleLength: 120
    } as SignalPlan;
  }

  private static fallbackPlan(intersectionId: string): SignalPlan {
    const phases: SignalPhase[] = [
      { phaseId: 1, name: '东西直行', green: 30, yellow: 3, allRed: 1, movements: ['EAST', 'WEST'] } as SignalPhase,
      { phaseId: 2, name: '东西左转', green: 14, yellow: 3, allRed: 1, movements: ['EAST', 'WEST'] } as SignalPhase,
      { phaseId: 3, name: '南北直行', green: 26, yellow: 3, allRed: 1, movements: ['NORTH', 'SOUTH'] } as SignalPhase,
      { phaseId: 4, name: '南北左转', green: 12, yellow: 3, allRed: 1, movements: ['NORTH', 'SOUTH'] } as SignalPhase
    ];
    return {
      intersectionId: intersectionId,
      planName: '默认方案',
      cycleLength: 90,
      lostTime: 16,
      phases: phases,
      optimized: false,
      beforeCycleLength: 90
    } as SignalPlan;
  }

  /**
   * Webster 延误：d = C(1-λ)²/[2(1-λx)] + x²/[2q(1-x)]
   */
  private static websterDelay(cycle: number, greenRatio: number, saturation: number, volume: number): number {
    const x: number = Math.min(0.95, saturation);
    const q: number = Math.max(0.05, volume / 3600);
    const term1: number = cycle * Math.pow(1 - greenRatio, 2) / (2 * (1 - greenRatio * x));
    const term2: number = Math.pow(x, 2) / (2 * q * (1 - x));
    return term1 + term2;
  }

  static getEvaluation(intersectionId: string, scenario: string): Evaluation {
    const plan: SignalPlan = XianWallMock.getSignalPlan(intersectionId);
    const flow: FlowRecord | undefined = XianWallMock.getFlowOf(intersectionId);
    let avgSat: number = 0.7;
    let totalVolume: number = 1200;
    if (flow !== undefined && flow.flows.length > 0) {
      let s: number = 0;
      let v: number = 0;
      for (let i = 0; i < flow.flows.length; i++) {
        s += flow.flows[i].saturation;
        v += flow.flows[i].volume;
      }
      avgSat = s / flow.flows.length;
      totalVolume = v;
    }

    const beforeRatio: number = 0.42;
    const afterRatio: number = (plan.cycleLength - plan.lostTime) / plan.cycleLength * 0.92;
    const beforeDelay: number = XianWallMock.websterDelay(120, beforeRatio, avgSat, totalVolume);
    const afterDelay: number = XianWallMock.websterDelay(plan.cycleLength, afterRatio, avgSat * 0.9, totalVolume);

    const before: Metrics = {
      avgDelay: Number(beforeDelay.toFixed(1)),
      avgQueue: Number((avgSat * avgSat * 16).toFixed(1)),
      throughput: Math.round(totalVolume * 0.93),
      stops: Number((avgSat * 1.6).toFixed(2))
    } as Metrics;
    const after: Metrics = {
      avgDelay: Number(afterDelay.toFixed(1)),
      avgQueue: Number((avgSat * 0.9 * avgSat * 0.9 * 16).toFixed(1)),
      throughput: Math.round(totalVolume),
      stops: Number((avgSat * 1.2).toFixed(2))
    } as Metrics;

    return {
      intersectionId: intersectionId,
      scenario: scenario,
      before: before,
      after: after,
      improvement: {
        avgDelay: XianWallMock.percent(before.avgDelay, after.avgDelay),
        avgQueue: XianWallMock.percent(before.avgQueue, after.avgQueue),
        throughput: XianWallMock.percent(before.throughput, after.throughput),
        stops: XianWallMock.percent(before.stops, after.stops)
      } as Metrics
    } as Evaluation;
  }

  private static percent(before: number, after: number): number {
    if (before === 0) {
      return 0;
    }
    return Number((((after - before) / before) * 100).toFixed(1));
  }

  // ---------------- 事件 ----------------

  static getEvents(): TrafficEvent[] {
    const now: number = Date.now();
    const list: TrafficEvent[] = [];
    list.push({
      id: 'E001', type: 3, title: '洒金桥南向北行驶缓慢', description: '回坊入口车流集中，排队约 300 米',
      roadName: '洒金桥路', longitude: 108.9332, latitude: 34.2708, impact: 3, createTime: now - 8 * 60000
    } as TrafficEvent);
    list.push({
      id: 'E002', type: 1, title: '东大街辅道施工', description: '占用一条非机动车道，预计 3 日恢复',
      roadName: '东大街·端履门', longitude: 108.9540, latitude: 34.2613, impact: 2, createTime: now - 42 * 60000
    } as TrafficEvent);
    list.push({
      id: 'E003', type: 0, title: '北大街两车剐蹭', description: '占用左侧车道，交警已到场',
      roadName: '北大街', longitude: 108.9488, latitude: 34.2660, impact: 2, createTime: now - 15 * 60000
    } as TrafficEvent);
    list.push({
      id: 'E004', type: 2, title: '书院门步行街临时管制', description: '节假日人流管控，机动车禁止驶入',
      roadName: '书院门', longitude: 108.9490, latitude: 34.2532, impact: 1, createTime: now - 120 * 60000
    } as TrafficEvent);
    return list;
  }
}
