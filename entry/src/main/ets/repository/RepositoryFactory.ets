import { ITrafficRepository } from './ITrafficRepository';
import { MockTrafficRepository } from './MockTrafficRepository';
import { AppConstants } from '../common/constants/AppConstants';

/**
 * 数据源工厂：按配置选择实现
 */
export class RepositoryFactory {
  private static mock: MockTrafficRepository | undefined = undefined;

  static getTrafficRepository(): ITrafficRepository {
    // 当前阶段统一使用本地仿真数据；接入后端后改为按 AppConstants.USE_REMOTE 选择
    if (RepositoryFactory.mock === undefined) {
      RepositoryFactory.mock = new MockTrafficRepository();
    }
    return RepositoryFactory.mock;
  }

  static isOffline(): boolean {
    return !AppConstants.USE_REMOTE;
  }
}
