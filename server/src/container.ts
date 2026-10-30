import { SimulationDataSource } from './source/SimulationDataSource.js';
import { TrafficService } from './service/TrafficService.js';
import { SignalService } from './service/SignalService.js';
import { EventService } from './service/EventService.js';

/**
 * 依赖装配（简易容器）
 * 所有 Service 在此统一创建，路由层只取用、不自行 new，方便后续替换数据源或加存储实现
 */

export const dataSource = new SimulationDataSource();
export const trafficService = new TrafficService(dataSource);
export const signalService = new SignalService(dataSource);
export const eventService = new EventService();
