import { BehaviorRecord, PetProfile, BehaviorType, generateId } from '../model/PetModels';
import { StorageManager } from '../model/StorageManager';
import { AuthManager } from '../model/AuthManager';
import { PhoneDistributedManager, WatchBehaviorAlert, WatchLocationInfo } from '../model/PhoneDistributedManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState, PressableChip } from '../components/BounceComponents';
import { LineIcon, LineIconButton, LineIconName } from '../components/LineIcons';
import { geoLocationManager } from '@kit.LocationKit';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CloudSyncService } from '../service/CloudSyncService';

const CLOUD_SYNC_INTERVAL_MS: number = 2000;

interface MapTileInfo {
  id: string;
  url: string;
  left: number;
  top: number;
}

@Component
export struct PetBehaviorPage {
  @State behaviorRecords: BehaviorRecord[] = [];
  @State petList: PetProfile[] = [];
  @State hasPets: boolean = false;
  @State isLoading: boolean = true;
  @State selectedTab: number = 0;
  @State showAddRecord: boolean = false;
  @State selectedPetId: string = '';
  @State newBehaviorType: BehaviorType = '正常';
  @State newDescription: string = '';
  @State newDuration: number = 0;
  @State newNotes: string = '';
  @State filteredBehaviorRecords: BehaviorRecord[] = [];
  @State isMonitoring: boolean = false;
  @State activityScore: number = 0;
  @State sleepScore: number = 0;
  @State moodScore: number = 0;
  @State abnormalCount: number = 0;
  @State activityTrend: number = 0;
  @State sleepTrend: number = 0;
  @State moodTrend: number = 0;
  @State userLat: number = 23.7246660;
  @State userLng: number = 113.1053635;
  @State petLat: number = 23.7249160;
  @State petLng: number = 113.1057135;
  @State mapReady: boolean = false;
  @State mapError: boolean = false;
  @State mapKey: number = 0;
  @State mapNotice: string = '';
  @StorageLink('petDataVersion') @Watch('onPetDataChanged') petDataVersion: number = 0;

