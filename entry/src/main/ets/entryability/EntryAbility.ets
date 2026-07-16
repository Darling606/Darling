import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { PhoneDistributedManager } from '../model/PhoneDistributedManager';
import { StorageManager } from '../model/StorageManager';
import { CalendarStorage } from '../service/CalendarStorage';

const DOMAIN: number = 0x0000;

export default class EntryAbility extends UIAbility {
  private dataManager: PhoneDistributedManager = PhoneDistributedManager.getInstance();
  private storageManager: StorageManager = StorageManager.getInstance();
  private calendarStorage: CalendarStorage = new CalendarStorage();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to set colorMode. Cause: %{public}s', err.message);
    }
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onWindowStageCreate');

    try {
      await this.storageManager.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', 'StorageManager initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to init StorageManager: %{public}s', err.message);
    }

    try {
      await this.dataManager.init(this.context);
      hilog.info(DOMAIN, 'EntryAbility', 'PhoneDistributedManager initialized successfully');
      await this.calendarStorage.init(this.context);
      const pets = await this.storageManager.getPetList();
      const feedPlans = await this.storageManager.getFeedPlans();
      const events = await this.calendarStorage.getEvents();
      for (let i = 0; i < pets.length; i++) {
        await this.dataManager.syncPetInfoToWatch(pets[i]);
      }
      for (let i = 0; i < feedPlans.length; i++) {
        await this.dataManager.syncFeedPlanToWatch(feedPlans[i]);
      }
      for (let i = 0; i < events.length; i++) {
        await this.dataManager.syncCalendarEventToWatch(events[i]);
      }
      await this.dataManager.syncPetSnapshotToWatch(pets, feedPlans, events);
    } catch (err) {
      hilog.error(DOMAIN, 'EntryAbility', 'Failed to init PhoneDistributedManager: %{public}s', err.message);
    }

    windowStage.loadContent('pages/LoginPage', (err: Error) => {
      if (err) {
        hilog.error(DOMAIN, 'EntryAbility', 'Failed to load the content. Cause: %{public}s', err.message);
        return;
      }
      hilog.info(DOMAIN, 'EntryAbility', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'EntryAbility', '%{public}s', 'Ability onBackground');
  }
}
