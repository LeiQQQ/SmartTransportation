import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { LogUtil } from './LogUtil';

/**
 * 轻量键值存储封装（收藏、设置、待同步事件）
 */
export class PreferencesUtil {
  private static readonly STORE_NAME: string = 'smart_transport';
  private static cached: preferences.Preferences | undefined = undefined;

  private static async getStore(): Promise<preferences.Preferences | undefined> {
    if (PreferencesUtil.cached !== undefined) {
      return PreferencesUtil.cached;
    }
    const ctx: common.Context | undefined = AppStorage.get<common.Context>('appContext');
    if (ctx === undefined) {
      return undefined;
    }
    try {
      const options: preferences.Options = { name: PreferencesUtil.STORE_NAME };
      PreferencesUtil.cached = await preferences.getPreferences(ctx, options);
      return PreferencesUtil.cached;
    } catch (e) {
      LogUtil.error('PreferencesUtil', 'init failed: ' + JSON.stringify(e));
      return undefined;
    }
  }

  static async putString(key: string, value: string): Promise<void> {
    const store: preferences.Preferences | undefined = await PreferencesUtil.getStore();
    if (store === undefined) {
      return;
    }
    await store.put(key, value);
    await store.flush();
  }

  static async getString(key: string, defValue: string): Promise<string> {
    const store: preferences.Preferences | undefined = await PreferencesUtil.getStore();
    if (store === undefined) {
      return defValue;
    }
    const value: preferences.ValueType = await store.get(key, defValue);
    return value as string;
  }

  static async putBoolean(key: string, value: boolean): Promise<void> {
    const store: preferences.Preferences | undefined = await PreferencesUtil.getStore();
    if (store === undefined) {
      return;
    }
    await store.put(key, value);
    await store.flush();
  }

  static async getBoolean(key: string, defValue: boolean): Promise<boolean> {
    const store: preferences.Preferences | undefined = await PreferencesUtil.getStore();
    if (store === undefined) {
      return defValue;
    }
    const value: preferences.ValueType = await store.get(key, defValue);
    return value as boolean;
  }
}
