import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { PetProfile, PetType, PetGender, generateId } from '../model/PetModels';
import { AuthManager } from '../model/AuthManager';
import { StorageManager } from '../model/StorageManager';
import { PhoneDistributedManager } from '../model/PhoneDistributedManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState, BounceBadge } from '../components/BounceComponents';
import { LineIcon, LineIconButton, MinimalPetAvatar, getPetIconName } from '../components/LineIcons';
import { CalendarEvent, getEventTypeColor } from '../model/CalendarModels';
import { CalendarStorage } from '../service/CalendarStorage';
import { CloudSyncService, CloudSyncStatus } from '../service/CloudSyncService';
import { CalendarContent } from './CalendarContent';

const CLOUD_SYNC_INTERVAL_MS: number = 2000;

@Component
struct StaggerReveal {
  @State enterOpacity: number = 0;
  @State enterOffset: number = 16;
  @Prop delay: number = 0;
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {}

  aboutToAppear(): void {
    setTimeout(() => {
      this.enterOpacity = 1;
      this.enterOffset = 0;
    }, this.delay);
  }

  build() {
    Column() {
      this.content()
    }
    .width('100%')
    .opacity(this.enterOpacity)
    .offset({ y: this.enterOffset })
    .animation({ duration: 220, curve: Curve.EaseOut })
  }
}

@Component
export struct PetProfilePage {
  @Prop layoutMode: string = 'compact';
  @State petList: PetProfile[] = [];
  @State isLoading: boolean = true;
  @State showAddPet: boolean = false;
  @State currentPetIndex: number = -1;
  @State showActionSheet: boolean = false;
  @State showAvatarSheet: boolean = false;
  @State avatarPetIndex: number = -1;
  @StorageLink('petDataVersion') petDataVersion: number = 0;
  @State todayEvents: CalendarEvent[] = [];
  @State syncStatus: CloudSyncStatus = new CloudSyncStatus();

  @State newPetName: string = '';
  @State newPetType: PetType = 'cat';
  @State newPetBreed: string = '';
  @State newPetBirthday: string = '';
  @State newPetColor: string = '';
  @State newPetWeight: number = 0;
  @State newPetGender: PetGender = 'male';

