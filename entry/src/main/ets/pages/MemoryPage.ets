import router from '@ohos.router';
import { CompanionMemory, MemoryType } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { MemoryService } from '../service/MemoryService';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard } from '../components/BounceComponents';

@Entry
@Component
export struct MemoryPage {
  @State memories: CompanionMemory[] = [];
  @State isLoading: boolean = true;
  @State showEditSheet: boolean = false;
  @State editingMemory: CompanionMemory | null = null;
  @State editContent: string = '';

  private storage: CompanionStorage = CompanionStorage.getInstance();
  private memoryService: MemoryService = MemoryService.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.storage.init(getContext(this));
    await this.loadMemories();
  }

  async loadMemories(): Promise<void> {
    const account = 'default_user';
    const companion = await this.storage.getCompanion(account);
    if (companion !== null) {
      this.memories = await this.memoryService.getAllMemories(companion.id);
    }
    this.isLoading = false;
  }

  async deleteMemory(memoryId: string): Promise<void> {
    await this.memoryService.deleteMemory(memoryId);
    this.memories = this.memories.filter(m => m.id !== memoryId);
    ToastUtils.show('已忘记');
  }

  async saveEdit(): Promise<void> {
    if (this.editingMemory === null) { return; }
    if (this.editContent.trim().length === 0) { return; }
    this.editingMemory.content = this.editContent.trim();
    await this.memoryService.updateMemory(this.editingMemory);
    this.memories = [...this.memories];
    this.showEditSheet = false;
    ToastUtils.show('记忆已更新');
  }

  getCategoryLabel(type: MemoryType): string {
    if (type === 'important') { return '重要'; }
    if (type === 'event') { return '事件'; }
    if (type === 'preference') { return '偏好'; }
    return '日常';
  }

  getCategoryColor(type: MemoryType): string {
    if (type === 'important') { return '#FF6B6B'; }
    if (type === 'event') { return '#4CAF50'; }
    if (type === 'preference') { return '#64B5F6'; }
    return '#BBBBBB';
  }

  getCategoryBgColor(type: MemoryType): string {
    if (type === 'important') { return '#FFEBEE'; }
    if (type === 'event') { return '#E8F5E9'; }
    if (type === 'preference') { return '#E3F2FD'; }
    return '#F5F5F5';
  }

  formatDate(timestamp: number): string {
    if (timestamp === 0) { return ''; }
    const d = new Date(timestamp);
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const h = d.getHours().toString().padStart(2, '0');
    const min = d.getMinutes().toString().padStart(2, '0');
    return m + '-' + day + ' ' + h + ':' + min;
  }

  @Builder
  EditSheet() {
    Column() {
      Column({ space: 14 }) {
        Text('编辑记忆')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)

        TextInput({ placeholder: '修改记忆内容', text: this.editContent })
          .width('100%').height(60)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .padding({ left: 16, top: 12 })
          .onChange((value: string) => { this.editContent = value; })

        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.showEditSheet = false; }
          })
          BounceButton({
            text: '保存', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.saveEdit(); }
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
  MemoryEmptyState() {
    Column({ space: 18 }) {
      Image($r('app.media.memory_empty_dog'))
        .width('62%')
        .constraintSize({ maxWidth: 280, minWidth: 220 })
        .objectFit(ImageFit.Contain)

      Column({ space: 8 }) {
        Text('还没有记住什么...')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#9AA09B')
          .textAlign(TextAlign.Center)

        Text('多和伙伴聊天，它会记住关于你的事情')
          .fontSize(13)
          .fontColor('#C1C6C2')
          .textAlign(TextAlign.Center)
      }
      .padding({ left: 32, right: 32 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24, bottom: 84 })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('\u2190')
            .fontSize(20).fontColor(ColorConstants.PRIMARY)
            .padding({ left: 4, right: 12, top: 8, bottom: 8 })
            .onClick(() => { try { router.back(); } catch (err) { } })

          Text('\u5976\u7CD6\u8BB0\u5F97')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
            .layoutWeight(1)

          Text(this.memories.length.toString())
            .fontSize(14).fontColor(ColorConstants.TEXT_TERTIARY)
            .padding({ right: 4 })
        }
        .width('100%').height(52).padding({ left: 16, right: 16 })
        .backgroundColor(ColorConstants.CARD_BACKGROUND)
        .shadow({ radius: 12, color: ColorConstants.SHADOW_COLOR, offsetX: 0, offsetY: 4 })

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress().width(32).height(32).color(ColorConstants.PRIMARY)
            Text('加载中...').fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (this.memories.length === 0) {
          this.MemoryEmptyState()
        } else {
          List({ space: 10 }) {
            ForEach(this.memories, (memory: CompanionMemory) => {
              ListItem() {
                BounceCard({ customWidth: '100%', customPadding: 16, customRadius: 16 }) {
                  Column({ space: 8 }) {
                    Row() {
                      Text(memory.content)
                        .fontSize(15).fontWeight(FontWeight.Medium)
                        .fontColor(ColorConstants.TEXT_PRIMARY)
                        .layoutWeight(1)
                    }
                    .width('100%')

                    Row() {
                      Text(this.getCategoryLabel(memory.type))
                        .fontSize(11)
                        .fontColor(this.getCategoryColor(memory.type))
                        .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                        .backgroundColor(this.getCategoryBgColor(memory.type))
                        .borderRadius(6)

                      Blank()

                      Text('\u91CD\u8981\u5EA6 ' + memory.importance.toString())
                        .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)

                      Text('  ' + this.formatDate(memory.timestamp))
                        .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                    }
                    .width('100%')

                    Row({ space: 12 }) {
                      Text('\u7F16\u8F91')
                        .fontSize(13).fontColor(ColorConstants.PRIMARY)
                        .onClick(() => {
                          this.editingMemory = memory;
                          this.editContent = memory.content;
                          this.showEditSheet = true;
                        })
                      Text('\u5220\u9664')
                        .fontSize(13).fontColor(ColorConstants.ERROR)
                        .onClick(() => { this.deleteMemory(memory.id); })
                    }
                    .width('100%').margin({ top: 4 })
                  }
                  .width('100%')
                }
              }
            }, (memory: CompanionMemory) => 'mem_' + memory.id)
          }
          .width('100%').padding({ left: 16, right: 16, top: 12 })
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%')
      .backgroundColor(ColorConstants.BACKGROUND)

      if (this.showEditSheet) { this.EditSheet() }
    }
    .width('100%').height('100%')
  }
}
