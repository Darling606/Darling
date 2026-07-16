import { router } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';
import { WatchBehaviorAlert, COLORS } from '../model/WatchDataModels';

@Entry
@Component
struct BehaviorAlertPage {
  @State alerts: WatchBehaviorAlert[] = [];
  @State petId: string = '';

  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['petId']) {
      this.petId = params['petId'];
    }
    this.loadAlerts();
    
    // 设置行为预警回调
    this.dataManager.onBehaviorAlertChanged = (alert: WatchBehaviorAlert) => {
      // 检查是否已存在
      const exists = this.alerts.find(a => a.id === alert.id);
      if (!exists) {
        this.alerts.unshift(alert);
        this.alerts.sort((a, b) => b.timestamp - a.timestamp);
      }
    };
  }

  aboutToDisappear(): void {
    this.dataManager.onBehaviorAlertChanged = null;
  }

  async loadAlerts(): Promise<void> {
    if (this.petId) {
      this.alerts = await this.dataManager.getBehaviorAlerts(this.petId);
    } else {
      const pets = await this.dataManager.getAllPetInfo();
      if (pets.length > 0) {
        this.petId = pets[0].id;
        this.alerts = await this.dataManager.getBehaviorAlerts(this.petId);
      }
    }
    this.alerts.sort((a, b) => b.timestamp - a.timestamp);
  }

  async markAsRead(alert: WatchBehaviorAlert): Promise<void> {
    if (!alert.read) {
      alert.read = true;
      await this.dataManager.markAlertRead(alert.id);
    }
  }

  getAlertIcon(type: string): string {
    switch (type) {
      case '异常': return '⚠️';
      case '焦虑': return '😰';
      case '攻击': return '😡';
      case '异食': return '🤮';
      default: return '🔔';
    }
  }

  getAlertColor(type: string): string {
    switch (type) {
      case '异常': return COLORS.danger;
      case '焦虑': return COLORS.warning;
      case '攻击': return COLORS.danger;
      case '异食': return COLORS.warning;
      default: return COLORS.primary;
    }
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(20)
          .fontColor(COLORS.primary)
          .onClick(() => {
            try {
              router.back()
            } catch (err) {
              console.error('Navigate back failed:', JSON.stringify(err));
            }
          })
        Text('行为预警')
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

      if (this.alerts.length === 0) {
        Column() {
          Text('🔔')
            .fontSize(48)
            .margin({ bottom: 16 })

          Text('暂无预警消息')
            .fontSize(16)
            .fontColor(COLORS.textPrimary)

          Text('宠物行为正常')
            .fontSize(12)
            .fontColor(COLORS.success)
            .margin({ top: 8 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 80 })
      } else {
        List() {
          ForEach(this.alerts, (alert: WatchBehaviorAlert) => {
            ListItem() {
              Row() {
                Text(this.getAlertIcon(alert.type))
                  .fontSize(24)
                  .margin({ right: 12 })

                Column() {
                  Row() {
                    Text(alert.type)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(this.getAlertColor(alert.type))

                    if (!alert.read) {
                      Text('新')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .backgroundColor(COLORS.danger)
                        .borderRadius(4)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .margin({ left: 8 })
                    }
                  }

                  Text(alert.message)
                    .fontSize(12)
                    .fontColor(COLORS.textSecondary)
                    .margin({ top: 4 })

                  Text(this.formatTime(alert.timestamp))
                    .fontSize(10)
                    .fontColor(COLORS.textHint)
                    .margin({ top: 4 })
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(alert.read ? COLORS.card : COLORS.cardHighlight)
              .borderRadius(12)
              .onClick(() => {
                this.markAsRead(alert);
              })
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

  formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    const month = (date.getMonth() + 1).toString().padStart(2, '0');
    const day = date.getDate().toString().padStart(2, '0');
    const hours = date.getHours().toString().padStart(2, '0');
    const minutes = date.getMinutes().toString().padStart(2, '0');
    return `${month}-${day} ${hours}:${minutes}`;
  }
}
