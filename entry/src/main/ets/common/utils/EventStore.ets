import { TrafficEvent } from '../model/TrafficEvent';
import { PreferencesUtil } from './PreferencesUtil';

/**
 * 离线事件本地存储
 *
 * 写入：仅离线（MOCK / AUTO 探测失败）时上报的事件落这里，保证"上报 → 重启仍在"成立。
 * 读取：列表页始终合并「本地 + 服务端」，离线期间报的事件在联网后仍可见；
 *       在线上报只写服务端、不写本地，因此两处不会重复。
 */
export class EventStore {
  private static readonly KEY: string = 'local_reported_events';
  private static readonly MAX: number = 50;

  static async list(): Promise<TrafficEvent[]> {
    const raw: string = await PreferencesUtil.getString(EventStore.KEY, '');
    if (raw.length === 0) {
      return [];
    }
    try {
      const list: TrafficEvent[] = JSON.parse(raw) as TrafficEvent[];
      return list;
    } catch (e) {
      return [];
    }
  }

  static async add(event: TrafficEvent): Promise<void> {
    const list: TrafficEvent[] = await EventStore.list();
    list.unshift(event);
    const kept: TrafficEvent[] = list.length > EventStore.MAX
      ? list.slice(0, EventStore.MAX)
      : list;
    await PreferencesUtil.putString(EventStore.KEY, JSON.stringify(kept));
  }

  static async count(): Promise<number> {
    const list: TrafficEvent[] = await EventStore.list();
    return list.length;
  }
}
