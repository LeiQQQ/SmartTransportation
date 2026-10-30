/** 进口道方向 */
export type ApproachDir = 'EAST' | 'WEST' | 'SOUTH' | 'NORTH';

/** 路口类型 */
export type IntersectionType = 'CROSS' | 'T_SHAPE' | 'RING';

/** 进口道（对应端侧 model/Intersection.ets 的 Approach） */
export interface Approach {
  dir: ApproachDir;
  /** 车道数 */
  lanes: number;
  /** 饱和流率（辆/h/车道） */
  saturationFlow: number;
}

/** 信号路口 */
export interface Intersection {
  id: string;
  name: string;
  longitude: number;
  latitude: number;
  type: IntersectionType;
  approaches: Approach[];
}

/** 路段（拓扑连线） */
export interface RoadSegment {
  id: string;
  name: string;
  fromId: string;
  toId: string;
  lanes: number;
}
