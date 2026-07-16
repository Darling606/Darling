import { CalendarEvent, EventType, generateEventId, getEventTypeLabel, getEventTypeColor, getEventTypeBgColor } from '../model/CalendarModels';
import { CalendarStorage } from '../service/CalendarStorage';
import { AuthManager } from '../model/AuthManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState } from '../components/BounceComponents';
import { LineIcon } from '../components/LineIcons';
import { CloudSyncService } from '../service/CloudSyncService';

const CLOUD_SYNC_INTERVAL_MS: number = 2000;

interface DateCell {
  day: number;
  dateStr: string;
  isEmpty: boolean;
  hasEvent: boolean;
  dotColor: string;
}

@Component
export struct CalendarContent {
  @State currentYear: number = 2026;
  @State currentMonth: number = 6;
  @State selectedDate: string = '';
  @State events: CalendarEvent[] = [];
  @State selectedEvents: CalendarEvent[] = [];
  @State showEventDialog: boolean = false;
  @State editingEvent: CalendarEvent | null = null;
  @State dialogTitle: string = '';
  @State dialogDescription: string = '';
  @State dialogType: EventType = 'work';
  @State dialogRemindDays: boolean[] = [false, false, false];
  @State todayDate: string = '';
  @State pressedDate: string = '';
  @State calendarCells: DateCell[] = [];
  onEventSaved?: () => void;

