/** 事件类型：0 事故 1 施工 2 管制 3 拥堵 4 其他 */
export enum EventType {
  ACCIDENT = 0,
  CONSTRUCTION = 1,
  CONTROL = 2,
  CONGESTION = 3,
  OTHER = 4
}

/** 交通事件 */
export interface TrafficEvent {
  id: string;
  type: number;
  title: string;
  description: string;
  roadName: string;
  longitude: number;
  latitude: number;
  /** 影响等级：1 轻微 2 一般 3 严重 */
  impact: number;
  /** 上报时间戳（毫秒） */
  createTime: number;
}

/** 事件上报入参 */
export interface CreateEventInput {
  type: number;
  title: string;
  description?: string;
  roadName?: string;
  longitude?: number;
  latitude?: number;
  impact?: number;
}
