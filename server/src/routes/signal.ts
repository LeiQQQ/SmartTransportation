import type { FastifyInstance } from 'fastify';
import { ok } from '../util/response.js';
import { signalService } from '../container.js';

/** 信号配时：方案查询、触发优化、优化评价 */
export default async function signalRoutes(app: FastifyInstance): Promise<void> {
  /** 当前配时方案 */
  app.get<{ Params: { id: string }; Querystring: { scenario?: string } }>('/plan/:id', async (request) =>
    ok(signalService.getPlan(request.params.id, request.query.scenario))
  );

  /** 触发一次优化，返回新方案与评价 */
  app.post<{ Params: { id: string }; Body: { scenario?: string } }>('/optimize/:id', async (request) => {
    const scenario: string = request.body?.scenario ?? '平峰';
    return ok(signalService.optimize(request.params.id, scenario));
  });

  /** 优化前后对比 */
  app.get<{ Params: { id: string }; Querystring: { scenario?: string } }>('/evaluation/:id', async (request) =>
    ok(signalService.getEvaluation(request.params.id, request.query.scenario ?? '平峰'))
  );
}
