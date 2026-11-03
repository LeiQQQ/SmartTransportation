import { ITrafficRepository } from './ITrafficRepository';
import { MockTrafficRepository } from './MockTrafficRepository';
import { RemoteTrafficRepository } from './RemoteTrafficRepository';
import { AppConstants } from '../common/constants/AppConstants';
import { HttpUtil } from '../common/utils/HttpUtil';
import { LogUtil } from '../common/utils/LogUtil';
import { HealthData } from './dto/RemoteDtos';

/**
 * 数据源工厂（三态）
 *
 * | 模式    | 行为                                             |
 * | ------- | ------------------------------------------------ |
 * | MOCK    | 恒用本地仿真，不发网络请求                       |
 * | AUTO    | 先探测 /health，成功走远程，失败回落本地（推荐） |
 * | REMOTE  | 硬连远程，失败由 RemoteTrafficRepository 兜底    |
 *
 * 使用：App 启动时调用一次 probeRemote()，之后 getTrafficRepository() 同步返回对应实现。
 */
export class RepositoryFactory {
  private static readonly TAG: string = 'RepoFactory';

  private static mock: MockTrafficRepository | undefined = undefined;
  private static remote: RemoteTrafficRepository | undefined = undefined;

  /** 探测是否已执行 */
  private static probed: boolean = false;
  /** 探测结果：远程是否可用 */
  private static remoteAvailable: boolean = false;
  /** 进行中的探测（避免并发重复探测） */
  private static probing: Promise<boolean> | undefined = undefined;

  static getTrafficRepository(): ITrafficRepository {
    const mode: string = AppConstants.DATA_SOURCE_MODE;

    if (mode === 'REMOTE') {
      return RepositoryFactory.remoteInstance();
    }
    if (mode === 'MOCK') {
      return RepositoryFactory.mockInstance();
    }
    // AUTO：探测完成且远程可用时走远程，否则本地
    if (RepositoryFactory.probed && RepositoryFactory.remoteAvailable) {
      return RepositoryFactory.remoteInstance();
    }
    return RepositoryFactory.mockInstance();
  }

  /**
   * 逐个探测候选地址，第一个 /health 成功的锁定为 BASE_URL
   * @returns true 表示后续走远程数据源
   */
  static async probeRemote(): Promise<boolean> {
    if (AppConstants.DATA_SOURCE_MODE === 'MOCK') {
      RepositoryFactory.probed = true;
      RepositoryFactory.remoteAvailable = false;
      return false;
    }
    const candidates: string[] = AppConstants.BASE_URL_CANDIDATES;
    for (let i = 0; i < candidates.length; i++) {
      const url: string = candidates[i];
      AppConstants.BASE_URL = url;
      try {
        const response = await HttpUtil.get<HealthData>('/health', AppConstants.PROBE_TIMEOUT_MS);
        if (response.code === 0 && response.data?.status === 'ok') {
          RepositoryFactory.remoteAvailable = true;
          RepositoryFactory.probed = true;
          LogUtil.info(RepositoryFactory.TAG, '远程数据源可用：' + url);
          return true;
        }
      } catch (error) {
        LogUtil.warn(RepositoryFactory.TAG, '探测失败：' + url);
      }
    }
    AppConstants.BASE_URL = candidates[0];
    RepositoryFactory.remoteAvailable = false;
    RepositoryFactory.probed = true;
    LogUtil.info(RepositoryFactory.TAG, '远程数据源不可用，使用本地仿真数据');
    return false;
  }

  /**
   * 确保探测已完成（并发调用只执行一次）
   * 写操作前调用：避免"还没探测完就把数据写进本地"，导致重启后与后端不一致
   */
  static probeOnce(): Promise<boolean> {
    if (RepositoryFactory.probing !== undefined) {
      return RepositoryFactory.probing;
    }
    if (RepositoryFactory.probed) {
      return Promise.resolve(RepositoryFactory.remoteAvailable);
    }
    RepositoryFactory.probing = RepositoryFactory.probeRemote().then((available: boolean) => {
      RepositoryFactory.probing = undefined;
      return available;
    });
    return RepositoryFactory.probing;
  }

  /** 当前是否处于离线（本地仿真）状态，用于首页提示条 */
  static isOffline(): boolean {
    const mode: string = AppConstants.DATA_SOURCE_MODE;
    if (mode === 'MOCK') {
      return true;
    }
    if (mode === 'REMOTE') {
      return false;
    }
    return !(RepositoryFactory.probed && RepositoryFactory.remoteAvailable);
  }

  private static mockInstance(): MockTrafficRepository {
    if (RepositoryFactory.mock === undefined) {
      RepositoryFactory.mock = new MockTrafficRepository();
    }
    return RepositoryFactory.mock;
  }

  private static remoteInstance(): RemoteTrafficRepository {
    if (RepositoryFactory.remote === undefined) {
      RepositoryFactory.remote = new RemoteTrafficRepository();
    }
    return RepositoryFactory.remote;
  }
}
