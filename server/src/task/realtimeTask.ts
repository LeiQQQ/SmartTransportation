import { BAIDU } from '../config.js';
import type { BaiduTrafficService } from '../service/BaiduTrafficService.js';

/**
 * 实时路况定时刷新任务
 *
 * 为什么要定时拉：IDataSource 是同步接口（路由层直接用返回值），
 * 而百度查询是异步的。这里在后台定期把实测快照刷新进内存，
 * 业务层同步读取最新快照，接口响应时间不受百度 RT 影响。
 *
 * 间隔 45 s：BaiduTrafficService 内部有 60 s 缓存，45 s 触发可保证缓存刚过期就补上，
 * 既不打爆个人 AK 的 QPS 配额，路况延迟也不超过 1 分钟。
 */

const REFRESH_MS: number = 45_000;

export function startRealtimeTask(service: BaiduTrafficService): NodeJS.Timeout | null {
  if (BAIDU.AK.length === 0) {
    console.log('[realtime] 未配置 BAIDU_AK，跳过定时刷新（使用纯仿真数据）');
    return null;
  }

  const tick = (): void => {
    service.getRealtimeRoads()
      .then((snap) => {
        console.log(`[realtime] ${snap.roads.length} 段路况，拥堵道路 ${snap.congestedRoads} 条，失败 ${snap.failedRoads.length} 条`);
      })
      .catch((error: unknown) => {
        console.error('[realtime] 刷新失败：', error instanceof Error ? error.message : String(error));
      });
  };

  tick(); // 启动即预热，首个业务请求即可用到实测
  const timer: NodeJS.Timeout = setInterval(tick, REFRESH_MS);
  timer.unref(); // 不阻塞进程退出
  return timer;
}
