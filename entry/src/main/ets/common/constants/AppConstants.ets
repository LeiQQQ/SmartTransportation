/**
 * 全局配置
 */
export class AppConstants {
  /** 后端地址：局域网联调时改为宿主机 IP；模拟器访问宿主机用 10.0.2.2（该地址需实测确认） */
  static readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';

  /**
   * 数据源模式
   * MOCK   恒用本地仿真，不发网络请求（默认，保证演示必定成功）
   * AUTO   启动时探测 /health，成功走远程，失败回落本地（联调与答辩推荐）
   * REMOTE 硬连远程，失败由 RemoteTrafficRepository 回落本地
   */
  static readonly DATA_SOURCE_MODE: string = 'MOCK';

  /** 是否启用远程数据源（由 DATA_SOURCE_MODE 派生，保留以兼容既有调用） */
  static readonly USE_REMOTE: boolean = AppConstants.DATA_SOURCE_MODE !== 'MOCK';

  /** 地图渲染模式：'TOPOLOGY' 拓扑图（默认，零依赖） | 'MAP_KIT' 花瓣地图 */
  static readonly MAP_MODE: string = 'TOPOLOGY';

  /** 刷新间隔（毫秒） */
  static readonly REFRESH_INDEX_MS: number = 30000;
  static readonly REFRESH_FLOW_MS: number = 5000;
  static readonly ANIMATION_FRAME_MS: number = 200;

  /** 路口动画中每个相位的模拟秒数（加速演示） */
  static readonly PHASE_DEMO_SECONDS: number = 8;

  /** 网络超时 */
  static readonly HTTP_TIMEOUT_MS: number = 10000;

  /** 数据自动降级提示文案 */
  static readonly TIP_OFFLINE: string = '当前为离线仿真数据';
}
