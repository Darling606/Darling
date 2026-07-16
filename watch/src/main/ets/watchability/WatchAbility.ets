import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';

const DOMAIN = 0x0000;
const TAG = 'WatchAbility';

export default class WatchAbility extends UIAbility {
  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, '%{public}s', 'Ability onDestroy');
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {

    hilog.info(
      0x0000,
      'WATCH_ABILITY',
      'ABILITY_START'
    );

    hilog.info(
      0x0000,
      'WATCH_ABILITY',
      'BEFORE_INIT'
    );


    try {
      await this.dataManager.initStore(this.context);
    } catch (err) {
      hilog.error(0x0000, 'WATCH_ABILITY', 'Init store failed: %{public}s', JSON.stringify(err as object));
    }

    hilog.info(
      0x0000,
      'WATCH_ABILITY',
      'AFTER_INIT'
    );

    setTimeout(async () => {

      hilog.info(
        0x0000,
        'WATCH_TEST',
        'START_GET_PETS'
      );

      let pets = await this.dataManager.getAllPetInfo();

      hilog.info(
        0x0000,
        'WATCH_TEST',
        'PET_COUNT=' + pets.length
      );

    }, 5000);

    // 注意：loadContent 要放在方法里面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(
          DOMAIN,
          TAG,
          'Failed to load the content. Cause: %{public}s',
          JSON.stringify(err)
        );
        return;
      }

      hilog.info(
        DOMAIN,
        TAG,
        'Succeeded in loading the content.'
      );
    });
  }
}