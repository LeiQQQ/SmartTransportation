import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConstants } from '../constants/AppConstants';
import { ApiResponse } from '../base/ApiResponse';
import { LogUtil } from './LogUtil';

/**
 * HTTP 请求封装
 *
 * ArkTS 注意事项（本项目踩过的坑）：
 * - 禁止裸对象字面量（arkts-no-untyped-obj-literals），查询参数一律用字符串拼在 path 上
 * - 禁止 any / unknown（arkts-no-any-unknown），异常统一按 Error 处理
 * - POST 的 body 由调用方 JSON.stringify 后传入字符串
 *
 * 请求前需声明 ohos.permission.INTERNET（工程 module.json5 已声明）
 */
export class HttpUtil {
  private static readonly TAG: string = 'HttpUtil';

  /** GET 请求，path 形如 '/signal/evaluation/INT_10?scenario=%E6%97%A9%E9%AB%98%E5%B3%B0' */
  static get<T>(path: string): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(http.RequestMethod.GET, path, '');
  }

  /** POST 请求，bodyJson 为已序列化的 JSON 字符串，无 body 时留空 */
  static post<T>(path: string, bodyJson: string = ''): Promise<ApiResponse<T>> {
    return HttpUtil.request<T>(http.RequestMethod.POST, path, bodyJson);
  }

  private static request<T>(method: http.RequestMethod, path: string,
    bodyJson: string): Promise<ApiResponse<T>> {
    return new Promise<ApiResponse<T>>(
      (resolve: (value: ApiResponse<T>) => void, reject: (reason: Error) => void) => {
        const request: http.HttpRequest = http.createHttp();
        const url: string = AppConstants.BASE_URL + path;

        const options: http.HttpRequestOptions = {
          method: method,
          header: { 'Content-Type': 'application/json' },
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: AppConstants.HTTP_TIMEOUT_MS,
          readTimeout: AppConstants.HTTP_TIMEOUT_MS
        };
        if (bodyJson !== '') {
          options.extraData = bodyJson;
        }

        request.request(url, options, (err: BusinessError, data: http.HttpResponse) => {
          request.destroy();
          const error: BusinessError | undefined = err;
          if (error !== undefined) {
            LogUtil.warn(HttpUtil.TAG, `${url} failed: code=${error.code} ${error.message}`);
            reject(new Error(error.message));
            return;
          }
          try {
            const raw: string = data.result as string;
            const parsed: Object = JSON.parse(raw) as Object;
            resolve(parsed as ApiResponse<T>);
          } catch (e) {
            const message: string = (e as Error).message;
            LogUtil.error(HttpUtil.TAG, `${url} parse failed: ${message}`);
            reject(new Error('响应解析失败'));
          }
        });
      }
    );
  }
}
