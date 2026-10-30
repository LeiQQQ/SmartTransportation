import type { CreateEventInput, TrafficEvent } from '../types/index.js';

/**
 * 交通事件业务
 * P1 阶段使用内存存储（重启后回到初始演示数据），P2 落库 SQLite 后改为持久化
 */
export class EventService {
  private events: TrafficEvent[] = EventService.seed();

  /** @param type 事件类型过滤，undefined 表示全部 */
  list(type: number | undefined, page: number = 1, size: number = 20): { events: TrafficEvent[]; total: number } {
    const filtered: TrafficEvent[] = type === undefined
      ? this.events
      : this.events.filter((event) => event.type === type);

    const sorted: TrafficEvent[] = [...filtered].sort((a, b) => b.createTime - a.createTime);
    const start: number = (page - 1) * size;
    return { events: sorted.slice(start, start + size), total: filtered.length };
  }

  create(input: CreateEventInput): TrafficEvent {
    const event: TrafficEvent = {
      id: `E${Date.now()}`,
      type: input.type,
      title: input.title,
      description: input.description ?? '',
      roadName: input.roadName ?? '',
      longitude: input.longitude ?? 0,
      latitude: input.latitude ?? 0,
      impact: input.impact ?? 1,
      createTime: Date.now()
    };
    this.events.push(event);
    return event;
  }

  /** 初始演示事件，与端侧 XianWallMock.getEvents() 一致 */
  private static seed(): TrafficEvent[] {
    const now: number = Date.now();
    return [
      {
        id: 'E001', type: 3, title: '洒金桥南向北行驶缓慢', description: '回坊入口车流集中，排队约 300 米',
        roadName: '洒金桥路', longitude: 108.9332, latitude: 34.2708, impact: 3, createTime: now - 8 * 60000
      },
      {
        id: 'E002', type: 1, title: '东大街辅道施工', description: '占用一条非机动车道，预计 3 日恢复',
        roadName: '东大街·端履门', longitude: 108.954, latitude: 34.2613, impact: 2, createTime: now - 42 * 60000
      },
      {
        id: 'E003', type: 0, title: '北大街两车剐蹭', description: '占用左侧车道，交警已到场',
        roadName: '北大街', longitude: 108.9488, latitude: 34.266, impact: 2, createTime: now - 15 * 60000
      },
      {
        id: 'E004', type: 2, title: '书院门步行街临时管制', description: '节假日人流管控，机动车禁止驶入',
        roadName: '书院门', longitude: 108.949, latitude: 34.2532, impact: 1, createTime: now - 120 * 60000
      }
    ];
  }
}
