/**
 * 统一响应结构
 * 与后端 server/src/util/response.ts 的 ApiResponse<T> 一一对应
 *
 * { code: 0, message: 'success', data: T, timestamp: number }
 */
export interface ApiResponse<T> {
  /** 0 表示成功，非 0 为业务失败 */
  code: number;
  message: string;
  data: T;
  /** 服务端时间戳（毫秒） */
  timestamp: number;
}