  private storageManager: StorageManager = StorageManager.getInstance();
  private authManager: AuthManager = AuthManager.getInstance();
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private tabLabels: string[] = ['分析概览', '行为记录', '训练教程'];
  private cloudSyncTimer: number = -1;
  private isCloudSyncing: boolean = false;
  private readonly mapViewportWidth: number = 346;
  private readonly mapViewportHeight: number = 180;
  private readonly mapTileSize: number = 256;
  private readonly mapZoom: number = 16;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storageManager.init(getContext(this));
    await this.loadPetData();
    this.requestLocation();
    this.startCloudSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopCloudSyncTimer();
  }

  async requestLocation(): Promise<void> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const permissions: Permissions[] = [
        'ohos.permission.APPROXIMATELY_LOCATION',
        'ohos.permission.LOCATION'
      ];
      const grantResult =
        await atManager.requestPermissionsFromUser(getContext(this), permissions);
      const allGranted: boolean = grantResult.authResults.every((r: number) => r === 0);
      if (allGranted) {
        this.fetchLocation();
      }
    } catch (err) {
      console.error('requestLocation error:', JSON.stringify(err));
    }
  }

  async fetchLocation(): Promise<void> {
    try {
      const requestInfo: geoLocationManager.SingleLocationRequest = {
        locatingPriority: geoLocationManager.LocatingPriority.PRIORITY_ACCURACY,
        locatingTimeoutMs: 10000
      };
      const location: geoLocationManager.Location =
        await geoLocationManager.getCurrentLocation(requestInfo);
      this.userLat = location.latitude;
      this.userLng = location.longitude;
      this.mapNotice = '';
      this.petLat = this.userLat + (Math.random() - 0.5) * 0.002;
      this.petLng = this.userLng + (Math.random() - 0.5) * 0.002;
      console.info(
        'PetMap: location success lat=' + this.userLat.toString()
          + ' lng=' + this.userLng.toString()
          + ' petLat=' + this.petLat.toString()
          + ' petLng=' + this.petLng.toString()
      );
      this.mapReady = true;
      this.mapKey++;
      await this.syncLocationToWatch();
    } catch (err) {
      const error = err as BusinessError;
      const code = error.code || 0;
      const message = error.message || JSON.stringify(err);
      console.error('PetMap: fetchLocation failed code=' + code.toString() + ' message=' + message);
      if (code === 801 || code === 3301100 || code === 3301200) {
        this.mapNotice = '模拟器定位不可用，已使用默认位置';
      } else {
        this.mapNotice = '定位失败，已使用默认位置';
      }
      await this.syncLocationToWatch();
    }
  }

  async syncLocationToWatch(): Promise<void> {
    if (this.selectedPetId.length === 0) {
      return;
    }
    const location: WatchLocationInfo = new WatchLocationInfo();
    location.petId = this.selectedPetId;
    location.userLat = this.userLat;
    location.userLng = this.userLng;
    location.petLat = this.petLat;
    location.petLng = this.petLng;
    location.address = '广东碧桂园职业学院';
    location.deleted = false;
    await PhoneDistributedManager.getInstance().syncLocationToWatch(location);
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
      const localRecords: BehaviorRecord[] =
        this.cloudSyncService.normalizeLocalItems(await this.storageManager.getBehaviorRecords());
      const mergedRecords: BehaviorRecord[] =
        await this.cloudSyncService.syncCollection(account, 'behaviorRecords', localRecords);
      await this.storageManager.saveBehaviorRecords(mergedRecords);
      this.behaviorRecords = mergedRecords;
      this.updateFilteredRecords();
      this.updateBehaviorStats();
    } finally {
      this.isCloudSyncing = false;
    }
  }

  async pushBehaviorRecordsToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushCollection(account, 'behaviorRecords', this.behaviorRecords);
  }

  private lngToTileX(lng: number, zoom: number): number {
    return (lng + 180) / 360 * Math.pow(2, zoom);
  }

  private latToTileY(lat: number, zoom: number): number {
    const rad: number = lat * Math.PI / 180;
    return (1 - Math.log(Math.tan(rad) + 1 / Math.cos(rad)) / Math.PI) / 2 * Math.pow(2, zoom);
  }

  private getMapStartTileX(): number {
    const centerX: number = this.lngToTileX(this.userLng, this.mapZoom);
    const cols: number = Math.ceil(this.mapViewportWidth / this.mapTileSize) + 2;
    return Math.floor(centerX) - Math.floor(cols / 2);
  }

  private getMapStartTileY(): number {
    const centerY: number = this.latToTileY(this.userLat, this.mapZoom);
    const rows: number = Math.ceil(this.mapViewportHeight / this.mapTileSize) + 2;
    return Math.floor(centerY) - Math.floor(rows / 2);
  }

  private getMapOffsetX(): number {
    const centerX: number = this.lngToTileX(this.userLng, this.mapZoom);
    const startX: number = this.getMapStartTileX();
    return this.mapViewportWidth / 2 - (centerX - startX) * this.mapTileSize;
  }

  private getMapOffsetY(): number {
    const centerY: number = this.latToTileY(this.userLat, this.mapZoom);
    const startY: number = this.getMapStartTileY();
    return this.mapViewportHeight / 2 - (centerY - startY) * this.mapTileSize;
  }

  private getMapTiles(): MapTileInfo[] {
    const tiles: MapTileInfo[] = [];
    const cols: number = Math.ceil(this.mapViewportWidth / this.mapTileSize) + 2;
    const rows: number = Math.ceil(this.mapViewportHeight / this.mapTileSize) + 2;
    const startX: number = this.getMapStartTileX();
    const startY: number = this.getMapStartTileY();
    const offsetX: number = this.getMapOffsetX();
    const offsetY: number = this.getMapOffsetY();

    for (let r = 0; r < rows; r++) {
      for (let c = 0; c < cols; c++) {
        const x: number = startX + c;
        const y: number = startY + r;
        const sub: number = ((x + y) % 4 + 4) % 4 + 1;
        tiles.push({
          id: x.toString() + '_' + y.toString() + '_' + this.mapKey.toString(),
          url: 'https://webrd0' + sub.toString()
            + '.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=7&x='
            + x.toString() + '&y=' + y.toString() + '&z=' + this.mapZoom.toString(),
          left: (x - startX) * this.mapTileSize + offsetX,
          top: (y - startY) * this.mapTileSize + offsetY
        });
      }
    }
    console.info('PetMap: native tiles count=' + tiles.length.toString());
    return tiles;
  }

  private lngToMapX(lng: number): number {
    const startX: number = this.getMapStartTileX();
    const offsetX: number = this.getMapOffsetX();
    return (this.lngToTileX(lng, this.mapZoom) - startX) * this.mapTileSize + offsetX;
  }

  private latToMapY(lat: number): number {
    const startY: number = this.getMapStartTileY();
    const offsetY: number = this.getMapOffsetY();
    return (this.latToTileY(lat, this.mapZoom) - startY) * this.mapTileSize + offsetY;
  }

  @Builder
  NativeTileMap() {
    Stack() {
      this.MapFallbackGrid()

      ForEach(this.getMapTiles(), (tile: MapTileInfo) => {
        Image(tile.url)
          .width(this.mapTileSize)
          .height(this.mapTileSize)
          .objectFit(ImageFit.Fill)
          .position({ x: tile.left, y: tile.top })
          .onComplete(() => {
            console.info('PetMap: native tile loaded ' + tile.id);
          })
          .onError(() => {
            console.error('PetMap: native tile failed ' + tile.id + ' url=' + tile.url);
          })
      }, (tile: MapTileInfo) => tile.id)

      Line()
        .width(this.mapViewportWidth)
        .height(this.mapViewportHeight)
        .startPoint([this.lngToMapX(this.userLng), this.latToMapY(this.userLat)])
        .endPoint([this.lngToMapX(this.petLng), this.latToMapY(this.petLat)])
        .stroke('#AAFF7FAF')
        .strokeWidth(2.5)
        .strokeDashArray([6, 4])

      this.MapMarker(this.lngToMapX(this.petLng), this.latToMapY(this.petLat), '#4CAF50')
      this.MapMarker(this.lngToMapX(this.userLng), this.latToMapY(this.userLat), '#FF7FAF')
    }
    .width('100%')
    .height(this.mapViewportHeight)
    .clip(true)
    .backgroundColor('#EEF1F5')
  }

  @Builder
  MapFallbackGrid() {
    Stack() {
      ForEach([28, 66, 104, 142], (top: number) => {
        Divider()
          .width('100%')
          .height(1)
          .color('#4497A3B5')
          .position({ x: 0, y: top })
      }, (top: number) => 'h_' + top.toString())

      ForEach([32, 78, 124, 170, 216, 262, 308], (left: number) => {
        Divider()
          .width(1)
          .height('100%')
          .color('#4497A3B5')
          .position({ x: left, y: 0 })
      }, (left: number) => 'v_' + left.toString())
    }
    .width('100%')
    .height(this.mapViewportHeight)
    .backgroundColor('#F3F6FA')
  }

  @Builder
  MapMarker(x: number, y: number, color: string) {
    Column()
      .width(18)
      .height(18)
      .borderRadius(9)
      .backgroundColor(color)
      .border({ width: 2.5, color: '#FFFFFF' })
      .shadow({ radius: 8, color: '#55000000', offsetX: 0, offsetY: 2 })
      .position({ x: x - 9, y: y - 9 })
  }

  async loadPetData(): Promise<void> {
    this.petList = await this.storageManager.getPetList();
    this.hasPets = this.petList.length > 0;
    if (this.petList.length > 0) {
      this.selectedPetId = this.petList[0].id;
    }
    this.behaviorRecords = await this.storageManager.getBehaviorRecords();
    await this.refreshCloudData();
    this.updateFilteredRecords();
    this.updateBehaviorStats();
    await this.syncLocationToWatch();
    this.isLoading = false;
  }

  onPetDataChanged(): void {
    this.loadPetData();
  }

  updateFilteredRecords(): void {
    this.filteredBehaviorRecords = this.getFilteredRecords();
  }

  getFilteredRecords(): BehaviorRecord[] {
    const result: BehaviorRecord[] = [];
    for (let i = 0; i < this.behaviorRecords.length; i++) {
      if (this.behaviorRecords[i].petId === this.selectedPetId) {
        result.push(this.behaviorRecords[i]);
      }
    }
    return result;
  }

  updateBehaviorStats(): void {
    const records = this.getFilteredRecords();
    this.abnormalCount = 0;
    for (let i = 0; i < records.length; i++) {
      if (records[i].type === '异常' || records[i].type === '焦虑') {
        this.abnormalCount++;
      }
    }
    const total = records.length || 1;
    this.activityScore = Math.round(Math.min(100, ((total - this.abnormalCount) / total) * 80 + 20));
    this.sleepScore = Math.round(Math.min(100, ((total - this.abnormalCount) / total) * 85 + 10));
    this.moodScore = Math.round(Math.max(0, 100 - (this.abnormalCount / total) * 100));
    this.activityTrend = Math.round(Math.random() * 20 - 8);
    this.sleepTrend = Math.round(Math.random() * 15 - 5);
    this.moodTrend = Math.round(Math.random() * 10 - 3);
  }

  getScoreLabel(score: number): string {
    if (score >= 85) { return '良好'; }
    if (score >= 65) { return '正常'; }
    return '偏低';
  }

  getScoreColor(score: number): string {
    if (score >= 85) { return '#4CAF50'; }
    if (score >= 65) { return '#FFB74D'; }
    return '#FF6B6B';
  }

  getTrendText(trend: number): string {
    if (trend > 0) { return '↑' + trend.toString() + '%'; }
    if (trend < 0) { return '↓' + Math.abs(trend).toString() + '%'; }
    return '—';
  }

  getTrendColor(trend: number): string {
    if (trend > 0) { return '#4CAF50'; }
    if (trend < 0) { return '#FF6B6B'; }
    return '#8A8A8A';
  }

  async deleteBehaviorRecord(id: string): Promise<void> {
    this.stopCloudSyncTimer();
    this.isCloudSyncing = true;
    const next: BehaviorRecord[] = [];
    for (let i = 0; i < this.behaviorRecords.length; i++) {
      if (this.behaviorRecords[i].id !== id) {
        next.push(this.behaviorRecords[i]);
      }
    }
    this.behaviorRecords = next;
    await this.storageManager.saveBehaviorRecords(this.behaviorRecords);
    const account: string = await this.authManager.getAccount();
    if (account.length > 0) {
      await this.cloudSyncService.deleteCollectionItem(account, 'behaviorRecords', id, Date.now());
    }
    this.updateFilteredRecords();
    this.updateBehaviorStats();
    ToastUtils.show('记录已删除');
    this.startCloudSyncTimer();
    this.isCloudSyncing = false;
  }

  @Builder
  behaviorSwipeDelete(record: BehaviorRecord): void {
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
      this.deleteBehaviorRecord(record.id);
    })
  }

  async addBehaviorRecord(): Promise<void> {
    if (this.selectedPetId.length === 0) {
      ToastUtils.show('请先选择宠物');
      return;
    }
    const record: BehaviorRecord = new BehaviorRecord();
    record.id = generateId();
    record.petId = this.selectedPetId;
    record.date = new Date().toISOString().split('T')[0];
    record.type = this.newBehaviorType;
    record.description = this.newDescription;
    record.duration = this.newDuration;
    record.notes = this.newNotes;
    record.updatedAt = Date.now();
    record.deleted = false;
    this.behaviorRecords.unshift(record);
    await this.storageManager.saveBehaviorRecords(this.behaviorRecords);
    await this.pushBehaviorRecordsToCloud();
    if (record.type === '异常' || record.type === '焦虑') {
      const alert: WatchBehaviorAlert = new WatchBehaviorAlert();
      alert.id = record.id;
      alert.petId = record.petId;
      alert.type = record.type;
      alert.message = record.description;
      alert.timestamp = Date.now();
      await PhoneDistributedManager.getInstance().sendBehaviorAlertToWatch(alert);
    }
    this.updateFilteredRecords();
    this.updateBehaviorStats();
    this.showAddRecord = false;
    this.resetForm();
    ToastUtils.showSuccess('记录添加成功');
  }

  resetForm(): void {
    this.newBehaviorType = '正常';
    this.newDescription = '';
    this.newDuration = 0;
    this.newNotes = '';
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
      }, (label: string, idx: number) => 'btab_' + idx.toString())
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
                this.updateFilteredRecords();
                this.updateBehaviorStats();
                this.syncLocationToWatch();
              }
            })
          }, (pet: PetProfile) => 'bpet_' + pet.id)
        }
        .padding({ left: 16, right: 16 })
      }
      .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      .padding({ bottom: 4 })
    }
  }

  @Builder
  StatCard(iconName: LineIconName, label: string, value: string, score: number, trend: number) {
    Column({ space: 8 }) {
      Row() {
        LineIcon({ name: iconName, iconSize: 18, color: ColorConstants.TEXT_PRIMARY })
        Blank()
        Text(this.getTrendText(trend))
          .fontSize(11).fontColor(ColorConstants.TEXT_TERTIARY)
      }
      .width('100%')

      Text(value)
        .fontSize(22).fontWeight(FontWeight.Bold)
        .fontColor(ColorConstants.TEXT_PRIMARY)
      Text(label)
        .fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY)
    }
    .layoutWeight(1).padding(14)
    .backgroundColor(ColorConstants.SECONDARY_BG)
    .borderRadius(20)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  AddRecordSheet() {
    Column() {
      Column({ space: 14 }) {
        Text('添加行为记录')
          .fontSize(20).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)

        Row({ space: 8 }) {
          BounceButton({
            text: '正常',
            bgColor: this.newBehaviorType === '正常' ? ColorConstants.BUTTON_PRIMARY : '#F0F0F0',
            textColor: this.newBehaviorType === '正常' ? ColorConstants.BUTTON_PRIMARY_TEXT : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 40, customRadius: 12,
            fontSize: 13,
            onAction: () => { this.newBehaviorType = '正常'; }
          })
          BounceButton({
            text: '异常',
            bgColor: this.newBehaviorType === '异常' ? ColorConstants.BUTTON_PRIMARY : '#F0F0F0',
            textColor: this.newBehaviorType === '异常' ? ColorConstants.BUTTON_PRIMARY_TEXT : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 40, customRadius: 12,
            fontSize: 13,
            onAction: () => { this.newBehaviorType = '异常'; }
          })
          BounceButton({
            text: '焦虑',
            bgColor: this.newBehaviorType === '焦虑' ? ColorConstants.BUTTON_PRIMARY : '#F0F0F0',
            textColor: this.newBehaviorType === '焦虑' ? ColorConstants.BUTTON_PRIMARY_TEXT : ColorConstants.TEXT_SECONDARY,
            customWidth: '30%', customHeight: 40, customRadius: 12,
            fontSize: 13,
            onAction: () => { this.newBehaviorType = '焦虑'; }
          })
        }
        .width('100%')

        TextInput({ placeholder: '行为描述', text: this.newDescription })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16 })
          .onChange((value: string) => { this.newDescription = value; })

        TextInput({ placeholder: '持续时长 (分钟)', text: this.newDuration > 0 ? this.newDuration.toString() : '' })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .type(InputType.Number).padding({ left: 16 })
          .onChange((value: string) => { this.newDuration = parseInt(value) || 0; })

        TextInput({ placeholder: '备注', text: this.newNotes })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16 })
          .onChange((value: string) => { this.newNotes = value; })

        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.showAddRecord = false; this.resetForm(); }
          })
          BounceButton({
            text: '添加', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.addBehaviorRecord(); }
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

  build() {
    Stack() {
      Column() {
        Row() {
          Text('行为分析')
            .fontSize(28).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
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
            title: '暂无行为数据',
            subtitle: '请先到首页添加宠物后再记录行为'
          })
          .layoutWeight(1)
        } else if (this.selectedTab === 0) {
          Column({ space: 14 }) {
            Row({ space: 10 }) {
              this.StatCard('mapPin', '活跃度', this.activityScore.toString() + '%', this.activityScore, this.activityTrend)
              this.StatCard('heart', '睡眠质量', this.sleepScore.toString() + '%', this.sleepScore, this.sleepTrend)
            }
            .width('100%').padding({ left: 16, right: 16 })

            Row({ space: 10 }) {
              this.StatCard('chat', '情绪指数', this.moodScore.toString() + '%', this.moodScore, this.moodTrend)
              this.StatCard('trophy', '异常行为', this.abnormalCount === 0 ? '未发现' : this.abnormalCount.toString() + '次',
                this.abnormalCount === 0 ? 90 : 40, 0)
            }
            .width('100%').padding({ left: 16, right: 16 })

            if (this.hasPets) {
              Row({ space: 6 }) {
                LineIcon({ name: 'mapPin', iconSize: 16, color: ColorConstants.TEXT_PRIMARY })
                Text('宠物位置')
                  .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
              }
                .alignSelf(ItemAlign.Start)
                .padding({ left: 16 })

              BounceCard({ customWidth: 'calc(100% - 32vp)', customPadding: 0, customRadius: 24 }) {
                Column() {
                  if (this.mapError) {
                    Column({ space: 8 }) {
                      LineIcon({ name: 'mapPin', iconSize: 32, color: ColorConstants.TEXT_TERTIARY })
                      Text('地图加载失败').fontSize(14).fontColor(ColorConstants.TEXT_SECONDARY)
                      Text('请检查网络连接').fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                       BounceButton({
                         text: '重新加载', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT, customWidth: '40%', customHeight: 36,
                         customRadius: 12, fontSize: 13,
                         onAction: () => {
                           this.mapError = false;
                           this.mapReady = true;
                           this.mapKey++;
                         }
                       })
                    }
                    .width('100%').height(180)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor(ColorConstants.SECONDARY_BG)
                  } else {
                    Stack() {
                      this.NativeTileMap()

                      Row() {
                        Blank()
                        LineIconButton({
                          iconName: 'mapPin',
                          bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
                          customWidth: '32vp',
                          customHeight: 32,
                          customRadius: 16,
                          iconSize: 14,
                          onAction: () => {
                            this.mapReady = true;
                            this.mapKey++;
                          }
                        })
                      }
                      .width('100%').height(180)
                      .padding({ top: 8, right: 8 })
                      .hitTestBehavior(HitTestMode.Transparent)
                    }
                  }

                  Column({ space: 8 }) {
                    Row({ space: 8 }) {
                      Column()
                        .width(10).height(10).borderRadius(5)
                        .backgroundColor(ColorConstants.PRIMARY)
                      Text('用户：' + this.userLat.toFixed(4) + ', ' + this.userLng.toFixed(4))
                        .fontSize(13).fontColor(ColorConstants.TEXT_PRIMARY)
                    }.width('100%')

                    Row({ space: 8 }) {
                      Column()
                        .width(10).height(10).borderRadius(5)
                        .backgroundColor(ColorConstants.SECONDARY)
                      Text('宠物：' + this.petLat.toFixed(4) + ', ' + this.petLng.toFixed(4))
                        .fontSize(13).fontColor(ColorConstants.TEXT_PRIMARY)
                    }.width('100%')

                    if (this.mapNotice.length > 0) {
                      Text(this.mapNotice)
                        .fontSize(12)
                        .fontColor(ColorConstants.TEXT_TERTIARY)
                        .width('100%')
                    }
                  }
                  .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 12 })
                }
                .width('100%')
              }
            }

            if (this.filteredBehaviorRecords.length < 3) {
              Text('记录较少，分析结果可能不准确')
                .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                .textAlign(TextAlign.Center).width('100%')
            }
          }
          .layoutWeight(1)

        } else if (this.selectedTab === 1) {
          Column({ space: 12 }) {
            if (this.filteredBehaviorRecords.length === 0) {
              BounceEmptyState({
                iconName: 'chat',
                title: '暂无行为记录',
                subtitle: '点击 + 添加 记录宠物行为'
              })
            } else {
              List({ space: 10 }) {
                ForEach(this.filteredBehaviorRecords, (record: BehaviorRecord) => {
                  ListItem() {
                    BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 14 }) {
                      Column({ space: 6 }) {
                        Row() {
                          Text(record.date).fontSize(13).fontColor(ColorConstants.TEXT_TERTIARY)
                          Blank()
                          Text(record.type).fontSize(12).fontWeight(FontWeight.Medium)
                            .fontColor(record.type === '正常' ? ColorConstants.PRIMARY : ColorConstants.TEXT_PRIMARY)
                            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                            .backgroundColor(record.type === '正常' ? ColorConstants.PRIMARY_LIGHT : '#DDE2DD')
                            .borderRadius(10)
                        }
                        .width('100%')
                        Text(record.description || '无描述').fontSize(14).fontColor(ColorConstants.TEXT_PRIMARY)
                        Text((record.duration > 0 ? '时长: ' + record.duration.toString() + '分钟' : '') + '  ' + record.notes)
                          .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                      }
                      .width('100%')
                    }
                  }
                  .swipeAction({
                    end: {
                      builder: () => { this.behaviorSwipeDelete(record) }
                    }
                  })
                }, (record: BehaviorRecord) => 'brec_' + record.id)
              }
              .width('100%').padding({ left: 16, right: 16 }).layoutWeight(1)
            }
          }
          .layoutWeight(1)

        } else {
          Column({ space: 12 }) {
            Text('行为矫正训练')
              .fontSize(15).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
              .alignSelf(ItemAlign.Start).padding({ left: 16 })

            List({ space: 10 }) {
              ListItem() {
                BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 14 }) {
                  Row({ space: 12 }) {
                    LineIcon({ name: 'dog', iconSize: 26, color: ColorConstants.TEXT_TERTIARY })
                    Column({ space: 3 }) {
                      Text('分离焦虑训练').fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
                      Text('帮助宠物适应独处').fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY)
                    }.layoutWeight(1)
                  }.width('100%')
                }
              }
              ListItem() {
                BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 14 }) {
                  Row({ space: 12 }) {
                    LineIcon({ name: 'pet', iconSize: 26, color: ColorConstants.TEXT_TERTIARY })
                    Column({ space: 3 }) {
                      Text('抓挠行为矫正').fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
                      Text('引导正确使用抓挠工具').fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY)
                    }.layoutWeight(1)
                  }.width('100%')
                }
              }
              ListItem() {
                BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 14 }) {
                  Row({ space: 12 }) {
                    LineIcon({ name: 'bell', iconSize: 26, color: ColorConstants.TEXT_TERTIARY })
                    Column({ space: 3 }) {
                      Text('过度吠叫训练').fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
                      Text('减少不必要的吠叫').fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY)
                    }.layoutWeight(1)
                  }.width('100%')
                }
              }
            }
            .width('100%').padding({ left: 16, right: 16 }).layoutWeight(1)
          }
          .layoutWeight(1)
        }
      }
      .width('100%').height('100%')

      if (this.showAddRecord) { this.AddRecordSheet() }
    }
    .width('100%').height('100%')
  }
}
