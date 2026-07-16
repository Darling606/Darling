import { HealthRecord, FeedPlan, PetProfile, generateId } from '../model/PetModels';
import { StorageManager } from '../model/StorageManager';
import { AuthManager } from '../model/AuthManager';
import { PhoneDistributedManager } from '../model/PhoneDistributedManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState, PressableChip } from '../components/BounceComponents';
import { LineIcon, LineIconButton, MinimalPetAvatar, LineIconName } from '../components/LineIcons';
import { CloudSyncService } from '../service/CloudSyncService';

const CLOUD_SYNC_INTERVAL_MS: number = 2000;

@Component
export struct PetHealthPage {
  @State healthRecords: HealthRecord[] = [];
  @State feedPlans: FeedPlan[] = [];
  @State petList: PetProfile[] = [];
  @State hasPets: boolean = false;
  @State isLoading: boolean = true;
  @State selectedTab: number = 0;
  @State showAddRecord: boolean = false;
  @State showAddFeedPlan: boolean = false;
  @State editingFeedPlanId: string = '';
  @State selectedPetId: string = '';
  @State newWeight: number = 0;
  @State newTemperature: number = 0;
  @State newDiet: string = '';
  @State newStool: string = '';
  @State newNotes: string = '';
  @State newFeedHourText: string = '08';
  @State newFeedMinuteText: string = '00';
  @State newFeedAmount: string = '50g';
  @State newFeedType: string = '主粮';
  @State filteredHealthRecords: HealthRecord[] = [];
  @State filteredFeedPlans: FeedPlan[] = [];
  @State healthScore: number = 0;
  @StorageLink('petDataVersion') @Watch('onPetDataChanged') petDataVersion: number = 0;

