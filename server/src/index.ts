import Fastify from 'fastify';
import { SERVER } from './config.js';
import { fail } from './util/response.js';
import healthRoutes from './routes/health.js';
import areaRoutes from './routes/area.js';
import trafficRoutes from './routes/traffic.js';
import signalRoutes from './routes/signal.js';
import eventRoutes from './routes/event.js';

/**
 * 智慧交通后端服务入口
 *
 * 分层：routes（接口）→ service（业务）→ source（数据源）+ algo（算法）
 * 接口前缀 /api/v1，统一响应 { code, message, data, timestamp }
 */

const app = Fastify({ logger: true });

// 统一错误处理：业务异常不暴露堆栈
app.setErrorHandler((error, _request, reply) => {
  app.log.error(error);
  const message: string = error instanceof Error ? error.message : String(error);
  reply.code(500).send(fail(message || '服务器内部错误'));
});

app.setNotFoundHandler((request, reply) => {
  reply.code(404).send(fail(`接口不存在：${request.url}`));
});

// 服务根路径：方便快速确认是否在线
app.get('/', async () => ({
  service: 'smart-transportation-server',
  version: '0.1.0',
  health: '/api/v1/health'
}));

// 路由注册（同一前缀下按模块划分）
await app.register(healthRoutes, { prefix: SERVER.API_PREFIX });
await app.register(areaRoutes, { prefix: `${SERVER.API_PREFIX}/area` });
await app.register(trafficRoutes, { prefix: `${SERVER.API_PREFIX}/traffic` });
await app.register(signalRoutes, { prefix: `${SERVER.API_PREFIX}/signal` });
await app.register(eventRoutes, { prefix: SERVER.API_PREFIX });

try {
  await app.listen({ port: SERVER.PORT, host: SERVER.HOST });
  console.log(`[server] started: http://localhost:${SERVER.PORT}${SERVER.API_PREFIX}/health`);
} catch (error) {
  app.log.error(error);
  process.exit(1);
}
