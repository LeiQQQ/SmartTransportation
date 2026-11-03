import { db } from '../store/sqlite.js';
import type { CreateEventInput, TrafficEvent } from '../types/index.js';

/** 事件表行结构（列名为 snake_case） */
interface EventRow {
  id: string;
  type: number;
  title: string;
  road_name: string;
  longitude: number;
  latitude: number;
  impact: number;
  description: string;
  create_time: number;
}

const INSERT_SQL: string =
  'INSERT INTO event (id, type, title, road_name, longitude, latitude, impact, description, create_time) ' +
  'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)';

/**
 * 交通事件业务
 *
 * 数据落 SQLite（server/data/store.db）：
 * - 服务重启不丢失（区别于 P1 的内存数组）
 * - 多台设备访问同一后端即可看到同一份事件（数据互通）
 */
export class EventService {
  constructor() {
    this.seedIfEmpty();
  }

  /** 表为空时写入 4 条演示事件；已有数据则跳过，避免每次重启重复插入 */
  private seedIfEmpty(): void {
    const row = db.prepare('SELECT COUNT(*) AS n FROM event').get() as { n: number } | undefined;
    if ((row?.n ?? 0) > 0) {
      return;
    }
    const stmt = db.prepare(INSERT_SQL);
    for (const event of EventService.seed()) {
      stmt.run(
        event.id, event.type, event.title, event.roadName,
        event.longitude, event.latitude, event.impact,
        event.description, event.createTime
      );
    }
  }

  /** @param type 事件类型过滤，undefined 表示全部 */
  list(type: number | undefined, page: number = 1, size: number = 20): { events: TrafficEvent[]; total: number } {
    const safePage: number = page < 1 ? 1 : page;
    const safeSize: number = size < 1 ? 20 : size;
    const offset: number = (safePage - 1) * safeSize;

    const countSql: string = type === undefined
      ? 'SELECT COUNT(*) AS n FROM event'
      : 'SELECT COUNT(*) AS n FROM event WHERE type = ?';
    const countRow = (type === undefined
      ? db.prepare(countSql).get()
      : db.prepare(countSql).get(type)) as { n: number } | undefined;
    const total: number = countRow?.n ?? 0;

    const pageSql: string = type === undefined
      ? 'SELECT * FROM event ORDER BY create_time DESC LIMIT ? OFFSET ?'
      : 'SELECT * FROM event WHERE type = ? ORDER BY create_time DESC LIMIT ? OFFSET ?';
    const rows = (type === undefined
      ? db.prepare(pageSql).all(safeSize, offset)
      : db.prepare(pageSql).all(type, safeSize, offset)) as unknown as EventRow[];

    const events: TrafficEvent[] = [];
    for (const row of rows) {
      events.push(EventService.toEvent(row));
    }
    return { events: events, total: total };
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
    db.prepare(INSERT_SQL).run(
      event.id, event.type, event.title, event.roadName,
      event.longitude, event.latitude, event.impact,
      event.description, event.createTime
    );
    return event;
  }

  private static toEvent(row: EventRow): TrafficEvent {
    return {
      id: row.id,
      type: row.type,
      title: row.title,
      description: row.description,
      roadName: row.road_name,
      longitude: row.longitude,
      latitude: row.latitude,
      impact: row.impact,
      createTime: row.create_time
    };
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
