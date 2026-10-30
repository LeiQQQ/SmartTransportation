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

  /** 探测后端是否可用，返回 true 表示后续走远程数据源 */
  static async probeRemote(): Promise<boolean> {
    try {
      const response = await HttpUtil.get<HealthData>('/health');
      RepositoryFactory.remoteAvailable = response.code === 0 && response.data?.status === 'ok';
    } catch (error) {
      RepositoryFactory.remoteAvailable = false;
    }
    RepositoryFactory.probed = true;
    LogUtil.info(RepositoryFactory.TAG,
      RepositoryFactory.remoteAvailable ? '远程数据源可用' : '远程数据源不可用，使用本地仿真数据');
    return RepositoryFactory.remoteAvailable;
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
