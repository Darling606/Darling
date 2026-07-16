import { promptAction } from '@kit.ArkUI';

export class ToastUtils {
  static show(message: string, duration: number = 2000): void {
    promptAction.showToast({ message: message, duration: duration });
  }

  static showSuccess(message: string): void {
    promptAction.showToast({ message: message, duration: 1500 });
  }

  static showError(message: string): void {
    promptAction.showToast({ message: message, duration: 2500 });
  }
}
