import { router } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';
import { WatchFeedReminder, COLORS } from '../model/WatchDataModels';

@Entry
@Component
struct FeedReminderPage {
  @State reminders: WatchFeedReminder[] = [];
  @State petId: string = '';

  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['petId']) {
      this.petId = params['petId'];
    }
    this.loadReminders();
    
    // 设置喂食提醒回调
    this.dataManager.onFeedReminderChanged = (reminder: WatchFeedReminder) => {
      // 检查是否已存在
      const exists = this.reminders.find(r => r.id === reminder.id);
      if (!exists) {
        this.reminders.push(reminder);
      }
    };
  }

  aboutToDisappear(): void {
    this.dataManager.onFeedReminderChanged = null;
  }

  async loadReminders(): Promise<void> {
    if (this.petId) {
      this.reminders = await this.dataManager.getFeedReminders(this.petId);
    } else {
      const pets = await this.dataManager.getAllPetInfo();
      if (pets.length > 0) {
        this.petId = pets[0].id;
        this.reminders = await this.dataManager.getFeedReminders(this.petId);
      }
    }
  }

  async toggleReminder(reminder: WatchFeedReminder): Promise<void> {
    reminder.enabled = !reminder.enabled;
    await this.dataManager.saveFeedReminder(reminder);
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(20)
          .fontColor(COLORS.primary)
          .onClick(() => {
            try {
              router.back();
            } catch (err) {
              console.error('Navigate back failed:', JSON.stringify(err));
            }
          })
        Text('喂食提醒')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textPrimary)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('')
          .width(20)
      }
      .width('100%')
      .height(48)
      .padding({ left: 16, right: 16 })

      if (this.reminders.length === 0) {
        Column() {
          Text('⏰')
            .fontSize(48)
            .margin({ bottom: 16 })

          Text('暂无喂食提醒')
            .fontSize(16)
            .fontColor(COLORS.textPrimary)

          Text('请在手机端设置喂食计划')
            .fontSize(12)
            .fontColor(COLORS.textHint)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 80 })
      } else {
        List() {
          ForEach(this.reminders, (reminder: WatchFeedReminder) => {
            ListItem() {
              Row() {
                Column() {
                  Text(reminder.time)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(COLORS.textPrimary)

                  Row() {
                    Text(reminder.amount)
                      .fontSize(12)
                      .fontColor(COLORS.textSecondary)
                    Text(' · ')
                      .fontSize(12)
                      .fontColor(COLORS.textHint)
                    Text(reminder.type)
                      .fontSize(12)
                      .fontColor(COLORS.textSecondary)
                  }
                  .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                Toggle({ type: ToggleType.Switch, isOn: reminder.enabled })
                  .selectedColor(COLORS.primary)
                  .switchPointColor('#FFFFFF')
                  .onChange(() => {
                    this.toggleReminder(reminder);
                  })
              }
              .width('100%')
              .padding(16)
              .backgroundColor(COLORS.card)
              .borderRadius(12)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.background)
  }
}
