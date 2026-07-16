import router from '@ohos.router';
import { PetCompanion } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { AchievementService, Achievement } from '../service/AchievementService';
import { ColorConstants } from '../model/ColorConstants';
import { BounceCard, BounceEmptyState } from '../components/BounceComponents';
import { LineIcon, LineIconName } from '../components/LineIcons';

@Entry
@Component
export struct AchievementPage {
  @State achievements: Achievement[] = [];
  @State isLoading: boolean = true;

  private storage: CompanionStorage = CompanionStorage.getInstance();

  private getAchievementIconName(id: string): LineIconName {
    if (id.indexOf('CHAT') >= 0) { return 'chat'; }
    if (id.indexOf('LEVEL') >= 0) { return 'star'; }
    if (id.indexOf('INTIMACY') >= 0) { return 'heart'; }
    if (id.indexOf('MEMORY') >= 0) { return 'book'; }
    return 'trophy';
  }

  async aboutToAppear(): Promise<void> {
    await this.storage.init(getContext(this));
    const account = 'default_user';
    const companion = await this.storage.getCompanion(account);
    if (companion !== null) {
      this.achievements = AchievementService.getAllAchievements(companion);
    }
    this.isLoading = false;
  }

  build() {
    Column() {
      Row() {
        Text('\u2190')
          .fontSize(20).fontColor(ColorConstants.PRIMARY)
          .padding({ left: 4, right: 12, top: 8, bottom: 8 })
          .onClick(() => { try { router.back(); } catch (err) { } })

        Text('\u6210\u5C31\u6BBF\u5802')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
          .layoutWeight(1)

        Text(this.achievements.filter(a => a.unlocked).length.toString() + '/' + this.achievements.length.toString())
          .fontSize(14).fontColor(ColorConstants.TEXT_TERTIARY)
          .padding({ right: 4 })
      }
      .width('100%').height(52).padding({ left: 16, right: 16 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .shadow({ radius: 12, color: ColorConstants.SHADOW_COLOR, offsetX: 0, offsetY: 4 })

      if (this.isLoading) {
        Column({ space: 12 }) {
          LoadingProgress().width(32).height(32).color(ColorConstants.PRIMARY)
          Text('鍔犺浇涓?..').fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.achievements, (achievement: Achievement) => {
            ListItem() {
              BounceCard({ customWidth: '100%', customPadding: 16, customRadius: 16 }) {
                Row({ space: 14 }) {
                  Column() {
                    LineIcon({
                      name: achievement.unlocked ? this.getAchievementIconName(achievement.id) : 'lock',
                      iconSize: 28,
                      color: achievement.unlocked ? ColorConstants.PRIMARY : ColorConstants.TEXT_TERTIARY
                    })
                  }
                  .width(56).height(56).borderRadius(16)
                  .backgroundColor(achievement.unlocked ? '#FFF0F5' : '#F0F0F0')
                  .justifyContent(FlexAlign.Center)
                  .opacity(achievement.unlocked ? 1 : 0.4)

                  Column({ space: 4 }) {
                    Text(achievement.title)
                      .fontSize(15).fontWeight(FontWeight.Medium)
                      .fontColor(achievement.unlocked ? ColorConstants.TEXT_PRIMARY : ColorConstants.TEXT_TERTIARY)

                    Text(achievement.description)
                      .fontSize(13)
                      .fontColor(achievement.unlocked ? ColorConstants.TEXT_SECONDARY : '#CCCCCC')

                    if (achievement.unlocked) {
                      Text('\u2714 \u5DF2\u89E3\u9501')
                        .fontSize(11).fontColor('#4CAF50')
                        .padding({ top: 2 })
                    } else {
                      Text('未解锁')
                        .fontSize(11).fontColor('#CCCCCC')
                        .padding({ top: 2 })
                    }
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                }
                .width('100%')
              }
            }
          }, (achievement: Achievement) => achievement.id)
        }
        .width('100%').padding({ left: 16, right: 16, top: 12 })
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(ColorConstants.BACKGROUND)
  }
}
