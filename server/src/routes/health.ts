import type { FastifyInstance } from 'fastify';
import { ok } from '../util/response.js';
import { dataSource } from '../container.js';

/**
 * 健康检查 / 数据源探测
 * 端侧 AUTO 模式启动时先请求此接口：成功走远程，失败或超时回落本地 Mock
 */
export default async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/health', async () =>
    ok({
      status: 'ok',
      dataSource: dataSource.name,
      algoVersion: 'webster-1.0',
      serverTime: Date.now()
    })
  );
}