  private storage: CalendarStorage = new CalendarStorage();
  private authManager: AuthManager = AuthManager.getInstance();
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private readonly eventTypes: EventType[] = ['birthday', 'study', 'work', 'anniversary', 'custom'];
  private cloudSyncTimer: number = -1;
  private isCloudSyncing: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storage.init(getContext(this));
    const today: Date = new Date();
    this.currentYear = today.getFullYear();
    this.currentMonth = today.getMonth() + 1;
    this.selectedDate = this.formatDate(today);
    this.todayDate = this.formatDate(today);
    await this.loadEvents();
    await this.refreshCloudData();
    await this.selectDate(this.selectedDate);
    this.updateCalendarCells();
    this.startCloudSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopCloudSyncTimer();
  }

  formatDate(d: Date): string {
    const y: string = d.getFullYear().toString();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  private formatPad(y: number, m: number, d: number): string {
    return y.toString() + '-' + m.toString().padStart(2, '0') + '-' + d.toString().padStart(2, '0');
  }

  async loadEvents(): Promise<void> {
    this.events = await this.storage.getEvents();
    this.updateCalendarCells();
  }

  startCloudSyncTimer(): void {
    this.stopCloudSyncTimer();
    this.cloudSyncTimer = setInterval(() => {
      this.refreshCloudData();
    }, CLOUD_SYNC_INTERVAL_MS);
  }

  stopCloudSyncTimer(): void {
    if (this.cloudSyncTimer !== -1) {
      clearInterval(this.cloudSyncTimer);
      this.cloudSyncTimer = -1;
    }
  }

  async refreshCloudData(): Promise<void> {
    if (this.isCloudSyncing) {
      return;
    }
    this.isCloudSyncing = true;
    try {
      const account: string = await this.authManager.getAccount();
      if (account.length === 0) {
        return;
      }
      const localEvents: CalendarEvent[] =
        this.cloudSyncService.normalizeLocalItems(await this.storage.getEvents());
      const mergedEvents: CalendarEvent[] =
        await this.cloudSyncService.syncCollection(account, 'calendarEvents', localEvents);
      await this.storage.saveEvents(mergedEvents);
      this.events = mergedEvents;
      await this.selectDate(this.selectedDate);
      this.updateCalendarCells();
    } finally {
      this.isCloudSyncing = false;
    }
  }

  async pushEventsToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushCollection(account, 'calendarEvents', this.events);
  }

  async deleteEventFromCloud(id: string): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.deleteCollectionItem(account, 'calendarEvents', id, Date.now());
  }

  async selectDate(date: string): Promise<void> {
    this.selectedDate = date;
    this.selectedEvents = await this.storage.getEventsByDate(date);
  }

  hasEvents(date: string): boolean {
    for (let i = 0; i < this.events.length; i++) {
      if (this.events[i].eventDate === date) { return true; }
    }
    return false;
  }

  getEventDotColor(date: string): string {
    let bestColor: string = '#DDDDDD';
    for (let i = 0; i < this.events.length; i++) {
      if (this.events[i].eventDate === date) {
        bestColor = getEventTypeColor(this.events[i].type);
      }
    }
    return bestColor;
  }

  getDaysInMonth(year: number, month: number): number {
    return new Date(year, month, 0).getDate();
  }

  getFirstDayOfWeek(year: number, month: number): number {
    return new Date(year, month - 1, 1).getDay();
  }

  private getCalendarCells(): DateCell[] {
    const totalDays: number = this.getDaysInMonth(this.currentYear, this.currentMonth);
    const firstDay: number = this.getFirstDayOfWeek(this.currentYear, this.currentMonth);
    const cells: DateCell[] = [];

    for (let i: number = 0; i < 42; i++) {
      if (i < firstDay || i >= firstDay + totalDays) {
        cells.push({ day: 0, dateStr: '', isEmpty: true, hasEvent: false, dotColor: '' });
      } else {
        const day: number = i - firstDay + 1;
        const dateStr: string = this.formatPad(this.currentYear, this.currentMonth, day);
        const hasEvt: boolean = this.hasEvents(dateStr);
        const dotClr: string = this.getEventDotColor(dateStr);
        cells.push({ day, dateStr, isEmpty: false, hasEvent: hasEvt, dotColor: dotClr });
      }
    }
    return cells;
  }

  private updateCalendarCells(): void {
    this.calendarCells = this.getCalendarCells();
  }

  prevMonth(): void {
    if (this.currentMonth === 1) { this.currentYear--; this.currentMonth = 12; }
    else { this.currentMonth--; }
    this.selectedEvents = [];
    this.selectedDate = this.formatPad(this.currentYear, this.currentMonth, 1);
    this.selectDate(this.selectedDate);
    this.updateCalendarCells();
  }

  nextMonth(): void {
    if (this.currentMonth === 12) { this.currentYear++; this.currentMonth = 1; }
    else { this.currentMonth++; }
    this.selectedEvents = [];
    this.selectedDate = this.formatPad(this.currentYear, this.currentMonth, 1);
    this.selectDate(this.selectedDate);
    this.updateCalendarCells();
  }

  async goToday(): Promise<void> {
    const today: Date = new Date();
    this.currentYear = today.getFullYear();
    this.currentMonth = today.getMonth() + 1;
    this.selectedDate = this.formatDate(today);
    await this.selectDate(this.selectedDate);
    this.updateCalendarCells();
  }

  openAddDialog(): void {
    this.editingEvent = null;
    this.dialogTitle = '';
    this.dialogDescription = '';
    this.dialogType = 'work';
    this.dialogRemindDays = [false, false, false];
    this.showEventDialog = true;
  }

  openEditDialog(event: CalendarEvent): void {
    this.editingEvent = event;
    this.dialogTitle = event.title;
    this.dialogDescription = event.description;
    this.dialogType = event.type;
    this.dialogRemindDays = [false, false, false];
    for (let i = 0; i < event.remindDays.length; i++) {
      const d: number = event.remindDays[i];
      if (d === 1) { this.dialogRemindDays[0] = true; }
      if (d === 3) { this.dialogRemindDays[1] = true; }
      if (d === 7) { this.dialogRemindDays[2] = true; }
    }
    this.showEventDialog = true;
  }

  async saveEvent(): Promise<void> {
    if (this.dialogTitle.length === 0) {
      ToastUtils.show('请输入事件标题');
      return;
    }
    const remindDays: number[] = [];
    if (this.dialogRemindDays[0]) { remindDays.push(1); }
    if (this.dialogRemindDays[1]) { remindDays.push(3); }
    if (this.dialogRemindDays[2]) { remindDays.push(7); }

    if (this.editingEvent !== null) {
      this.editingEvent.title = this.dialogTitle;
      this.editingEvent.description = this.dialogDescription;
      this.editingEvent.type = this.dialogType;
      this.editingEvent.remindDays = remindDays;
      this.editingEvent.updatedAt = Date.now();
      this.editingEvent.deleted = false;
      await this.storage.updateEvent(this.editingEvent);
    } else {
      const newEvent: CalendarEvent = {
        id: generateEventId(),
        title: this.dialogTitle,
        description: this.dialogDescription,
        eventDate: this.selectedDate,
        type: this.dialogType,
        remindDays: remindDays,
        createdAt: Date.now(),
        updatedAt: Date.now(),
        deleted: false
      };
      await this.storage.addEvent(newEvent);
    }

    this.showEventDialog = false;
    this.stopCloudSyncTimer();
    await this.loadEvents();
    await this.pushEventsToCloud();
    await this.selectDate(this.selectedDate);
    this.startCloudSyncTimer();
    this.onEventSaved?.();
    ToastUtils.showSuccess('保存成功');
  }

  async deleteEvent(id: string): Promise<void> {
    this.stopCloudSyncTimer();
    await this.storage.deleteEvent(id);
    await this.deleteEventFromCloud(id);
    await this.loadEvents();
    await this.selectDate(this.selectedDate);
    this.startCloudSyncTimer();
    this.onEventSaved?.();
    ToastUtils.show('已删除');
  }

  isToday(date: string): boolean {
    return date === this.formatDate(new Date());
  }

  @Builder
  DateGrid() {
    Column() {
      Row() {
        Text('← ' + this.currentYear.toString())
          .fontSize(16).fontColor(ColorConstants.PRIMARY)
          .padding({ left: 4, right: 8, top: 6, bottom: 6 })
          .onClick(() => { this.prevMonth(); })
        Text(this.currentMonth.toString() + '月')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY).layoutWeight(1).textAlign(TextAlign.Center)
        Text(this.currentYear.toString() + ' →')
          .fontSize(16).fontColor(ColorConstants.PRIMARY)
          .padding({ left: 8, right: 4, top: 6, bottom: 6 })
          .onClick(() => { this.nextMonth(); })
      }
      .width('100%').padding({ left: 16, right: 16, top: 8 })

      Row() {
        ForEach(['日', '一', '二', '三', '四', '五', '六'], (label: string) => {
          Text(label).fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
            .width('13%').textAlign(TextAlign.Center).padding({ top: 4, bottom: 4 })
        }, (label: string) => label)
      }
      .width('100%').padding({ left: 16, right: 16 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.calendarCells, (cell: DateCell, index: number) => {
          if (cell.isEmpty) {
            Column().width('13.5%').height(42)
          } else {
            Column() {
              Text(cell.day.toString())
                .fontSize(15)
                .fontWeight(cell.dateStr === this.todayDate ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(cell.dateStr === this.todayDate ? ColorConstants.PRIMARY : ColorConstants.TEXT_PRIMARY)
                .width(32).height(22).borderRadius(16)
                .textAlign(TextAlign.Center)
                .backgroundColor(cell.dateStr === this.todayDate ? '#FFDFEB' : 'transparent')

              Text('●')
                .fontSize(8)
                .fontColor(cell.hasEvent ? cell.dotColor : 'transparent')
                .height(10)
                .width(32)
                .textAlign(TextAlign.Center)
            }
            .width('13.5%').height(42)
            .justifyContent(FlexAlign.Start).alignItems(HorizontalAlign.Center)
            .padding({ top: 5 })
            .scale({ x: this.pressedDate === cell.dateStr ? 0.92 : 1, y: this.pressedDate === cell.dateStr ? 0.92 : 1 })
            .animation({ duration: 120, curve: Curve.EaseOut })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.pressedDate = cell.dateStr;
              } else if (event.type === TouchType.Up) {
                this.pressedDate = '';
                this.selectedDate = cell.dateStr;
                this.storage.getEventsByDate(cell.dateStr).then((events: CalendarEvent[]) => {
                  this.selectedEvents = events;
                });
              } else {
                this.pressedDate = '';
              }
            })
          }
        }, (cell: DateCell, index: number) => (cell.isEmpty ? 'empty_' + index.toString() : cell.dateStr + (cell.hasEvent ? '_evt' : '')))
      }
      .width('100%').padding({ left: 16, right: 16, top: 4 })
    }
  }

  @Builder
  EventList() {
    Column({ space: 8 }) {
      if (this.selectedDate.length > 0) {
        Row() {
          Text(this.selectedDate)
            .fontSize(14).fontWeight(FontWeight.Medium)
            .fontColor(ColorConstants.TEXT_SECONDARY)
          Blank()
        }
        .width('100%').padding({ left: 4, right: 4 })
      }

      if (this.selectedEvents.length === 0) {
        BounceEmptyState({
          iconName: 'calendar',
          title: '当天无事件',
          subtitle: '点击下方按钮添加',
        })
      } else {
        ForEach(this.selectedEvents, (event: CalendarEvent) => {
          BounceCard({ customWidth: '100%', customPadding: 12, customRadius: 12 }) {
            Row({ space: 10 }) {
              Column() {
                Text('●').fontSize(20).fontColor(getEventTypeColor(event.type))
              }.width(14)

              Column({ space: 3 }) {
                Text(event.title)
                  .fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor(ColorConstants.TEXT_PRIMARY)

                if (event.description.length > 0) {
                  Text(event.description)
                    .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY).maxLines(1)
                }

                Text(getEventTypeLabel(event.type))
                  .fontSize(11).fontColor(getEventTypeColor(event.type))
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(getEventTypeBgColor(event.type)).borderRadius(4)
              }
              .layoutWeight(1).alignItems(HorizontalAlign.Start)

              LineIcon({ name: 'edit', iconSize: 17, color: ColorConstants.TEXT_TERTIARY })
                .onClick(() => { this.openEditDialog(event); })
              LineIcon({ name: 'trash', iconSize: 17, color: ColorConstants.ERROR })
                .onClick(() => { this.deleteEvent(event.id); })
            }
            .width('100%')
          }
        }, (event: CalendarEvent) => event.id)
      }
    }
    .width('100%').padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  EventDialog() {
    Column() {
      Column({ space: 14 }) {
        Text(this.editingEvent !== null ? '编辑事件' : '添加事件')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)

        TextInput({ placeholder: '事件标题', text: this.dialogTitle })
          .width('100%').height(44)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 12 })
          .onChange((value: string) => { this.dialogTitle = value; })

        TextInput({ placeholder: '描述 (选填)', text: this.dialogDescription })
          .width('100%').height(44)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 12 })
          .onChange((value: string) => { this.dialogDescription = value; })

        Text('事件类型').fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY).alignSelf(ItemAlign.Start)

        Row({ space: 6 }) {
          ForEach(this.eventTypes, (type: EventType) => {
            Text(getEventTypeLabel(type))
              .fontSize(12)
              .fontColor(this.dialogType === type ? '#FFFFFF' : getEventTypeColor(type))
              .fontWeight(this.dialogType === type ? FontWeight.Medium : FontWeight.Normal)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor(this.dialogType === type ? getEventTypeColor(type) : getEventTypeBgColor(type))
              .borderRadius(14)
              .onClick(() => { this.dialogType = type; })
          }, (type: EventType) => type)
        }
        .width('100%')

        Text('提前提醒').fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY).alignSelf(ItemAlign.Start)

        Row({ space: 8 }) {
          Row({ space: 4 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.dialogRemindDays[0] })
              .selectedColor(ColorConstants.BUTTON_PRIMARY).width(18).height(18)
              .onChange((value: boolean) => { this.dialogRemindDays[0] = value; })
            Text('1天前').fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY)
          }
          Row({ space: 4 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.dialogRemindDays[1] })
              .selectedColor(ColorConstants.BUTTON_PRIMARY).width(18).height(18)
              .onChange((value: boolean) => { this.dialogRemindDays[1] = value; })
            Text('3天前').fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY)
          }
          Row({ space: 4 }) {
            Toggle({ type: ToggleType.Checkbox, isOn: this.dialogRemindDays[2] })
              .selectedColor(ColorConstants.BUTTON_PRIMARY).width(18).height(18)
              .onChange((value: boolean) => { this.dialogRemindDays[2] = value; })
            Text('7天前').fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY)
          }
        }
        .width('100%')

        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.showEventDialog = false; }
          })
          BounceButton({
            text: '保存', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.saveEvent(); }
          })
        }
        .width('100%')
      }
      .width('100%').padding(24)
      .backgroundColor(ColorConstants.CARD_BACKGROUND).borderRadius(20)
      .shadow({ radius: 20, color: '#33000000', offsetX: 0, offsetY: 8 })
    }
    .width('85%')
  }

  build() {
    Stack() {
      Column() {
        Column() {
          this.DateGrid()
        }
        .width('calc(100% - 32vp)')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 12, color: '#14000000', offsetX: 0, offsetY: 4 })

        Column().height(12)

        BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 16, customRadius: 16 }) {
          Column() {
            this.EventList()
            BounceButton({
              text: '添加事件',
              iconName: 'calendar',
              bgColor: ColorConstants.BUTTON_PRIMARY,
              textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
              customWidth: '100%',
              customHeight: 44,
              customRadius: 12,
              fontSize: 14,
              fontWeight: FontWeight.Medium,
              onAction: () => { this.openAddDialog(); }
            })
          }
        }
      }
      .width('100%')

      if (this.showEventDialog) {
        Stack() {
          Column()
            .width('100%').height('100%')
            .backgroundColor('#66000000')
            .onClick(() => { this.showEventDialog = false; })

          Column() {
            this.EventDialog()
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center)
          .hitTestBehavior(HitTestMode.None)
        }
        .width('100%').height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .margin({ top: 8 })
  }
}
