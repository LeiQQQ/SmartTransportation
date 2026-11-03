/**
 * 全局配置
 */
export class AppConstants {
  /**
   * 后端候选地址（AUTO 模式下按顺序探测，第一个 /health 成功的被锁定）
   * - 局域网 IP：真机 / 模拟器与电脑同一 WiFi 时首选（换网络需改这里）
   * - 10.0.2.2：部分模拟器访问宿主机的约定地址
   * - 127.0.0.1：端侧与后端同机时（一般仅调试）
   */
  static readonly BASE_URL_CANDIDATES: string[] = [
    'http://10.124.10.210:8080/api/v1',
    'http://10.0.2.2:8080/api/v1',
    'http://127.0.0.1:8080/api/v1'
  ];

  /** 当前生效的后端地址：AUTO/REMOTE 探测成功后锁定为候选之一 */
  static BASE_URL: string = 'http://10.124.10.210:8080/api/v1';

  /**
   * 数据源模式
   * MOCK   恒用本地仿真，不发网络请求（离线兜底，事件存 preferences）
   * AUTO   启动时逐个探测候选地址的 /health，成功走远程，失败回落本地（推荐）
   * REMOTE 硬连远程，失败由 RemoteTrafficRepository 回落本地
   */
  static readonly DATA_SOURCE_MODE: string = 'AUTO';

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
  /** 探测超时：多个候选地址逐个试，单个不宜过长 */
  static readonly PROBE_TIMEOUT_MS: number = 1500;

  /** 数据自动降级提示文案 */
  static readonly TIP_OFFLINE: string = '当前为离线仿真数据';
}