  private storageManager: StorageManager = StorageManager.getInstance();
  private authManager: AuthManager = AuthManager.getInstance();
  private calendarStorage: CalendarStorage = new CalendarStorage();
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private cloudSyncTimer: number = -1;
  private isCloudSyncing: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storageManager.init(getContext(this));
    await this.calendarStorage.init(getContext(this));
    await this.loadPets();
    this.startCloudSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopCloudSyncTimer();
  }

  async loadPets(): Promise<void> {
    if (this.isCloudSyncing) { return; }
    this.isCloudSyncing = true;
    try {
      let pets: PetProfile[] = await this.storageManager.getPetList();
      pets = this.cloudSyncService.normalizeLocalPets(pets);
      const account: string = await this.authManager.getAccount();
      if (account.length > 0) {
        pets = await this.cloudSyncService.syncPets(account, pets);
        await this.cloudSyncService.fetchDebug(account);
        await this.storageManager.savePetList(pets);
      } else {
        await this.storageManager.savePetList(pets);
      }
      this.updateSyncStatus();
      this.petList = pets;
      await this.refreshTodayEvents();
      this.normalizeSelectedPet();
      this.isLoading = false;
    } finally {
      this.isCloudSyncing = false;
    }
  }

  async refreshTodayEvents(): Promise<void> {
    const todayStr: string = this.formatToday();
    const allEvents: CalendarEvent[] = await this.calendarStorage.getEvents();
    this.todayEvents = allEvents.filter((e: CalendarEvent): boolean => {
      if (e.eventDate === todayStr) return true;
      if (e.remindDays.length === 0) return false;
      const evtDate: Date = new Date(e.eventDate);
      for (let i = 0; i < e.remindDays.length; i++) {
        const remind: Date = new Date(evtDate);
        remind.setDate(remind.getDate() - e.remindDays[i]);
        const remindStr: string = remind.getFullYear().toString() + '-' +
          (remind.getMonth() + 1).toString().padStart(2, '0') + '-' +
          remind.getDate().toString().padStart(2, '0');
        if (remindStr === todayStr) return true;
      }
      return false;
    });
  }

  async pushPetsToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushPets(account, this.petList);
    await this.cloudSyncService.fetchDebug(account);
    this.updateSyncStatus();
  }

  async deletePetFromCloud(petId: string, updatedAt: number): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.deletePet(account, petId, updatedAt);
    await this.cloudSyncService.fetchDebug(account);
    this.updateSyncStatus();
  }

  startCloudSyncTimer(): void {
    this.stopCloudSyncTimer();
    this.cloudSyncTimer = setInterval(() => {
      this.refreshPetsFromCloud();
    }, CLOUD_SYNC_INTERVAL_MS);
  }

  stopCloudSyncTimer(): void {
    if (this.cloudSyncTimer !== -1) {
      clearInterval(this.cloudSyncTimer);
      this.cloudSyncTimer = -1;
    }
  }

  async refreshPetsFromCloud(): Promise<void> {
    if (this.isCloudSyncing) {
      return;
    }
    this.isCloudSyncing = true;
    try {
      const account: string = await this.authManager.getAccount();
      if (account.length === 0) {
        return;
      }
      const localPets: PetProfile[] = this.cloudSyncService.normalizeLocalPets(await this.storageManager.getPetList());
      const mergedPets: PetProfile[] = await this.cloudSyncService.syncPets(account, localPets);
      await this.cloudSyncService.fetchDebug(account);
      const before: string = JSON.stringify(this.petList);
      const after: string = JSON.stringify(mergedPets);
      if (before !== after) {
        this.petList = mergedPets;
        await this.storageManager.savePetList(this.petList);
        this.normalizeSelectedPet();
        AppStorage.set('petDataVersion', this.petDataVersion + 1);
      }
      this.updateSyncStatus();
    } finally {
      this.isCloudSyncing = false;
    }
  }

  updateSyncStatus(): void {
    const status: CloudSyncStatus = this.cloudSyncService.getStatus();
    const next: CloudSyncStatus = new CloudSyncStatus();
    next.backendUrl = status.backendUrl;
    next.userId = status.userId;
    next.lastAction = status.lastAction;
    next.lastSyncTime = status.lastSyncTime;
    next.localCount = this.petList.length > 0 ? this.petList.length : status.localCount;
    next.remoteCount = status.remoteCount;
    next.mergedCount = status.mergedCount;
    next.netId = status.netId;
    next.interfaceName = status.interfaceName;
    next.ipv4Valid = status.ipv4Valid;
    next.ipv6Valid = status.ipv6Valid;
    next.lastError = status.lastError;
    this.syncStatus = next;
  }

  async syncWatchSnapshot(): Promise<void> {
    const feedPlans = await this.storageManager.getFeedPlans();
    const events = await this.calendarStorage.getEvents();
    await PhoneDistributedManager.getInstance().syncPetSnapshotToWatch(this.petList, feedPlans, events);
  }

  private formatToday(): string {
    const d: Date = new Date();
    const y: string = d.getFullYear().toString();
    const m: string = (d.getMonth() + 1).toString().padStart(2, '0');
    const day: string = d.getDate().toString().padStart(2, '0');
    return y + '-' + m + '-' + day;
  }

  getGenderText(gender: PetGender): string {
    return gender === 'male' ? '♂ 公' : '♀ 母';
  }
  getLifeStage(pet: PetProfile): string {
    return pet.lifeStage || '成年期';
  }

  private isFoldableLayout(): boolean {
    return this.layoutMode === 'medium' || this.layoutMode === 'expanded';
  }

  private normalizeSelectedPet(): void {
    if (this.petList.length === 0) {
      this.currentPetIndex = -1;
      return;
    }
    if (this.currentPetIndex < 0 || this.currentPetIndex >= this.petList.length) {
      this.currentPetIndex = 0;
    }
  }

  private openActionSheet(index: number): void {
    this.currentPetIndex = index;
    this.showActionSheet = true;
  }

  private openAvatarSheet(index: number): void {
    this.avatarPetIndex = index;
    this.showAvatarSheet = true;
  }

  hasValidAvatar(pet: PetProfile): boolean {
    if (pet.avatar.length === 0) { return false; }
    try {
      fileIo.accessSync(pet.avatar);
      return true;
    } catch (e) {
      return false;
    }
  }

  async pickPhotoFromGallery(): Promise<void> {
    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const result = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      });
      if (result.photoUris.length > 0) {
        await this.saveAvatar(result.photoUris[0]);
      }
    } catch (err) {
      if (err && JSON.stringify(err).indexOf('cancel') === -1) {
        ToastUtils.showError('头像上传失败');
      }
    }
  }

  async saveAvatar(sourceUri: string): Promise<void> {
    try {
      if (this.avatarPetIndex < 0 || this.avatarPetIndex >= this.petList.length) { return; }
      const pet: PetProfile = this.petList[this.avatarPetIndex];
      const ctx = getContext(this);
      const avatarDir: string = ctx.filesDir + '/avatars';
      const destPath: string = avatarDir + '/' + pet.id + '.jpg';

      try {
        fileIo.mkdirSync(avatarDir);
      } catch (e) {
        // directory may already exist
      }

      try {
        fileIo.unlinkSync(destPath);
      } catch (e) {
        // file may not exist
      }

      const srcFd = fileIo.openSync(sourceUri, fileIo.OpenMode.READ_ONLY);
      const dstFd = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      const stat = fileIo.statSync(sourceUri);
      fileIo.copyFileSync(srcFd.fd, dstFd.fd, stat.size);
      fileIo.closeSync(srcFd);
      fileIo.closeSync(dstFd);

      pet.avatar = destPath;
      pet.updatedAt = Date.now();
      pet.deleted = false;
      await this.storageManager.savePetList(this.petList);
      AppStorage.set('petDataVersion', this.petDataVersion + 1);
      await PhoneDistributedManager.getInstance().syncPetInfoToWatch(pet);
      await this.syncWatchSnapshot();
      await this.pushPetsToCloud();

      this.showAvatarSheet = false;
      ToastUtils.showSuccess('头像更新成功');
    } catch (err) {
      ToastUtils.showError('头像上传失败');
    }
  }

  async removeAvatar(): Promise<void> {
    try {
      if (this.avatarPetIndex < 0 || this.avatarPetIndex >= this.petList.length) { return; }
      const pet: PetProfile = this.petList[this.avatarPetIndex];
      if (pet.avatar.length > 0) {
        try {
          fileIo.unlinkSync(pet.avatar);
        } catch (e) {
          // file may not exist
        }
        pet.avatar = '';
        pet.updatedAt = Date.now();
        pet.deleted = false;
        await this.storageManager.savePetList(this.petList);
        AppStorage.set('petDataVersion', this.petDataVersion + 1);
        await PhoneDistributedManager.getInstance().syncPetInfoToWatch(pet);
        await this.syncWatchSnapshot();
        await this.pushPetsToCloud();
      }
      this.showAvatarSheet = false;
      ToastUtils.showSuccess('头像已删除');
    } catch (err) {
      ToastUtils.showError('操作失败');
    }
  }

  async addPet(): Promise<void> {
    if (this.newPetName.length === 0) {
      ToastUtils.show('请输入宠物名字');
      return;
    }
    const newPet: PetProfile = new PetProfile();
    newPet.id = generateId();
    newPet.name = this.newPetName;
    newPet.type = this.newPetType;
    newPet.breed = this.newPetBreed;
    newPet.age = 1;
    newPet.lifeStage = '幼年期';
    newPet.gender = this.newPetGender;
    newPet.birthday = this.newPetBirthday;
    newPet.color = this.newPetColor;
    newPet.weight = this.newPetWeight;
    newPet.avatar = '';
    newPet.photos = [];
    newPet.familyMembers = [];
    newPet.notes = '';
    newPet.updatedAt = Date.now();
    newPet.deleted = false;
    this.petList.push(newPet);
    this.currentPetIndex = this.petList.length - 1;
    await this.storageManager.savePetList(this.petList);
    AppStorage.set('petDataVersion', this.petDataVersion + 1);
    await PhoneDistributedManager.getInstance().syncPetInfoToWatch(newPet);
    await this.syncWatchSnapshot();
    await this.pushPetsToCloud();
    this.showAddPet = false;
    this.resetForm();
    ToastUtils.showSuccess('添加成功');
  }

  async deletePet(): Promise<void> {
    this.isCloudSyncing = true;
    this.stopCloudSyncTimer();
    const index = this.currentPetIndex;
    if (index >= 0 && index < this.petList.length) {
      const pet: PetProfile = this.petList[index];
      const deletedAt: number = Date.now();
      if (pet.avatar.length > 0) {
        try { fileIo.unlinkSync(pet.avatar); } catch (e) { /* ignore */ }
      }
      this.petList.splice(index, 1);
      await this.storageManager.savePetList(this.petList);
      AppStorage.set('petDataVersion', this.petDataVersion + 1);
      await PhoneDistributedManager.getInstance().deletePetInfoFromWatch(pet.id);
      await this.syncWatchSnapshot();
      await this.deletePetFromCloud(pet.id, deletedAt);
      if (this.petList.length === 0) {
        this.currentPetIndex = -1;
      } else if (index >= this.petList.length) {
        this.currentPetIndex = this.petList.length - 1;
      } else {
        this.currentPetIndex = index;
      }
      this.showActionSheet = false;
      ToastUtils.showSuccess('已删除');
    }
    this.startCloudSyncTimer();
    this.isCloudSyncing = false;
  }

  resetForm(): void {
    this.newPetName = '';
    this.newPetType = 'cat';
    this.newPetBreed = '';
    this.newPetBirthday = '';
    this.newPetColor = '';
    this.newPetWeight = 0;
    this.newPetGender = 'male';
  }

  @Builder
  AvatarView(pet: PetProfile) {
    if (this.hasValidAvatar(pet)) {
      Image(pet.avatar)
        .width(72)
        .height(72)
        .borderRadius(24)
        .objectFit(ImageFit.Cover)
    } else {
      MinimalPetAvatar({
        species: pet.type,
        avatarSize: 72,
        bgColor: '#FAFBFC',
        color: ColorConstants.TEXT_PRIMARY,
        radius: 8
      })
    }
  }

  @Builder
  PetHeroCard(pet: PetProfile, index: number) {
    BounceCard({
      customWidth: '100%',
      customPadding: 16,
      customRadius: 8,
      onAction: () => {
        this.openActionSheet(index);
      }
    }) {
      Row({ space: 16 }) {
        Stack() {
          Column() {
            this.AvatarView(pet)
          }
          .width(72)
          .height(72)
          .borderRadius(8)
          .backgroundColor('#FAFBFC')
          .justifyContent(FlexAlign.Center)
          .border({ width: 1, color: '#E7EAF0' })

          Column() {
            LineIcon({ name: getPetIconName(pet.type), iconSize: 14, color: ColorConstants.PRIMARY })
          }
          .width(24)
          .height(24)
          .borderRadius(6)
          .backgroundColor(ColorConstants.CARD_BACKGROUND)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .border({ width: 1, color: '#E7EAF0' })
          .position({ x: 48, y: 48 })
        }
        .width(72)
        .height(72)
        .onClick(() => {
          this.openAvatarSheet(index);
        })

        Column({ space: 6 }) {
          Row() {
            Text(pet.name)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
            Blank()
            BounceBadge({
              text: this.getGenderText(pet.gender),
              bgColor: pet.gender === 'male' ? '#E3F2FD' : '#FCE4EC',
              textColor: pet.gender === 'male' ? '#1976D2' : '#C2185B'
            })
          }
          .width('100%')

          Text(pet.breed + ' · ' + this.getLifeStage(pet))
            .fontSize(13)
            .fontColor(ColorConstants.TEXT_SECONDARY)

          Row({ space: 12 }) {
            if (pet.weight > 0) {
              Row({ space: 4 }) {
                LineIcon({ name: 'scale', iconSize: 13, color: ColorConstants.TEXT_TERTIARY })
                Text(pet.weight.toString() + 'kg')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(ColorConstants.TEXT_PRIMARY)
              }
            }
            if (pet.birthday.length > 0) {
              Row({ space: 4 }) {
                LineIcon({ name: 'cake', iconSize: 13, color: ColorConstants.TEXT_TERTIARY })
                Text(pet.birthday)
                  .fontSize(13)
                  .fontColor(ColorConstants.TEXT_SECONDARY)
              }
            }
          }
          .width('100%')

          Row({ space: 8 }) {
            BounceBadge({
              text: '健康',
              bgColor: '#E8F5E9',
              textColor: '#388E3C'
            })
            Text('最近更新: ' + new Date().toISOString().split('T')[0])
              .fontSize(11)
              .fontColor(ColorConstants.TEXT_TERTIARY)
          }
          .width('100%')
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
  }

  @Builder
  SyncInfoRow(label: string, value: string, color: string = ColorConstants.TEXT_SECONDARY) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(ColorConstants.TEXT_TERTIARY)
      Blank()
      Text(value)
        .fontSize(11)
        .fontColor(color)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
  }

  @Builder
  SyncStatusCard() {
    BounceCard({ customWidth: '100%', customPadding: 12, customRadius: 8 }) {
      Column({ space: 6 }) {
        Row({ space: 8 }) {
          LineIcon({ name: 'dot', iconSize: 10, color: this.syncStatus.lastError.length > 0 ? ColorConstants.ERROR : ColorConstants.SUCCESS })
          Text('同步诊断')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor(ColorConstants.TEXT_PRIMARY)
          Blank()
          Text(this.syncStatus.lastSyncTime.length > 0 ? this.syncStatus.lastSyncTime : '未同步')
            .fontSize(11)
            .fontColor(ColorConstants.TEXT_TERTIARY)
        }
        .width('100%')

        this.SyncInfoRow('后端', this.syncStatus.backendUrl)
        this.SyncInfoRow('账号', this.syncStatus.userId.length > 0 ? this.syncStatus.userId : '未登录')
        this.SyncInfoRow('网络',
          'netId=' + this.syncStatus.netId.toString() +
            ' ' + (this.syncStatus.interfaceName.length > 0 ? this.syncStatus.interfaceName : '未知网卡') +
            ' IPv4=' + (this.syncStatus.ipv4Valid ? '可用' : '未知'))
        this.SyncInfoRow('数量',
          '本地=' + this.petList.length.toString() +
            ' 云端=' + (this.syncStatus.remoteCount >= 0 ? this.syncStatus.remoteCount.toString() : '未知') +
            ' 合并=' + this.syncStatus.mergedCount.toString())
        if (this.syncStatus.lastError.length > 0) {
          this.SyncInfoRow('错误', this.syncStatus.lastError, ColorConstants.ERROR)
        }
      }
      .width('100%')
    }
  }

  @Builder
  TodayEventsCard() {
    if (this.todayEvents.length > 0) {
      BounceCard({ customWidth: '100%', customPadding: 16, customRadius: 16 }) {
        Column({ space: 8 }) {
          Row({ space: 8 }) {
            LineIcon({ name: 'calendar', iconSize: 16, color: ColorConstants.PRIMARY })
            Text('今日日程 (' + this.todayEvents.length.toString() + ')')
              .fontSize(14).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
          }
          .width('100%')

          ForEach(this.todayEvents, (event: CalendarEvent) => {
            Row({ space: 8 }) {
              Text('\u25CF')
                .fontSize(12).fontColor(getEventTypeColor(event.type))
              Text(event.title)
                .fontSize(13).fontColor(ColorConstants.TEXT_SECONDARY)
                .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              Blank()
              Text(event.description)
                .fontSize(11).fontColor(ColorConstants.TEXT_TERTIARY)
                .maxLines(1)
            }
            .width('100%')
          }, (event: CalendarEvent) => event.id)
        }
        .width('100%')
      }
    }
  }

  @Builder
  CompactProfileContent() {
    Scroll() {
      Column({ space: 12 }) {
        ForEach(this.petList, (pet: PetProfile, index: number) => {
          StaggerReveal({ delay: index * 60 }) {
            this.PetHeroCard(pet, index)
          }
        }, (pet: PetProfile) => 'pet_' + pet.id)

        this.TodayEventsCard()
        CalendarContent({ onEventSaved: () => { this.refreshTodayEvents(); } })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 16, bottom: 80 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
  }

  @Builder
  PetListItem(pet: PetProfile, index: number) {
    Row({ space: 10 }) {
      MinimalPetAvatar({
        species: pet.type,
        avatarSize: 44,
        bgColor: '#FAFBFC',
        color: ColorConstants.TEXT_PRIMARY,
        radius: 8
      })

      Column({ space: 4 }) {
        Text(pet.name)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text((pet.breed.length > 0 ? pet.breed : '未填写品种') + ' · ' + this.getLifeStage(pet))
          .fontSize(11)
          .fontColor(ColorConstants.TEXT_SECONDARY)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)

      LineIconButton({
        iconName: 'edit',
        bgColor: this.currentPetIndex === index ? ColorConstants.BUTTON_PRIMARY : '#FAFBFC',
        textColor: ColorConstants.TEXT_PRIMARY,
        customWidth: '32vp',
        customHeight: 32,
        customRadius: 8,
        iconSize: 14,
        onAction: () => { this.openActionSheet(index); }
      })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.currentPetIndex === index ? ColorConstants.SECONDARY_BG : '#FAFBFC')
    .borderRadius(8)
    .border({ width: 1, color: this.currentPetIndex === index ? ColorConstants.DIVIDER : '#EEF0F3' })
    .onClick(() => { this.currentPetIndex = index; })
  }

  @Builder
  PetListPanel() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 4 }) {
          Text('宠物档案')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorConstants.TEXT_PRIMARY)
          Text(this.petList.length.toString() + ' 只宠物')
            .fontSize(12)
            .fontColor(ColorConstants.TEXT_TERTIARY)
        }
        .layoutWeight(1)

        LineIconButton({
          iconName: 'plus',
          bgColor: ColorConstants.BUTTON_PRIMARY,
          textColor: '#ffffff',
          customWidth: '40vp',
          customHeight: 40,
          customRadius: 12,
          iconSize: 16,
          onAction: () => { this.showAddPet = true; }
        })
      }
      .width('100%')

      Scroll() {
        Column({ space: 10 }) {
          ForEach(this.petList, (pet: PetProfile, index: number) => {
            this.PetListItem(pet, index)
          }, (pet: PetProfile) => 'fold_pet_' + pet.id)
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width(280)
    .height('100%')
    .padding(14)
    .backgroundColor(ColorConstants.CARD_BACKGROUND)
    .borderRadius(8)
    .border({ width: 1, color: '#EEF0F3' })
    .shadow({ radius: 8, color: ColorConstants.SHADOW_COLOR, offsetX: 0, offsetY: 2 })
  }

  @Builder
  DetailStat(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(ColorConstants.TEXT_PRIMARY)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(label)
        .fontSize(11)
        .fontColor(ColorConstants.TEXT_TERTIARY)
    }
    .layoutWeight(1)
    .padding(10)
    .backgroundColor('#FAFBFC')
    .borderRadius(8)
  }

  @Builder
  PetDetailHeader(pet: PetProfile) {
    BounceCard({ customWidth: '100%', customPadding: 18, customRadius: 12 }) {
      Column({ space: 16 }) {
        Row({ space: 16 }) {
          Stack() {
            this.AvatarView(pet)
          }
          .width(72)
          .height(72)
          .onClick(() => {
            this.openAvatarSheet(this.currentPetIndex);
          })

          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Text(pet.name)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor(ColorConstants.TEXT_PRIMARY)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              BounceBadge({
                text: this.getGenderText(pet.gender),
                bgColor: pet.gender === 'male' ? '#E3F2FD' : '#FCE4EC',
                textColor: pet.gender === 'male' ? '#1976D2' : '#C2185B'
              })
            }
            .width('100%')

            Text((pet.breed.length > 0 ? pet.breed : '未填写品种') + ' · ' + this.getLifeStage(pet))
              .fontSize(13)
              .fontColor(ColorConstants.TEXT_SECONDARY)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Row({ space: 8 }) {
              BounceBadge({ text: '健康', bgColor: '#E8F5E9', textColor: '#388E3C' })
              Text('最近更新: ' + new Date().toISOString().split('T')[0])
                .fontSize(11)
                .fontColor(ColorConstants.TEXT_TERTIARY)
            }
          }
          .layoutWeight(1)

          LineIconButton({
            iconName: 'edit',
            bgColor: ColorConstants.SECONDARY_BG,
            textColor: ColorConstants.TEXT_PRIMARY,
            customWidth: '42vp',
            customHeight: 42,
            customRadius: 12,
            iconSize: 16,
            onAction: () => { this.openActionSheet(this.currentPetIndex); }
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row({ space: 10 }) {
          this.DetailStat('体重', pet.weight > 0 ? pet.weight.toString() + 'kg' : '未填写')
          this.DetailStat('生日', pet.birthday.length > 0 ? pet.birthday : '未填写')
          this.DetailStat('阶段', this.getLifeStage(pet))
        }
        .width('100%')
      }
      .width('100%')
    }
  }

  @Builder
  PetDetailPanel() {
    if (this.currentPetIndex >= 0 && this.currentPetIndex < this.petList.length) {
      Scroll() {
        Column({ space: 12 }) {
          this.PetDetailHeader(this.petList[this.currentPetIndex])
          this.TodayEventsCard()
          CalendarContent({ onEventSaved: () => { this.refreshTodayEvents(); } })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    } else {
      BounceEmptyState({
        iconName: 'pet',
        title: '还没有选中宠物',
        subtitle: '从左侧列表选择一只宠物查看详情'
      })
      .layoutWeight(1)
    }
  }

  @Builder
  FoldableProfileContent() {
    Row({ space: 12 }) {
      this.PetListPanel()
      Column() {
        this.PetDetailPanel()
      }
      .layoutWeight(1)
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 80 })
  }

  @Builder
  AvatarSheet() {
    Column() {
      Column({ space: 0 }) {
        Text('更换头像')
          .fontSize(14)
          .fontColor(ColorConstants.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 12 })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('从相册选择').fontSize(15).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).padding({ left: 20, right: 20 })
        .onClick(() => { this.pickPhotoFromGallery(); })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('拍照').fontSize(15).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).padding({ left: 20, right: 20 })
        .onClick(() => {
          this.showAvatarSheet = false;
          this.pickPhotoFromGallery();
        })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        if (this.avatarPetIndex >= 0 && this.avatarPetIndex < this.petList.length &&
            this.hasValidAvatar(this.petList[this.avatarPetIndex])) {
          Row() {
            Text('删除头像').fontSize(15).fontColor(ColorConstants.ERROR)
          }
          .width('100%').height(48).padding({ left: 20, right: 20 })
          .onClick(() => { this.removeAvatar(); })

          Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)
        }

        Row() {
          Text('取消').fontSize(15).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).justifyContent(FlexAlign.Center)
        .onClick(() => { this.showAvatarSheet = false; })
      }
      .width('100%')
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
    .onClick(() => { this.showAvatarSheet = false; })
  }

  @Builder
  AddPetSheet() {
    Column() {
      Column({ space: 14 }) {
        Text('添加宠物')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)

        TextInput({ placeholder: '宠物名字', text: this.newPetName })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .padding({ left: 16 })
          .onChange((value: string) => { this.newPetName = value; })

        Row({ space: 10 }) {
          BounceButton({
            text: '猫',
            bgColor: this.newPetType === 'cat' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPetType === 'cat' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.newPetType = 'cat'; }
          })
          BounceButton({
            text: '狗',
            bgColor: this.newPetType === 'dog' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPetType === 'dog' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.newPetType = 'dog'; }
          })
          BounceButton({
            text: '其他',
            bgColor: this.newPetType === 'other' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPetType === 'other' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '31%', customHeight: 42, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.newPetType = 'other'; }
          })
        }
        .width('100%')

        TextInput({ placeholder: '品种', text: this.newPetBreed })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .padding({ left: 16 })
          .onChange((value: string) => { this.newPetBreed = value; })

        TextInput({ placeholder: '生日 (如 2023-01-01)', text: this.newPetBirthday })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .padding({ left: 16 })
          .onChange((value: string) => { this.newPetBirthday = value; })

        TextInput({ placeholder: '体重 (kg)', text: this.newPetWeight > 0 ? this.newPetWeight.toString() : '' })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
          .type(InputType.Number)
          .padding({ left: 16 })
          .onChange((value: string) => { this.newPetWeight = parseFloat(value) || 0; })

        Row({ space: 10 }) {
          BounceButton({
            text: '公',
            bgColor: this.newPetGender === 'male' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPetGender === 'male' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 42, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.newPetGender = 'male'; }
          })
          BounceButton({
            text: '母',
            bgColor: this.newPetGender === 'female' ? ColorConstants.PRIMARY : '#F0F0F0',
            textColor: this.newPetGender === 'female' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 42, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.newPetGender = 'female'; }
          })
        }
        .width('100%')

        Row({ space: 10 }) {
          BounceButton({
            text: '取消',
            bgColor: '#F0F0F0',
            textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.showAddPet = false; this.resetForm(); }
          })
          BounceButton({
            text: '确认添加',
            bgColor: ColorConstants.BUTTON_PRIMARY,
            textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            fontSize: 14,
            onAction: () => { this.addPet(); }
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 32 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 24, topRight: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
  }

  @Builder
  ActionSheet() {
    Column() {
      Column({ space: 0 }) {
        Text('操作')
          .fontSize(14)
          .fontColor(ColorConstants.TEXT_TERTIARY)
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 16, bottom: 12 })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('更换头像').fontSize(15).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).padding({ left: 20, right: 20 })
        .onClick(() => {
          this.avatarPetIndex = this.currentPetIndex;
          this.showActionSheet = false;
          this.showAvatarSheet = true;
        })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('编辑信息').fontSize(15).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).padding({ left: 20, right: 20 })
        .onClick(() => {
          this.showActionSheet = false;
          ToastUtils.show('编辑功能开发中');
        })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('删除宠物').fontSize(15).fontColor(ColorConstants.ERROR)
        }
        .width('100%').height(48).padding({ left: 20, right: 20 })
        .onClick(() => { this.deletePet(); })

        Divider().color(ColorConstants.DIVIDER).strokeWidth(0.5)

        Row() {
          Text('取消').fontSize(15).fontWeight(FontWeight.Medium).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(48).justifyContent(FlexAlign.Center)
        .onClick(() => { this.showActionSheet = false; })
      }
      .width('100%')
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius({ topLeft: 20, topRight: 20 })
      .padding({ bottom: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.End)
    .onClick(() => { this.showActionSheet = false; })
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
        } else if (this.petList.length === 0) {
          Column({ space: 12 }) {
            BounceEmptyState({
              iconName: 'pet',
              title: '还没有宠物',
              subtitle: '点击右下角按钮添加你的第一只宠物',
              buttonText: '添加宠物',
              onAction: () => { this.showAddPet = true; }
            })
          }
          .layoutWeight(1)
          .padding({ left: 16, right: 16, top: 16 })
        } else {
          if (this.isFoldableLayout()) {
            this.FoldableProfileContent()
          } else {
            this.CompactProfileContent()
          }
        }
      }
      .width('100%')
      .height('100%')

      if (this.petList.length > 0 && !this.isFoldableLayout()) {
        Stack() {
          LineIconButton({
            iconName: 'healthWhite',
            bgColor: ColorConstants.BUTTON_PRIMARY, textColor: '#FFFFFF',
            customWidth: '56vp',
            customHeight: 56,
            customRadius: 28,
            iconSize: 18,
            onAction: () => { this.showAddPet = true; }
          })
        }
        .width('100%')
        .height('100%')
        .alignContent(Alignment.BottomEnd)
        .padding({ right: 20, bottom: 20 })
        .hitTestBehavior(HitTestMode.None)
      }

      if (this.showAddPet) { this.AddPetSheet() }
      if (this.showActionSheet) { this.ActionSheet() }
      if (this.showAvatarSheet) { this.AvatarSheet() }
    }
    .width('100%')
    .height('100%')
  }
}

