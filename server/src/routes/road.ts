import type { FastifyInstance } from 'fastify';
import { ok } from '../util/response.js';
import { baiduTrafficService } from '../container.js';

/** 百度实时路况 */
export default async function roadRoutes(app: FastifyInstance): Promise<void> {
  /**
   * 西安城墙内 32 条路段的实时路况（来源：百度 /traffic/v1/road，60 s 缓存）
   * ?force=1 强制刷新缓存；AK 未配置或全部查询失败时 ok=false
   */
  app.get<{ Querystring: { force?: string } }>('/realtime', async (request) =>
    ok(await baiduTrafficService.getRealtimeRoads(request.query.force === '1'))
  );
}
