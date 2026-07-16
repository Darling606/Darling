import router from '@ohos.router';
import { PetCompanion, CompanionPersonality, generateCompanionId, CompanionStats } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState } from '../components/BounceComponents';
import { CompanionAvatar, MoodLabel, LevelRing } from '../components/CompanionComponents';
import { LineIcon, LineIconName } from '../components/LineIcons';
import { CareService, CareMessage } from '../service/CareService';
import { AppEventBus } from '../common/AppEventBus';
import { CheckInService } from '../service/CheckInService';
import { AchievementService, Achievement } from '../service/AchievementService';

@Component
export struct CompanionHomePage {
  @State companion: PetCompanion | null = null;
  @State isLoading: boolean = true;
  @State showCreateSheet: boolean = false;
  @State stats: CompanionStats = new CompanionStats();

  @State newName: string = '';
  @State newSpecies: string = 'cat';
  @State newPersonality: string = '温柔';
  @State careMessage: CareMessage | null = null;
  @State achievementCount: number = 0;
  @State checkedInToday: boolean = false;

  private storage: CompanionStorage = CompanionStorage.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.storage.init(getContext(this));
    await this.loadCompanion();
    AppEventBus.on('COMPANION_STATUS_CHANGED', (data: Object) => {
      this.companion = data as PetCompanion;
    });
    AppEventBus.on('ACHIEVEMENT_UNLOCKED', (data: Object) => {
      const achievement = data as Achievement;
      ToastUtils.show('解锁新成就：' + achievement.title);
      this.achievementCount = AchievementService.getUnlockedCount(this.companion!);
    });
  }

  aboutToDisappear(): void {
    AppEventBus.off('COMPANION_STATUS_CHANGED');
    AppEventBus.off('ACHIEVEMENT_UNLOCKED');
  }

  async loadCompanion(): Promise<void> {
    const account = this.getCurrentAccount();
    const comp = await this.storage.getCompanion(account);
    this.companion = comp;
    if (comp !== null) {
      this.stats = await this.storage.getStats(comp.id);
      if (this.stats.totalDays === 0) { this.stats.totalDays = 1; }
      this.careMessage = CareService.checkCare(comp);
      this.achievementCount = AchievementService.getUnlockedCount(comp);
      this.checkedInToday = !CheckInService.checkToday(comp);
    }
    this.isLoading = false;
  }

  getCurrentAccount(): string {
    return 'default_user';
  }

  async createCompanion(): Promise<void> {
    if (this.newName.length === 0) {
      ToastUtils.show('请输入伙伴名称');
      return;
    }
    const comp = new PetCompanion();
    comp.id = generateCompanionId();
    comp.account = this.getCurrentAccount();
    comp.name = this.newName;
    comp.species = this.newSpecies;
    comp.personality = this.newPersonality as CompanionPersonality;
    comp.level = 1;
    comp.exp = 0;
    comp.intimacy = 100;
    comp.mood = 'happy';
    comp.created = Date.now();
    comp.updated = Date.now();

    const saved = await this.storage.saveCompanion(comp);
    if (saved) {
      this.companion = comp;
      this.stats = await this.storage.getStats(comp.id);
      if (this.stats.totalDays === 0) { this.stats.totalDays = 1; }
      this.showCreateSheet = false;
      ToastUtils.showSuccess('伙伴创建成功！');
    } else {
      ToastUtils.showError('创建失败，请重试');
    }
  }

  handleNavigate(path: string): void {
    try {
      router.pushUrl({ url: path });
    } catch (err) {
      console.error('Navigate failed:', JSON.stringify(err));
    }
  }

  async performCheckIn(): Promise<void> {
    if (this.companion === null) { return; }
    const exp: number = await CheckInService.performCheckIn(this.companion);
    if (exp > 0) {
      this.checkedInToday = true;
      ToastUtils.show('\u7B7E\u5230\u6210\u529F\uFF01+ ' + exp.toString() + ' EXP');
      const updated: PetCompanion | null = await this.storage.getCompanionById(this.companion!.id);
      if (updated !== null) {
        this.companion = updated;
      }
    } else {
      ToastUtils.show('\u4ECA\u5929\u5DF2\u7ECF\u7B7E\u5230\u8FC7\u4E86');
    }
  }

  @Builder
  CreateSheet() {
    Column() {
      Column({ space: 14 }) {
        Text('创建你的专属伙伴')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)

        TextInput({ placeholder: '给伙伴起个名字', text: this.newName })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .padding({ left: 16 })
          .onChange((value: string) => { this.newName = value; })

        Text('选择物种')
          .fontSize(14).fontColor(ColorConstants.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)

        Row({ space: 10 }) {
          BounceButton({
            text: '猫咪',
            iconName: 'cat',
            bgColor: this.newSpecies === 'cat' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newSpecies === 'cat' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newSpecies = 'cat'; }
          })
          BounceButton({
            text: '狗狗',
            iconName: 'dog',
            bgColor: this.newSpecies === 'dog' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newSpecies === 'dog' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newSpecies = 'dog'; }
          })
          BounceButton({
            text: '自定义',
            iconName: 'pet',
            bgColor: this.newSpecies === 'custom' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newSpecies === 'custom' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newSpecies = 'custom'; }
          })
        }
        .width('100%')

        Text('选择性格')
          .fontSize(14).fontColor(ColorConstants.TEXT_SECONDARY)
          .alignSelf(ItemAlign.Start)

        Row({ space: 8 }) {
          BounceButton({
            text: '温柔',
            bgColor: this.newPersonality === '温柔' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPersonality === '温柔' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newPersonality = '温柔'; }
          })
          BounceButton({
            text: '活泼',
            bgColor: this.newPersonality === '活泼' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPersonality === '活泼' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newPersonality = '活泼'; }
          })
          BounceButton({
            text: '傲娇',
            bgColor: this.newPersonality === '傲娇' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPersonality === '傲娇' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 42, customRadius: 12, fontSize: 13,
            onAction: () => { this.newPersonality = '傲娇'; }
          })
        }
        .width('100%')

        Row({ space: 10 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12, fontSize: 14,
            onAction: () => { this.showCreateSheet = false; }
          })
          BounceButton({
            text: '创建伙伴', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12, fontSize: 14,
            onAction: () => { this.createCompanion(); }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%').height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  StatsRow(iconName: LineIconName, label: string, value: string) {
    Column({ space: 4 }) {
      LineIcon({ name: iconName, iconSize: 22, color: ColorConstants.PRIMARY })
      Text(value).fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
      Text(label).fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress().width(32).height(32).color(ColorConstants.PRIMARY)
            Text('加载中...').fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.companion === null) {
          BounceEmptyState({
            iconName: 'sparkles',
            title: '还没有 AI 伙伴',
            subtitle: '创建一个专属的虚拟宠物伙伴，陪你聊天，记录回忆',
            buttonText: '创建伙伴',
            onAction: () => { this.showCreateSheet = true; }
          })
          .layoutWeight(1)
        } else {
          Scroll() {
            Column({ space: 16 }) {

              if (this.careMessage !== null) {
                BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 14, customRadius: 16 }) {
                  Row({ space: 8 }) {
                    LineIcon({ name: 'chat', iconSize: 18, color: ColorConstants.PRIMARY })
                    Text(this.careMessage!.message)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(ColorConstants.PRIMARY)
                      .layoutWeight(1)
                  }
                  .width('100%')
                }
              }

              CompanionAvatar({
                species: this.companion!.species,
                mood: this.companion!.mood,
                avatarSize: 140
              })

              Column({ space: 4 }) {
                Text(this.companion!.name)
                  .fontSize(22).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
                MoodLabel({ mood: this.companion!.mood })
              }
              .alignItems(HorizontalAlign.Center)

              Row({ space: 12 }) {
                BounceCard({ customWidth: '48%', customPadding: 16, customRadius: 16 }) {
                  Column({ space: 4 }) {
                    LevelRing({
                      level: this.companion!.level,
                      exp: this.companion!.exp,
                      maxExp: this.companion!.getMaxExp(),
                      ringSize: 72
                    })
                  }
                  .alignItems(HorizontalAlign.Center)
                }

                BounceCard({ customWidth: '48%', customPadding: 16, customRadius: 16 }) {
                  Column({ space: 8 }) {
                                        Text('亲密度')
                    Text(this.companion!.intimacy.toString())
                      .fontSize(28).fontWeight(FontWeight.Bold)
                      .fontColor(ColorConstants.PRIMARY)
                    Row() {
                      Column()
                        .width((this.companion!.intimacy / 10).toString() + '%')
                        .height(6)
                        .backgroundColor(ColorConstants.PRIMARY)
                        .borderRadius(3)
                      Blank()
                    }
                    .width('100%').height(6)
                    .backgroundColor('#F0F0F0').borderRadius(3)
                  }
                  .alignItems(HorizontalAlign.Center)
                }
              }
              .width('100%').padding({ left: 16, right: 16 })

              Row({ space: 12 }) {
                BounceCard({ customWidth: '48%', customPadding: 14, customRadius: 16 }) {
                  Column({ space: 6 }) {
                    Text('\u7ECF\u9A8C\u503C').fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                    Text(this.companion!.exp.toString() + '/' + this.companion!.getMaxExp().toString())
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
                    Row() {
                      Column()
                        .width((this.companion!.exp / this.companion!.getMaxExp() * 100).toString() + '%')
                        .height(5).backgroundColor(ColorConstants.PRIMARY).borderRadius(3)
                      Blank()
                    }
                    .width('100%').height(5).backgroundColor('#F0F0F0').borderRadius(3)
                  }
                  .alignItems(HorizontalAlign.Start)
                }

                BounceCard({ customWidth: '48%', customPadding: 14, customRadius: 16 }) {
                  Column({ space: 6 }) {
                    Text('\u5FEB\u4E50\u503C').fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                    Text(this.companion!.happiness.toString() + '/100')
                      .fontSize(16).fontWeight(FontWeight.Bold).fontColor(ColorConstants.PRIMARY)
                    Row() {
                      Column()
                        .width((this.companion!.happiness).toString() + '%')
                        .height(5).backgroundColor(ColorConstants.PRIMARY).borderRadius(3)
                      Blank()
                    }
                    .width('100%').height(5).backgroundColor('#F0F0F0').borderRadius(3)
                  }
                  .alignItems(HorizontalAlign.Start)
                }
              }
              .width('100%').padding({ left: 16, right: 16 })

              BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 14, customRadius: 16 }) {
                Row({ space: 10 }) {
                  LineIcon({ name: 'trophy', iconSize: 22, color: ColorConstants.PRIMARY })
                  Column({ space: 2 }) {
                    Text('\u5DF2\u89E3\u9501 ' + this.achievementCount.toString() + ' \u9879\u6210\u5C31')
                      .fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
                    Text('\u63D0\u5347\u4EB2\u5BC6\u5EA6\u3001\u7B49\u7EA7\u6765\u89E3\u9501\u66F4\u591A')
                      .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  Text('\u203A')
                    .fontSize(20).fontColor(ColorConstants.TEXT_HINT)
                }
                .width('100%')
                .onClick(() => { this.handleNavigate('pages/AchievementPage'); })
              }

              BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 14, customRadius: 16 }) {
                Row({ space: 10 }) {
                  LineIcon({ name: 'calendar', iconSize: 20, color: ColorConstants.PRIMARY })
                  Column({ space: 2 }) {
                    Text(CheckInService.getStreakText(this.companion!.checkInDays))
                      .fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
                  }
                  .layoutWeight(1).alignItems(HorizontalAlign.Start)
                  BounceButton({
                    text: this.checkedInToday ? '\u5DF2\u7B7E\u5230' : '\u7ACB\u5373\u7B7E\u5230',
                    bgColor: this.checkedInToday ? '#E0E0E0' : ColorConstants.BUTTON_PRIMARY,
                    textColor: this.checkedInToday ? ColorConstants.TEXT_SECONDARY : ColorConstants.BUTTON_PRIMARY_TEXT,
                    customWidth: this.checkedInToday ? '82vp' : '108vp', customHeight: 36, customRadius: 12, fontSize: 12,
                    fontWeight: FontWeight.Medium,
                    onAction: () => { this.performCheckIn(); }
                  })
                }
                .width('100%')
              }

              Row({ space: 12 }) {
                BounceButton({
                  text: '聊聊',
                  iconName: 'chat',
                  bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
                  customWidth: '48%', customHeight: 48, customRadius: 12, fontSize: 15,
                  onAction: () => { this.handleNavigate('pages/ChatPage'); }
                })
                BounceButton({
                  text: '回忆',
                  iconName: 'book',
                  bgColor: '#F0F0F0',
                  textColor: ColorConstants.TEXT_PRIMARY,
                  customWidth: '48%', customHeight: 48, customRadius: 12, fontSize: 15,
                  onAction: () => {
                    try {
                      router.pushUrl({ url: 'pages/MemoryPage' });
                    } catch (err) {
                      ToastUtils.show('页面跳转失败');
                    }
                  }
                })
              }
              .width('100%').padding({ left: 16, right: 16 })

              BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 16, customRadius: 16 }) {
                Row() {
                  this.StatsRow('chat', '\u4ECA\u65E5\u4E92\u52A8', this.stats.todayChats.toString())
                  this.StatsRow('calendar', '\u966A\u4F34\u5929\u6570', this.stats.totalDays.toString())
                  this.StatsRow('brain', '\u8BB0\u5FC6', this.stats.memoriesCount.toString())
                  this.StatsRow('heart', '\u4EB2\u5BC6', this.companion!.intimacy.toString())
                }
                .width('100%')
              }



            }
            .padding({ top: 16, bottom: 24 })
            .alignItems(HorizontalAlign.Center)
          }
          .width('100%').height('100%')
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%')

      if (this.showCreateSheet) { this.CreateSheet() }
    }
    .width('100%').height('100%')
  }
}
