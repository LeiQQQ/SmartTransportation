/** 事件类型 */
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
  /** 上报时间戳 */
  createTime: number;
}

export class EventTypeUtil {
  static nameOf(type: number): string {
    switch (type) {
      case EventType.ACCIDENT:
        return '事故';
      case EventType.CONSTRUCTION:
        return '施工';
      case EventType.CONTROL:
        return '管制';
      case EventType.CONGESTION:
        return '拥堵';
      default:
        return '其他';
    }
  }

  static colorOf(type: number): string {
    switch (type) {
      case EventType.ACCIDENT:
        return '#FF3B30';
      case EventType.CONSTRUCTION:
        return '#FFB020';
      case EventType.CONTROL:
        return '#0F6FFF';
      case EventType.CONGESTION:
        return '#FF7A45';
      default:
        return '#8A94A6';
    }
  }
}
