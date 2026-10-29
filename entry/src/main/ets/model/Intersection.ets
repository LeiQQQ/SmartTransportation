/** 进口道方向 */
export enum ApproachDir {
  EAST = 'EAST',
  WEST = 'WEST',
  SOUTH = 'SOUTH',
  NORTH = 'NORTH'
}

/** 路口类型 */
export enum IntersectionType {
  CROSS = 'CROSS',
  T_SHAPE = 'T_SHAPE',
  RING = 'RING'
}

/** 进口道 */
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
  type: string;
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
