import { router } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';
import { WatchAck, WatchCalendarEvent, WatchPetInfo, COLORS } from '../model/WatchDataModels';

interface PetRouteParams {
  petId: string;
}

@Entry
@Component
struct Index {
  @State currentTime: string = '';
  @State pets: WatchPetInfo[] = [];
  @State currentPetIndex: number = 0;
  @State events: WatchCalendarEvent[] = [];
  @State syncText: string = '等待同步';

  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();
  private timer: number = -1;

  aboutToAppear(): void {
    this.updateTime();
    this.loadData();
    this.timer = setInterval(() => {
      this.updateTime();
    }, 1000);

    this.dataManager.onPetInfoChanged = (pet: WatchPetInfo) => {
      this.upsertPet(pet);
      this.syncText = '刚刚同步';
    };
    this.dataManager.onPetDeleted = (petId: string) => {
      this.pets = this.pets.filter((item: WatchPetInfo) => item.id !== petId);
      if (this.currentPetIndex >= this.pets.length) {
        this.currentPetIndex = Math.max(0, this.pets.length - 1);
      }
      this.syncText = '档案已同步';
    };
    this.dataManager.onCalendarEventChanged = (event: WatchCalendarEvent) => {
      this.upsertEvent(event);
      this.syncText = '提醒已同步';
    };
    this.dataManager.onSnapshotChanged = () => {
      this.loadData();
    };
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
    }
    this.dataManager.onPetInfoChanged = null;
    this.dataManager.onPetDeleted = null;
    this.dataManager.onCalendarEventChanged = null;
    this.dataManager.onSnapshotChanged = null;
  }

  async loadData(): Promise<void> {
    this.pets = await this.dataManager.getAllActivePets();
    this.events = await this.dataManager.getCalendarEvents();
    if (this.currentPetIndex >= this.pets.length) {
      this.currentPetIndex = Math.max(0, this.pets.length - 1);
    }
    this.syncText = this.pets.length > 0 ? '同步完成' : '暂无宠物';
  }

  updateTime(): void {
    const now = new Date();
    this.currentTime = now.getHours().toString().padStart(2, '0')
      + ':' + now.getMinutes().toString().padStart(2, '0');
  }

  upsertPet(pet: WatchPetInfo): void {
    if (pet.deleted) {
      this.pets = this.pets.filter((item: WatchPetInfo) => item.id !== pet.id);
      return;
    }
    const next: WatchPetInfo[] = [];
    let found: boolean = false;
    for (let i = 0; i < this.pets.length; i++) {
      if (this.pets[i].id === pet.id) {
        next.push(pet);
        found = true;
      } else {
        next.push(this.pets[i]);
      }
    }
    if (!found) {
      next.unshift(pet);
    }
    this.pets = next;
  }

  upsertEvent(event: WatchCalendarEvent): void {
    const next: WatchCalendarEvent[] = [];
    for (let i = 0; i < this.events.length; i++) {
      if (this.events[i].id !== event.id) {
        next.push(this.events[i]);
      }
    }
    if (!event.deleted) {
      next.push(event);
    }
    next.sort((a: WatchCalendarEvent, b: WatchCalendarEvent) => a.eventDate.localeCompare(b.eventDate));
    this.events = next;
  }

  get currentPet(): WatchPetInfo | null {
    if (this.pets.length === 0 || this.currentPetIndex >= this.pets.length) {
      return null;
    }
    return this.pets[this.currentPetIndex];
  }

  getReminderEvents(): WatchCalendarEvent[] {
    const today = this.formatDate(new Date());
    const result: WatchCalendarEvent[] = [];
    for (let i = 0; i < this.events.length; i++) {
      const event = this.events[i];
      if (event.read) {
        continue;
      }
      if (event.eventDate >= today && result.length < 3) {
        result.push(event);
      }
    }
    return result;
  }

  formatDate(date: Date): string {
    return date.getFullYear().toString() + '-'
      + (date.getMonth() + 1).toString().padStart(2, '0') + '-'
      + date.getDate().toString().padStart(2, '0');
  }

  async markEventRead(event: WatchCalendarEvent): Promise<void> {
    event.read = true;
    const ack: WatchAck = new WatchAck();
    ack.sourceId = event.id;
    ack.sourceType = 'calendar';
    ack.action = 'event_read';
    ack.timestamp = Date.now();
    await this.dataManager.saveWatchAck(ack);
    this.upsertEvent(event);
  }

  navigate(url: string): void {
    try {
      const pet = this.currentPet;
      if (pet) {
        const params: PetRouteParams = {
          petId: pet.id
        };
        const options: router.RouterOptions = {
          url: url,
          params: params
        };
        router.pushUrl(options);
      } else {
        const options: router.RouterOptions = {
          url: url
        };
        router.pushUrl(options);
      }
    } catch (err) {
      console.error('Navigate failed:', JSON.stringify(err));
    }
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text(this.currentTime)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textPrimary)
        Blank()
        Text(this.syncText)
          .fontSize(10)
          .fontColor(COLORS.textHint)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 8 })

      this.PetHeader()
      this.ActionGrid()
      this.EventStrip()

      Blank()
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 8 })
    .backgroundColor(COLORS.background)
  }

  @Builder
  PetHeader() {
    Column({ space: 6 }) {
      if (this.currentPet) {
        Row({ space: 10 }) {
          Text(this.currentPet!.name.substring(0, 1))
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLORS.primary)
            .textAlign(TextAlign.Center)
            .width(54)
            .height(54)
            .borderRadius(14)
            .backgroundColor(COLORS.cardHighlight)

          Column({ space: 2 }) {
            Text(this.currentPet!.name)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(COLORS.textPrimary)
            Text(this.currentPet!.type + ' · ' + this.currentPet!.breed)
              .fontSize(11)
              .fontColor(COLORS.textSecondary)
            Text('体重 ' + this.currentPet!.lastWeight.toString() + 'kg')
              .fontSize(10)
              .fontColor(COLORS.textHint)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')

        if (this.pets.length > 1) {
          Row({ space: 6 }) {
            Text('上一只')
              .fontSize(10)
              .fontColor(COLORS.primary)
              .onClick(() => {
                this.currentPetIndex = (this.currentPetIndex + this.pets.length - 1) % this.pets.length;
              })
            Text((this.currentPetIndex + 1).toString() + '/' + this.pets.length.toString())
              .fontSize(10)
              .fontColor(COLORS.textHint)
            Text('下一只')
              .fontSize(10)
              .fontColor(COLORS.primary)
              .onClick(() => {
                this.currentPetIndex = (this.currentPetIndex + 1) % this.pets.length;
              })
          }
        }
      } else {
        Text('暂无宠物档案')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textPrimary)
        Text('请在手机端添加宠物')
          .fontSize(11)
          .fontColor(COLORS.textHint)
      }
    }
    .width('calc(100% - 24vp)')
    .padding(14)
    .backgroundColor(COLORS.card)
    .borderRadius(16)
  }

  @Builder
  ActionGrid() {
    Row({ space: 8 }) {
      this.ActionButton('档案', '◇', 'pages/PetInfoPage')
      this.ActionButton('定位', '⌖', 'pages/MapLocationPage')
      this.ActionButton('喂食', '○', 'pages/FeedReminderPage')
    }
    .width('calc(100% - 24vp)')
  }

  @Builder
  ActionButton(label: string, icon: string, url: string) {
    Column({ space: 4 }) {
      Text(icon)
        .fontSize(18)
        .fontColor(COLORS.primary)
      Text(label)
        .fontSize(11)
        .fontColor(COLORS.textPrimary)
    }
    .layoutWeight(1)
    .height(66)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(COLORS.card)
    .borderRadius(14)
    .onClick(() => {
      this.navigate(url);
    })
  }

  @Builder
  EventStrip() {
    Column({ space: 8 }) {
      Row() {
        Text('日期提醒')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLORS.textPrimary)
        Blank()
        Text(this.getReminderEvents().length.toString())
          .fontSize(11)
          .fontColor(COLORS.primary)
      }
      .width('100%')

      if (this.getReminderEvents().length === 0) {
        Text('暂无待提醒事件')
          .fontSize(11)
          .fontColor(COLORS.textHint)
          .width('100%')
      } else {
        ForEach(this.getReminderEvents(), (event: WatchCalendarEvent) => {
          Row({ space: 8 }) {
            Text('□')
              .fontSize(12)
              .fontColor(COLORS.primary)
            Column({ space: 2 }) {
              Text(event.title)
                .fontSize(12)
                .fontColor(COLORS.textPrimary)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(event.eventDate)
                .fontSize(10)
                .fontColor(COLORS.textHint)
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)
            Text('已读')
              .fontSize(10)
              .fontColor(COLORS.primary)
              .onClick(() => {
                this.markEventRead(event);
              })
          }
          .width('100%')
        }, (event: WatchCalendarEvent) => event.id)
      }
    }
    .width('calc(100% - 24vp)')
    .padding(12)
    .backgroundColor(COLORS.card)
    .borderRadius(14)
  }
}
