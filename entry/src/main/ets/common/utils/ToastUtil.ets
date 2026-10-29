import { promptAction } from '@kit.ArkUI';

export class ToastUtil {
  static show(message: string): void {
    promptAction.showToast({ message: message, duration: 2000 });
  }
}
