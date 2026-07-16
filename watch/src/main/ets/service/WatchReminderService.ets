import reminderAgentManager from '@ohos.reminderAgentManager';
import vibrator from '@ohos.vibrator';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN: number = 0x0000;
const TAG: string = 'WatchReminderService';

export class WatchReminderService {
  static async notifyNow(title: string, content: string): Promise<void> {
    try {
      const request: reminderAgentManager.ReminderRequestTimer = {
        reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_TIMER,
        triggerTimeInSeconds: 1,
        title: title,
        content: content,
        expiredContent: content,
        ringDuration: 1,
        snoozeTimes: 0
      };
      await reminderAgentManager.publishReminder(request);
      hilog.info(DOMAIN, TAG, 'Reminder published: %{public}s', title);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Reminder unavailable, fallback in-app: %{public}s', JSON.stringify(err as object));
    }

    try {
      await vibrator.startVibration({
        type: 'time',
        duration: 500
      }, {
        id: 0,
        usage: 'alarm'
      });
      hilog.info(DOMAIN, TAG, 'Vibration started');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Vibration unavailable: %{public}s', JSON.stringify(err as object));
    }
  }
}
