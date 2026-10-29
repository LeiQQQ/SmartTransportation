import { PreferencesUtil } from './PreferencesUtil';

/**
 * 收藏路口管理（以逗号分隔的 id 串存储，避免 JSON 解析的类型风险）
 */
export class FavoriteUtil {
  private static readonly KEY: string = 'favorite_intersections';
  private static cache: string[] | undefined = undefined;

  static async list(): Promise<string[]> {
    if (FavoriteUtil.cache !== undefined) {
      return FavoriteUtil.cache;
    }
    const raw: string = await PreferencesUtil.getString(FavoriteUtil.KEY, '');
    const ids: string[] = raw.length === 0 ? [] : raw.split(',');
    const result: string[] = [];
    for (let i = 0; i < ids.length; i++) {
      if (ids[i].length > 0) {
        result.push(ids[i]);
      }
    }
    FavoriteUtil.cache = result;
    return result;
  }

  static async contains(id: string): Promise<boolean> {
    const ids: string[] = await FavoriteUtil.list();
    return ids.indexOf(id) >= 0;
  }

  static async count(): Promise<number> {
    const ids: string[] = await FavoriteUtil.list();
    return ids.length;
  }

  /** 返回操作后的收藏状态：true 已收藏 */
  static async toggle(id: string): Promise<boolean> {
    const ids: string[] = await FavoriteUtil.list();
    const next: string[] = [];
    let added: boolean = false;
    const index: number = ids.indexOf(id);
    if (index >= 0) {
      for (let i = 0; i < ids.length; i++) {
        if (i !== index) {
          next.push(ids[i]);
        }
      }
    } else {
      for (let i = 0; i < ids.length; i++) {
        next.push(ids[i]);
      }
      next.push(id);
      added = true;
    }
    FavoriteUtil.cache = next;
    await PreferencesUtil.putString(FavoriteUtil.KEY, next.join(','));
    return added;
  }
}