  private storageManager: StorageManager = StorageManager.getInstance();
  private authManager: AuthManager = AuthManager.getInstance();
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private tabLabels: string[] = ['健康记录', '喂食计划', '健康趋势'];
  private feedTimer: number = -1;
  private cloudSyncTimer: number = -1;
  private isCloudSyncing: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storageManager.init(getContext(this));
    await this.loadPetData();
    this.startFeedReminderTimer();
    this.startCloudSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopFeedReminderTimer();
    this.stopCloudSyncTimer();
  }

  async loadPetData(): Promise<void> {
    this.petList = await this.storageManager.getPetList();
    this.hasPets = this.petList.length > 0;
    if (this.petList.length > 0 && this.selectedPetId.length === 0) {
      this.selectedPetId = this.petList[0].id;
    }
    this.healthRecords = await this.storageManager.getHealthRecords();
    this.feedPlans = this.normalizeFeedPlans(await this.storageManager.getFeedPlans());
    await this.refreshCloudData();
    this.updateFilteredData();
    this.isLoading = false;
  }

  onPetDataChanged(): void {
    this.loadPetData();
  }

  normalizeFeedPlans(list: FeedPlan[]): FeedPlan[] {
    const normalized: FeedPlan[] = [];
    for (let i = 0; i < list.length; i++) {
      const source = list[i];
      const plan = new FeedPlan();
      plan.id = source.id;
      plan.petId = source.petId;
      plan.time = source.time;
      plan.amount = source.amount;
      plan.type = source.type;
      plan.enabled = source.enabled !== undefined ? source.enabled : true;
      plan.lastTriggeredAt = source.lastTriggeredAt || '';
      plan.lastFeedAt = source.lastFeedAt || 0;
      plan.updatedAt = source.updatedAt || 0;
      plan.deleted = source.deleted === true;
      normalized.push(plan);
    }
    return normalized;
  }

  cloneFeedPlan(source: FeedPlan): FeedPlan {
    const plan = new FeedPlan();
    plan.id = source.id;
    plan.petId = source.petId;
    plan.time = source.time;
    plan.amount = source.amount;
    plan.type = source.type;
    plan.enabled = source.enabled;
    plan.lastTriggeredAt = source.lastTriggeredAt;
    plan.lastFeedAt = source.lastFeedAt;
    plan.updatedAt = source.updatedAt;
    plan.deleted = source.deleted;
    return plan;
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
      const localHealthRecords: HealthRecord[] =
        this.cloudSyncService.normalizeLocalItems(await this.storageManager.getHealthRecords());
      const localFeedPlans: FeedPlan[] =
        this.cloudSyncService.normalizeLocalItems(this.normalizeFeedPlans(await this.storageManager.getFeedPlans()));
      const mergedHealthRecords: HealthRecord[] =
        await this.cloudSyncService.syncCollection(account, 'healthRecords', localHealthRecords);
      const mergedFeedPlans: FeedPlan[] =
        await this.cloudSyncService.syncCollection(account, 'feedPlans', localFeedPlans);
      await this.storageManager.saveHealthRecords(mergedHealthRecords);
      await this.storageManager.saveFeedPlans(mergedFeedPlans);
      this.healthRecords = mergedHealthRecords;
      this.feedPlans = this.normalizeFeedPlans(mergedFeedPlans);
      this.updateFilteredData();
    } finally {
      this.isCloudSyncing = false;
    }
  }

  async pushHealthRecordsToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushCollection(account, 'healthRecords', this.healthRecords);
  }

  async pushFeedPlansToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushCollection(account, 'feedPlans', this.feedPlans);
  }

  async deleteFeedPlanFromCloud(planId: string): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.deleteCollectionItem(account, 'feedPlans', planId, Date.now());
  }

  updateFilteredData(): void {
    this.filteredHealthRecords = this.getFilteredRecords();
    this.filteredFeedPlans = this.getFilteredPlans();
    this.calculateHealthScore();
  }

  getFilteredRecords(): HealthRecord[] {
    const result: HealthRecord[] = [];
    for (let i = 0; i < this.healthRecords.length; i++) {
      if (this.healthRecords[i].petId === this.selectedPetId) {
        result.push(this.healthRecords[i]);
      }
    }
    return result;
  }

  getFilteredPlans(): FeedPlan[] {
    const result: FeedPlan[] = [];
    for (let i = 0; i < this.feedPlans.length; i++) {
      if (this.feedPlans[i].petId === this.selectedPetId) {
        result.push(this.feedPlans[i]);
      }
    }
    return result;
  }

  calculateHealthScore(): void {
    const records = this.getFilteredRecords();
    if (records.length === 0) {
      this.healthScore = 0;
      return;
    }
    const latest = records[0];
    let score = 80;
    if (latest.weight > 0 && latest.weight < 50) { score += 5; }
    if (latest.temperature > 37 && latest.temperature < 40) { score += 5; }
    if (latest.diet.length > 0) { score += 5; }
    if (latest.stool === '正常') { score += 5; }
    this.healthScore = Math.min(100, score);
  }

  getScoreColor(): string {
    if (this.healthScore >= 90) { return ColorConstants.SUCCESS; }
    if (this.healthScore >= 70) { return ColorConstants.WARNING; }
    return ColorConstants.ERROR;
  }

  startFeedReminderTimer(): void {
    this.stopFeedReminderTimer();
    this.feedTimer = setInterval(() => { this.checkFeedReminders(); }, 1000);
  }

  stopFeedReminderTimer(): void {
    if (this.feedTimer !== -1) {
      clearInterval(this.feedTimer);
      this.feedTimer = -1;
    }
  }

  formatTime(hour: number, minute: number): string {
    return hour.toString().padStart(2, '0') + ':' + minute.toString().padStart(2, '0');
  }

  parseTimePart(value: string, max: number): number {
    const parsed = parseInt(value.trim());
    if (isNaN(parsed) || parsed < 0 || parsed > max) {
      return -1;
    }
    return parsed;
  }

  async persistFeedPlans(): Promise<void> {
    await this.storageManager.saveFeedPlans(this.feedPlans);
    this.updateFilteredData();
  }

  async checkFeedReminders(): Promise<void> {
    if (this.feedPlans.length === 0) { return; }
    const now = new Date();
    const currentTime = this.formatTime(now.getHours(), now.getMinutes());
    const remainingPlans: FeedPlan[] = [];
    let hasReminder = false;

    for (let i = 0; i < this.feedPlans.length; i++) {
      const plan = this.cloneFeedPlan(this.feedPlans[i]);
      if (plan.enabled && plan.time === currentTime) {
        hasReminder = true;
      } else {
        remainingPlans.push(plan);
      }
    }

    if (hasReminder) {
      this.stopCloudSyncTimer();
      this.isCloudSyncing = true;
      const consumedIds: string[] = [];
      for (let i = 0; i < this.feedPlans.length; i++) {
        if (this.feedPlans[i].enabled && this.feedPlans[i].time === currentTime) {
          consumedIds.push(this.feedPlans[i].id);
        }
      }
      this.feedPlans = remainingPlans;
      await this.persistFeedPlans();
      const account: string = await this.authManager.getAccount();
      if (account.length > 0) {
        for (let i = 0; i < consumedIds.length; i++) {
          await this.cloudSyncService.deleteCollectionItem(account, 'feedPlans', consumedIds[i], Date.now());
        }
      }
      ToastUtils.show('喂食机正在执行投喂，请稍后', 2500);
      this.startCloudSyncTimer();
      this.isCloudSyncing = false;
    }
  }

  async deleteHealthRecord(id: string): Promise<void> {
    this.stopCloudSyncTimer();
    this.isCloudSyncing = true;
    const next: HealthRecord[] = [];
    for (let i = 0; i < this.healthRecords.length; i++) {
      if (this.healthRecords[i].id !== id) {
        next.push(this.healthRecords[i]);
      }
    }
    this.healthRecords = next;
    await this.storageManager.saveHealthRecords(this.healthRecords);
    const account: string = await this.authManager.getAccount();
    if (account.length > 0) {
      await this.cloudSyncService.deleteCollectionItem(account, 'healthRecords', id, Date.now());
    }
    this.updateFilteredData();
    ToastUtils.show('记录已删除');
    this.startCloudSyncTimer();
    this.isCloudSyncing = false;
  }

  @Builder
  healthSwipeDelete(record: HealthRecord): void {
    Row() {
      Text('🗑')
        .fontSize(18)
        .fontColor(Color.White)
    }
    .width(64)
    .height('100%')
    .backgroundColor('#FF6B6B')
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.deleteHealthRecord(record.id);
    })
  }

  async addHealthRecord(): Promise<void> {
    if (this.selectedPetId.length === 0) {
      ToastUtils.show('请先选择宠物');
      return;
    }
    if (this.newWeight <= 0) {
      ToastUtils.show('请输入有效的体重');
      return;
    }
    const record = new HealthRecord();
    record.id = generateId();
    record.petId = this.selectedPetId;
    record.date = new Date().toISOString().split('T')[0];
    record.weight = this.newWeight;
    record.temperature = this.newTemperature;
    record.diet = this.newDiet;
    record.stool = this.newStool;
    record.notes = this.newNotes;
    record.updatedAt = Date.now();
    record.deleted = false;
    this.healthRecords = [record, ...this.healthRecords];
    await this.storageManager.saveHealthRecords(this.healthRecords);
    await this.pushHealthRecordsToCloud();
    await PhoneDistributedManager.getInstance().syncHealthRecordToWatch(record);
    this.showAddRecord = false;
    this.resetRecordForm();
    this.updateFilteredData();
    ToastUtils.showSuccess('记录添加成功');
  }

  resetRecordForm(): void {
    this.newWeight = 0;
    this.newTemperature = 0;
    this.newDiet = '';
    this.newStool = '';
    this.newNotes = '';
  }

  openFeedPlanSheet(): void {
    const now = new Date();
    this.newFeedHourText = now.getHours().toString().padStart(2, '0');
    this.newFeedMinuteText = now.getMinutes().toString().padStart(2, '0');
    this.newFeedAmount = '50g';
    this.newFeedType = '主粮';
    this.editingFeedPlanId = '';
    this.showAddFeedPlan = true;
  }

  openEditFeedPlanSheet(plan: FeedPlan): void {
    const timeParts = plan.time.split(':');
    this.newFeedHourText = timeParts.length > 0 ? timeParts[0] : '08';
    this.newFeedMinuteText = timeParts.length > 1 ? timeParts[1] : '00';
    this.newFeedAmount = plan.amount;
    this.newFeedType = plan.type;
    this.editingFeedPlanId = plan.id;
    this.showAddFeedPlan = true;
  }

  resetFeedPlanForm(): void {
    this.newFeedHourText = '08';
    this.newFeedMinuteText = '00';
    this.newFeedAmount = '50g';
    this.newFeedType = '主粮';
    this.editingFeedPlanId = '';
  }

  async saveFeedPlan(): Promise<void> {
    const hour = this.parseTimePart(this.newFeedHourText, 23);
    const minute = this.parseTimePart(this.newFeedMinuteText, 59);
    if (hour < 0 || minute < 0) {
      ToastUtils.show('请输入正确的预约时间');
      return;
    }
    if (this.newFeedAmount.trim().length === 0) {
      ToastUtils.show('请输入喂食份量');
      return;
    }
    if (this.selectedPetId.length === 0) {
      ToastUtils.show('请先选择宠物');
      return;
    }

    if (this.editingFeedPlanId.length === 0) {
      const plan = new FeedPlan();
      plan.id = generateId();
      plan.petId = this.selectedPetId;
      plan.time = this.formatTime(hour, minute);
      plan.amount = this.newFeedAmount.trim();
      plan.type = this.newFeedType;
      plan.enabled = true;
      plan.updatedAt = Date.now();
      plan.deleted = false;
      this.feedPlans = [plan, ...this.feedPlans];
      await this.persistFeedPlans();
      await this.pushFeedPlansToCloud();
      await PhoneDistributedManager.getInstance().syncFeedPlanToWatch(plan);
      ToastUtils.showSuccess('喂食预约已创建');
    } else {
      const nextPlans: FeedPlan[] = [];
      let updatedPlan: FeedPlan | null = null;
      for (let i = 0; i < this.feedPlans.length; i++) {
        const current = this.cloneFeedPlan(this.feedPlans[i]);
        if (current.id === this.editingFeedPlanId) {
          current.time = this.formatTime(hour, minute);
          current.amount = this.newFeedAmount.trim();
          current.type = this.newFeedType;
          current.updatedAt = Date.now();
          current.deleted = false;
          updatedPlan = current;
        }
        nextPlans.push(current);
      }
      if (updatedPlan === null) {
        ToastUtils.showError('未找到要编辑的喂食计划');
        return;
      }
      this.feedPlans = nextPlans;
      await this.persistFeedPlans();
      await this.pushFeedPlansToCloud();
      await PhoneDistributedManager.getInstance().syncFeedPlanToWatch(updatedPlan);
      ToastUtils.showSuccess('喂食预约已更新');
    }
    this.showAddFeedPlan = false;
    this.resetFeedPlanForm();
  }

  async toggleFeedPlan(plan: FeedPlan, isOn: boolean): Promise<void> {
    const nextPlans: FeedPlan[] = [];
    let updatedPlan: FeedPlan | null = null;
    for (let i = 0; i < this.feedPlans.length; i++) {
      const current = this.cloneFeedPlan(this.feedPlans[i]);
      if (current.id === plan.id) {
        current.enabled = isOn;
        current.updatedAt = Date.now();
        current.deleted = false;
        updatedPlan = current;
      }
      nextPlans.push(current);
    }
    this.feedPlans = nextPlans;
    await this.persistFeedPlans();
    await this.pushFeedPlansToCloud();
    if (updatedPlan !== null) {
      await PhoneDistributedManager.getInstance().syncFeedPlanToWatch(updatedPlan);
    }
  }

  async deleteFeedPlan(planId: string): Promise<void> {
    const nextPlans: FeedPlan[] = [];
    let deletedPetId: string = '';
    for (let i = 0; i < this.feedPlans.length; i++) {
      if (this.feedPlans[i].id !== planId) {
        nextPlans.push(this.cloneFeedPlan(this.feedPlans[i]));
      } else {
        deletedPetId = this.feedPlans[i].petId;
      }
    }
    this.feedPlans = nextPlans;
    await this.persistFeedPlans();
    await this.deleteFeedPlanFromCloud(planId);
    await PhoneDistributedManager.getInstance().deleteFeedPlanFromWatch(planId, deletedPetId);
    ToastUtils.showSuccess('喂食预约已删除');
  }

  async triggerManualFeed(): Promise<void> {
    const nextPlans: FeedPlan[] = [];
    let changed = false;
    for (let i = 0; i < this.feedPlans.length; i++) {
      const current = this.cloneFeedPlan(this.feedPlans[i]);
      if (!changed && current.petId === this.selectedPetId && current.enabled) {
        current.lastFeedAt = Date.now();
        current.updatedAt = Date.now();
        current.deleted = false;
        changed = true;
      }
      nextPlans.push(current);
    }
    if (changed) {
      this.feedPlans = nextPlans;
      await this.persistFeedPlans();
      await this.pushFeedPlansToCloud();
      for (let i = 0; i < this.feedPlans.length; i++) {
        if (this.feedPlans[i].petId === this.selectedPetId && this.feedPlans[i].lastFeedAt > 0) {
          await PhoneDistributedManager.getInstance().syncFeedPlanToWatch(this.feedPlans[i]);
          break;
        }
      }
    }
    ToastUtils.show('喂食机正在执行投喂，请稍后', 2500);
  }

  formatLastFeedTime(timestamp: number): string {
    if (timestamp <= 0) { return '未执行'; }
    const date = new Date(timestamp);
    return (date.getMonth() + 1).toString() + '月'
      + date.getDate().toString() + '日 '
      + date.getHours().toString().padStart(2, '0') + ':'
      + date.getMinutes().toString().padStart(2, '0');
  }

  getEnabledFeedPlanCount(): number {
    let count = 0;
    for (let i = 0; i < this.filteredFeedPlans.length; i++) {
      if (this.filteredFeedPlans[i].enabled) { count++; }
    }
    return count;
  }

  getSelectedPetName(): string {
    for (let i = 0; i < this.petList.length; i++) {
      if (this.petList[i].id === this.selectedPetId) { return this.petList[i].name; }
    }
    return '';
  }

  getCurrentPet(): PetProfile | null {
    for (let i = 0; i < this.petList.length; i++) {
      if (this.petList[i].id === this.selectedPetId) { return this.petList[i]; }
    }
    return null;
  }

  hasCurrentPetAvatar(): boolean {
    const pet = this.getCurrentPet();
    return pet !== null && pet.avatar.length > 0;
  }

  getCurrentPetAvatar(): string {
    const pet = this.getCurrentPet();
    return pet === null ? '' : pet.avatar;
  }

  @Builder
  TabSelector() {
    Row({ space: 6 }) {
      ForEach(this.tabLabels, (label: string, idx: number) => {
        PressableChip({
          text: label,
          selected: this.selectedTab === idx,
          selectedBg: ColorConstants.BUTTON_PRIMARY,
          normalBg: 'transparent',
          selectedTextColor: ColorConstants.TEXT_PRIMARY,
          normalTextColor: ColorConstants.TEXT_SECONDARY,
          customHeight: 30,
          customRadius: 15,
          fontSize: 12,
          horizontalPadding: 12,
          onAction: () => { this.selectedTab = idx; }
        })
      }, (label: string, idx: number) => 'health_tab_' + idx.toString())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 4, bottom: 10 })
  }

  @Builder
  PetSelector() {
    if (this.petList.length > 1) {
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.petList, (pet: PetProfile) => {
            PressableChip({
              text: pet.name,
              selected: this.selectedPetId === pet.id,
              selectedBg: ColorConstants.BUTTON_PRIMARY,
              normalBg: ColorConstants.SECONDARY_BG,
              selectedTextColor: ColorConstants.BUTTON_PRIMARY_TEXT,
              normalTextColor: ColorConstants.TEXT_SECONDARY,
              customHeight: 34,
              customRadius: 17,
              fontSize: 13,
              horizontalPadding: 14,
              onAction: () => {
                this.selectedPetId = pet.id;
                this.updateFilteredData();
              }
            })
          }, (pet: PetProfile) => 'health_pet_' + pet.id)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .padding({ bottom: 4 })
    }
  }

  @Builder
  MetricCard(iconName: LineIconName, label: string, value: string) {
    Column({ space: 8 }) {
      LineIcon({ name: iconName, iconSize: 18, color: ColorConstants.TEXT_SECONDARY })
      Text(value)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorConstants.TEXT_PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor(ColorConstants.TEXT_SECONDARY)
    }
    .layoutWeight(1)
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(ColorConstants.SECONDARY_BG)
    .borderRadius(20)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  HealthScoreCard() {
    BounceCard({ customWidth: '100%', customPadding: 18, customRadius: 24 }) {
      Row({ space: 16 }) {
        if (this.hasCurrentPetAvatar()) {
          Image(this.getCurrentPetAvatar())
            .width(60)
            .height(60)
            .borderRadius(18)
            .objectFit(ImageFit.Cover)
        } else {
          Row() {
            MinimalPetAvatar({
              species: this.getCurrentPet() === null ? 'cat' : this.getCurrentPet()!.type,
              avatarSize: 62,
              bgColor: '#EEF5EC',
              color: '#6E8778',
              radius: 18
            })
          }
          .width(62)
          .height(62)
        }
        Column({ space: 4 }) {
          Text(this.getSelectedPetName())
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorConstants.TEXT_PRIMARY)
          Text('健康评分')
            .fontSize(12)
            .fontColor(ColorConstants.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text(this.healthScore.toString())
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.getScoreColor())
          Text('分')
            .fontSize(12)
            .fontColor(ColorConstants.TEXT_TERTIARY)
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  HealthOverviewGrid() {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        this.MetricCard('scale', '体重', this.filteredHealthRecords.length > 0 ? this.filteredHealthRecords[0].weight.toString() + 'kg' : '--')
        this.MetricCard('food', '饮食', this.filteredHealthRecords.length > 0 ? (this.filteredHealthRecords[0].diet || '正常') : '--')
      }
      Row({ space: 10 }) {
        this.MetricCard('water', '饮水', '适量')
        this.MetricCard('vaccine', '疫苗', '已接种')
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  AddRecordSheet() {
    Column() {
      Column({ space: 14 }) {
        Text('添加健康记录')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)
        TextInput({ placeholder: '体重 (kg)', text: this.newWeight > 0 ? this.newWeight.toString() : '' })
          .width('100%').height(48).type(InputType.Number)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newWeight = parseFloat(value) || 0; })
        TextInput({ placeholder: '体温 (C)', text: this.newTemperature > 0 ? this.newTemperature.toString() : '' })
          .width('100%').height(48).type(InputType.Number)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newTemperature = parseFloat(value) || 0; })
        TextInput({ placeholder: '饮食情况', text: this.newDiet })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newDiet = value; })
        TextInput({ placeholder: '排便情况', text: this.newStool })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newStool = value; })
        TextInput({ placeholder: '备注', text: this.newNotes })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newNotes = value; })
        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 8,
            onAction: () => { this.showAddRecord = false; this.resetRecordForm(); }
          })
          BounceButton({
            text: '添加', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 8,
            onAction: () => { this.addHealthRecord(); }
          })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  FeedPlanSummaryCard() {
    BounceCard({ customWidth: '100%', customPadding: 18, customRadius: 24 }) {
      Column({ space: 12 }) {
        Row() {
          Column({ space: 4 }) {
            Text('定时喂食')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
            Text('为 ' + this.getSelectedPetName() + ' 设置预约喂食时间')
              .fontSize(12)
              .fontColor(ColorConstants.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Column({ space: 2 }) {
            Text(this.getEnabledFeedPlanCount().toString())
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.PRIMARY)
            Text('已启用')
              .fontSize(11)
              .fontColor(ColorConstants.TEXT_TERTIARY)
          }
        }
        Row({ space: 10 }) {
          BounceButton({
            text: '新增预约', iconName: 'calendar',
            bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 42, customRadius: 16,
            onAction: () => { this.openFeedPlanSheet(); }
          })
          BounceButton({
            text: '立即喂食', iconName: 'food',
            bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 42, customRadius: 16,
            onAction: () => { this.triggerManualFeed(); }
          })
        }
      }
      .width('100%')
    }
  }

  @Builder
  AddFeedPlanSheet() {
    Column() {
      Column({ space: 14 }) {
        Text(this.editingFeedPlanId.length > 0 ? '编辑喂食预约' : '新增喂食预约')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)
        Column({ space: 8 }) {
          Text('预约时间')
            .fontSize(13)
            .fontColor(ColorConstants.TEXT_SECONDARY)
            .alignSelf(ItemAlign.Start)
          Row({ space: 8 }) {
            TextInput({ placeholder: '08', text: this.newFeedHourText })
              .width('42%').height(48).type(InputType.Number).textAlign(TextAlign.Center)
              .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8)
              .onChange((value: string) => { this.newFeedHourText = value; })
            Text(':')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
            TextInput({ placeholder: '00', text: this.newFeedMinuteText })
              .width('42%').height(48).type(InputType.Number).textAlign(TextAlign.Center)
              .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8)
              .onChange((value: string) => { this.newFeedMinuteText = value; })
          }
        }
        Row({ space: 8 }) {
          ForEach(['主粮', '零食', '饮水'], (type: string) => {
            BounceButton({
              text: type,
              bgColor: this.newFeedType === type ? ColorConstants.BUTTON_PRIMARY : '#F0F0F0',
              textColor: this.newFeedType === type ? ColorConstants.BUTTON_PRIMARY_TEXT : ColorConstants.TEXT_SECONDARY,
              customWidth: '31%', customHeight: 40, customRadius: 8,
              fontSize: 13,
              onAction: () => { this.newFeedType = type; }
            })
          }, (type: string) => type)
        }
        TextInput({ placeholder: '喂食份量，例如 50g / 100ml', text: this.newFeedAmount })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(8).padding({ left: 16 })
          .onChange((value: string) => { this.newFeedAmount = value; })
        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 8,
            onAction: () => { this.showAddFeedPlan = false; this.resetFeedPlanForm(); }
          })
          BounceButton({
            text: '保存预约', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 8,
            onAction: () => { this.saveFeedPlan(); }
          })
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Text('健康记录')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorConstants.TEXT_PRIMARY)
          Blank()
          if (this.hasPets) {
            LineIconButton({
              iconName: 'plus',
              bgColor: ColorConstants.BUTTON_PRIMARY,
              textColor: '#ffffff',
              customWidth: '36vp',
              customHeight: 36,
              customRadius: 14,
              iconSize: 14,
              onAction: () => { this.showAddRecord = true; }
            })
          }
        }
        .width('100%').height(58).padding({ left: 20, right: 16, top: 10 })

        this.PetSelector()
        this.TabSelector()

        if (this.isLoading) {
          Column({ space: 12 }) {
            LoadingProgress().width(32).height(32).color(ColorConstants.PRIMARY)
            Text('加载中...').fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
          }
          .layoutWeight(1).justifyContent(FlexAlign.Center)
        } else if (!this.hasPets) {
          BounceEmptyState({
            iconName: 'pet',
            title: '暂无健康记录',
            subtitle: '请先到首页添加宠物后再记录健康数据'
          })
          .layoutWeight(1)
        } else if (this.selectedTab === 0) {
          Column({ space: 12 }) {
            this.HealthScoreCard()
            this.HealthOverviewGrid()
            Text('最近记录')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
              .alignSelf(ItemAlign.Start)
              .padding({ left: 16 })
            if (this.filteredHealthRecords.length === 0) {
              BounceEmptyState({
                iconName: 'list',
                title: '暂无记录',
                subtitle: '点击右上角 + 添加健康数据'
              })
            } else {
              List({ space: 10 }) {
                ForEach(this.filteredHealthRecords.slice(0, 5), (record: HealthRecord) => {
                  ListItem() {
                    BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 8 }) {
                      Row({ space: 12 }) {
                        Column() {
                          Text(record.date.substring(5))
                            .fontSize(14).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
                          Text(record.date.substring(0, 4))
                            .fontSize(11).fontColor(ColorConstants.TEXT_TERTIARY)
                        }
                        .width(48).alignItems(HorizontalAlign.Center)
                        Column({ space: 4 }) {
                          Row({ space: 12 }) {
                            Text('体重 ' + record.weight.toString() + 'kg')
                              .fontSize(13).fontColor(ColorConstants.TEXT_PRIMARY)
                            Text('体温 ' + record.temperature.toString() + 'C')
                              .fontSize(13).fontColor(record.temperature > 39 ? ColorConstants.ERROR : ColorConstants.TEXT_SECONDARY)
                          }
                          if (record.diet.length > 0) {
                            Text('饮食: ' + record.diet)
                              .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                          }
                          if (record.notes.length > 0) {
                            Text(record.notes)
                              .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                          }
                        }
                        .layoutWeight(1).alignItems(HorizontalAlign.Start)
                      }
                    }
                  }
                  .swipeAction({
                    end: {
                      builder: () => { this.healthSwipeDelete(record) }
                    }
                  })
                }, (record: HealthRecord) => 'health_' + record.id)
              }
              .width('100%')
              .padding({ left: 16, right: 16 })
              .layoutWeight(1)
            }
          }
          .layoutWeight(1)
        } else if (this.selectedTab === 1) {
          Column({ space: 12 }) {
            this.FeedPlanSummaryCard()
            if (this.filteredFeedPlans.length === 0) {
              BounceEmptyState({
                iconName: 'food',
                title: '暂无喂食计划',
                subtitle: '添加喂食计划后可在此查看和执行'
              })
            } else {
              List({ space: 10 }) {
                ForEach(this.filteredFeedPlans, (plan: FeedPlan) => {
                  ListItem() {
                    BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 8 }) {
                      Column({ space: 10 }) {
                        Row({ space: 12 }) {
                          Text(plan.time)
                            .fontSize(24)
                            .fontWeight(FontWeight.Bold)
                            .fontColor(ColorConstants.TEXT_PRIMARY)
                          Column({ space: 3 }) {
                            Text(plan.type).fontSize(14).fontColor(ColorConstants.TEXT_PRIMARY)
                            Text(plan.amount).fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY)
                          }
                          .layoutWeight(1).alignItems(HorizontalAlign.Start)
                          Toggle({ type: ToggleType.Switch, isOn: plan.enabled })
                            .selectedColor(ColorConstants.SECONDARY)
                            .onChange((isOn: boolean) => { this.toggleFeedPlan(plan, isOn); })
                        }
                        Row() {
                          Text('最近投喂 ' + this.formatLastFeedTime(plan.lastFeedAt))
                            .fontSize(12)
                            .fontColor(ColorConstants.TEXT_TERTIARY)
                          Blank()
                          Text(plan.enabled ? '预约中' : '已暂停')
                            .fontSize(11)
                            .fontColor(plan.enabled ? ColorConstants.SUCCESS : ColorConstants.TEXT_SECONDARY)
                        }
                        Row({ space: 10 }) {
                          BounceButton({
                            text: '编辑', bgColor: '#F5F6F8', textColor: ColorConstants.TEXT_PRIMARY,
                            customWidth: '48%', customHeight: 36, customRadius: 8, fontSize: 13,
                            onAction: () => { this.openEditFeedPlanSheet(plan); }
                          })
                          BounceButton({
                            text: '删除', bgColor: '#FFF0F0', textColor: ColorConstants.ERROR,
                            customWidth: '48%', customHeight: 36, customRadius: 8, fontSize: 13,
                            onAction: () => { this.deleteFeedPlan(plan.id); }
                          })
                        }
                      }
                    }
                  }
                }, (plan: FeedPlan) => 'feed_' + plan.id)
              }
              .width('100%').padding({ left: 16, right: 16 }).layoutWeight(1)
            }
            BounceButton({
              text: '喂食', iconName: 'food',
              bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
              customWidth: 'calc(100% - 32vp)', customHeight: 48,
              customRadius: 8, fontSize: 15,
              onAction: () => { this.triggerManualFeed(); }
            })
            .margin({ left: 16, right: 16, bottom: 16 })
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 8 })
        } else {
          Column({ space: 12 }) {
            if (this.filteredHealthRecords.length === 0) {
              BounceEmptyState({
                iconName: 'activity',
                title: '暂无趋势数据',
                subtitle: '添加健康记录后可查看趋势'
              })
            } else {
              Text('体重趋势')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorConstants.TEXT_PRIMARY)
                .alignSelf(ItemAlign.Start)
                .padding({ left: 16 })
              BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 16, customRadius: 8 }) {
                Row({ space: 4 }) {
                  ForEach(this.filteredHealthRecords.slice(0, 7), (record: HealthRecord, index: number) => {
                    Column() {
                      Text(record.date.substring(5))
                        .fontSize(9).fontColor(ColorConstants.TEXT_TERTIARY)
                      Column()
                        .width(24)
                        .height(Math.max(4, record.weight * 12))
                        .backgroundColor(ColorConstants.PRIMARY)
                        .borderRadius(4)
                      Text(record.weight.toString() + 'kg')
                        .fontSize(10).fontColor(ColorConstants.TEXT_SECONDARY)
                    }
                    .alignItems(HorizontalAlign.Center)
                  }, (record: HealthRecord, index: number) => 'weight_chart_' + index.toString())
                }
                .width('100%').height(140)
                .alignItems(VerticalAlign.Bottom)
                .justifyContent(FlexAlign.SpaceAround)
              }
            }
          }
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%')
      if (this.showAddRecord) { this.AddRecordSheet() }
      if (this.showAddFeedPlan) { this.AddFeedPlanSheet() }
    }
    .width('100%').height('100%')
  }
}
