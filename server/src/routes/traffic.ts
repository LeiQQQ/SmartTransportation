import type { FastifyInstance } from 'fastify';
import { ok, fail } from '../util/response.js';
import { trafficService } from '../container.js';

/** 交通流：片区指数、路口流量 */
export default async function trafficRoutes(app: FastifyInstance): Promise<void> {
  /** 片区拥堵指数 */
  app.get<{ Querystring: { scenario?: string } }>('/index', async (request) =>
    ok(trafficService.getAreaIndex(request.query.scenario))
  );

  /** 流量列表，可用 codes=INT_01,INT_02 指定路口 */
  app.get<{ Querystring: { codes?: string; scenario?: string } }>('/flow', async (request) => {
    const codes: string[] = (request.query.codes ?? '')
      .split(',')
      .map((code) => code.trim())
      .filter((code) => code.length > 0);
    return ok({ flows: trafficService.getFlows(codes, request.query.scenario) });
  });

  /** 单路口流量 */
  app.get<{ Params: { id: string }; Querystring: { scenario?: string } }>('/flow/:id', async (request, reply) => {
    const record = trafficService.getFlow(request.params.id, request.query.scenario);
    if (record === undefined) {
      return reply.code(404).send(fail(`路口不存在：${request.params.id}`));
    }
    return ok(record);
  });
}
