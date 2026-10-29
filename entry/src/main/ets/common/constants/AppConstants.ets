/**
 * 全局配置
 */
export class AppConstants {
  /** 后端地址：局域网联调时改为宿主机 IP；模拟器访问宿主机用 10.0.2.2 */
  static readonly BASE_URL: string = 'http://10.0.2.2:8080/api/v1';

  /** 数据源开关：true 走真实后端，false 走本地 Mock（失败时自动降级为 Mock） */
  static readonly USE_REMOTE: boolean = false;

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
