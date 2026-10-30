/**
 * 统一响应包装
 * 端侧 ApiResponse.ets 按同样结构解析，字段不可随意改动
 */

export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
  timestamp: number;
}

export function ok<T>(data: T): ApiResponse<T> {
  return { code: 0, message: 'success', data: data, timestamp: Date.now() };
}

export function fail(message: string, code: number = 1): ApiResponse<null> {
  return { code: code, message: message, data: null, timestamp: Date.now() };
}
