import type { FastifyInstance } from 'fastify';
import { ok } from '../util/response.js';
import { trafficService } from '../container.js';

/** 路网数据：路口与路段 */
export default async function areaRoutes(app: FastifyInstance): Promise<void> {
  app.get('/intersections', async () => ok({ intersections: trafficService.getIntersections() }));

  app.get('/segments', async () => ok({ segments: trafficService.getSegments() }));
}
