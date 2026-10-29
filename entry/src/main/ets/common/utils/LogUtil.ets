import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0A01;
const TAG: string = 'SmartTransport';

export class LogUtil {
  static info(tag: string, msg: string): void {
    hilog.info(DOMAIN, TAG, '%{public}s', '[' + tag + '] ' + msg);
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(DOMAIN, TAG, '%{public}s', '[' + tag + '] ' + msg);
  }

  static error(tag: string, msg: string): void {
    hilog.error(DOMAIN, TAG, '%{public}s', '[' + tag + '] ' + msg);
  }
}
