import type { FastifyInstance } from 'fastify';
import { ok, fail } from '../util/response.js';
import { eventService } from '../container.js';
import type { CreateEventInput } from '../types/index.js';

/** 交通事件：列表查询与上报 */
export default async function eventRoutes(app: FastifyInstance): Promise<void> {
  /** 事件列表，支持 type 过滤与分页 */
  app.get<{ Querystring: { type?: string; page?: string; size?: string } }>('/events', async (request) => {
    const type: number | undefined = request.query.type === undefined
      ? undefined
      : Number(request.query.type);
    const page: number = Number(request.query.page ?? 1);
    const size: number = Number(request.query.size ?? 20);
    return ok(eventService.list(type, page, size));
  });

  /** 事件上报 */
  app.post<{ Body: CreateEventInput }>('/events', async (request, reply) => {
    const input: CreateEventInput | undefined = request.body;
    if (input === undefined || input.title === undefined || input.title === '') {
      return reply.code(400).send(fail('事件标题不能为空'));
    }
    const created = eventService.create(input);
    return ok({ id: created.id });
  });
}
