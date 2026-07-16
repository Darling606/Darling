import { AdoptApplication, AdoptPet, PetType, PetGender, AdoptStatus, generateId } from '../model/PetModels';
import { StorageManager } from '../model/StorageManager';
import { AuthManager } from '../model/AuthManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton, BounceCard, BounceEmptyState } from '../components/BounceComponents';
import { CloudSyncService } from '../service/CloudSyncService';

const CLOUD_SYNC_INTERVAL_MS: number = 2000;

@Component
export struct PetAdoptPage {
  @State adoptPets: AdoptPet[] = [];
  @State applications: AdoptApplication[] = [];
  @State selectedTab: number = 0;
  @State showApplyForm: boolean = false;
  @State selectedPetIndex: number = -1;
  @State applicantName: string = '';
  @State applicantPhone: string = '';
  @State applicantAddress: string = '';
  @State applyReason: string = '';
  @State selectedPetName: string = '';
  @StorageLink('petDataVersion') petDataVersion: number = 0;

  private storageManager: StorageManager = StorageManager.getInstance();
  private authManager: AuthManager = AuthManager.getInstance();
  private cloudSyncService: CloudSyncService = CloudSyncService.getInstance();
  private tabLabels: string[] = ['领养列表', '我的申请'];
  private cloudSyncTimer: number = -1;
  private isCloudSyncing: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storageManager.init(getContext(this));
    this.applications = await this.storageManager.getApplications();
    await this.loadAdoptPets();
    await this.refreshCloudData();
    this.startCloudSyncTimer();
  }

  aboutToDisappear(): void {
    this.stopCloudSyncTimer();
  }

  async loadAdoptPets(): Promise<void> {
    let savedPets: AdoptPet[] = await this.storageManager.getAdoptPets();
    if (savedPets.length === 0) {
      savedPets = [
        {
          id: generateId(), name: '小橘', type: 'cat' as PetType, age: '2岁',
          gender: 'male' as PetGender, health: '健康，已绝育已驱虫',
          description: '性格温顺，喜欢粘人', image: '\uD83D\uDC08',
          status: '未领养' as AdoptStatus,
          updatedAt: Date.now(),
          deleted: false
        },
        {
          id: generateId(), name: '豆豆', type: 'dog' as PetType, age: '1岁',
          gender: 'female' as PetGender, health: '健康，已疫苗已驱虫',
          description: '活泼可爱，喜欢玩耍', image: '\uD83D\uDC15',
          status: '未领养' as AdoptStatus,
          updatedAt: Date.now() + 1,
          deleted: false
        },
        {
          id: generateId(), name: '小白', type: 'dog' as PetType, age: '3岁',
          gender: 'male' as PetGender, health: '健康，已绝育已驱虫',
          description: '温柔友善，适合家庭', image: '\uD83D\uDC36',
          status: '未领养' as AdoptStatus,
          updatedAt: Date.now() + 2,
          deleted: false
        }
      ];
      await this.storageManager.saveAdoptPets(savedPets);
    }
    this.adoptPets = savedPets;
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
      const localApplications: AdoptApplication[] =
        this.cloudSyncService.normalizeLocalItems(await this.storageManager.getApplications());
      const localAdoptPets: AdoptPet[] =
        this.cloudSyncService.normalizeLocalItems(await this.storageManager.getAdoptPets());
      const mergedApplications: AdoptApplication[] =
        await this.cloudSyncService.syncCollection(account, 'applications', localApplications);
      const mergedAdoptPets: AdoptPet[] =
        await this.cloudSyncService.syncCollection(account, 'adoptPets', localAdoptPets);
      await this.storageManager.saveApplications(mergedApplications);
      await this.storageManager.saveAdoptPets(mergedAdoptPets);
      this.applications = mergedApplications;
      this.adoptPets = mergedAdoptPets;
    } finally {
      this.isCloudSyncing = false;
    }
  }

  async pushApplicationsToCloud(): Promise<void> {
    const account: string = await this.authManager.getAccount();
    if (account.length === 0) {
      return;
    }
    await this.cloudSyncService.pushCollection(account, 'applications', this.applications);
  }

  getSelectedPet(): AdoptPet | null {
    if (this.selectedPetIndex >= 0 && this.selectedPetIndex < this.adoptPets.length) {
      return this.adoptPets[this.selectedPetIndex];
    }
    return null;
  }

  getPetIcon(type: PetType): string {
    if (type === 'cat') { return '\uD83D\uDC08'; }
    if (type === 'dog') { return '\uD83D\uDC15'; }
    return '\uD83D\uDC31';
  }

  getStatusColor(status: AdoptStatus): string {
    if (status === '未领养') { return '#4CAF50'; }
    if (status === '申请中') { return '#FFB74D'; }
    return '#8A8A8A';
  }

  async submitApplication(): Promise<void> {
    if (this.applicantName.length === 0) { ToastUtils.show('请输入姓名'); return; }
    if (this.applicantPhone.length === 0) { ToastUtils.show('请输入手机号'); return; }
    if (this.applyReason.length === 0) { ToastUtils.show('请输入申请理由'); return; }

    const selectedPet = this.getSelectedPet();
    const application: AdoptApplication = new AdoptApplication();
    application.id = generateId();
    application.petId = selectedPet !== null ? selectedPet.id : '';
    application.applicantName = this.applicantName;
    application.applicantPhone = this.applicantPhone;
    application.applicantAddress = this.applicantAddress;
    application.reason = this.applyReason;
    application.status = '待审核';
    application.applyDate = new Date().toISOString().split('T')[0];
    application.auditDate = '';
    application.updatedAt = Date.now();
    application.deleted = false;
    this.applications.push(application);
    await this.storageManager.saveApplications(this.applications);
    await this.pushApplicationsToCloud();
    this.showApplyForm = false;
    this.resetForm();
    ToastUtils.showSuccess('申请已提交');
  }

  resetForm(): void {
    this.applicantName = '';
    this.applicantPhone = '';
    this.applicantAddress = '';
    this.applyReason = '';
    this.selectedPetIndex = -1;
  }

  @Builder
  TabSelector() {
    Row({ space: 0 }) {
      ForEach(this.tabLabels, (label: string, idx: number) => {
        Text(label)
          .fontSize(13)
          .fontWeight(this.selectedTab === idx ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.selectedTab === idx ? ColorConstants.PRIMARY : ColorConstants.TEXT_SECONDARY)
          .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          .backgroundColor(this.selectedTab === idx ? '#FFF0F5' : 'transparent')
          .borderRadius(16)
          .onClick(() => { this.selectedTab = idx; })
      }, (label: string, idx: number) => 'atab_' + idx.toString())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 8 })
  }

  @Builder
  AdoptCard(pet: AdoptPet, index: number) {
    BounceCard({
      customWidth: '100%',
      customPadding: 14,
      customRadius: 16,
      onAction: () => {
        ToastUtils.show(pet.name + ': ' + pet.description);
      }
    }) {
      Row({ space: 14 }) {
        Column() {
          Text(this.getPetIcon(pet.type))
            .fontSize(32)
            .textAlign(TextAlign.Center)
        }
        .width(64)
        .height(64)
        .borderRadius(16)
        .backgroundColor(ColorConstants.SECONDARY_BG)
        .justifyContent(FlexAlign.Center)

        Column({ space: 4 }) {
          Row() {
            Text(pet.name)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
            Blank()
            Text(pet.status)
              .fontSize(11)
              .fontColor(this.getStatusColor(pet.status))
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(pet.status === '未领养' ? '#E8F5E9' : '#FFF3E0')
              .borderRadius(6)
          }
          .width('100%')

          Text(pet.age + ' · ' + (pet.gender === 'male' ? '公' : '母') + ' · ' + pet.health)
            .fontSize(12)
            .fontColor(ColorConstants.TEXT_SECONDARY)
            .maxLines(1)

          Text(pet.description)
            .fontSize(12)
            .fontColor(ColorConstants.TEXT_TERTIARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })

          Row({ space: 10 }) {
            BounceButton({
              text: '查看详情',
              bgColor: '#F0F0F0',
              textColor: ColorConstants.TEXT_PRIMARY,
              customWidth: '48%',
              customHeight: 36,
              customRadius: 10,
              fontSize: 13,
              onAction: () => {
                ToastUtils.show(pet.name + ': ' + pet.description);
              }
            })
            BounceButton({
              text: '申请领养',
              bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
              customWidth: '48%',
              customHeight: 36,
              customRadius: 10,
              fontSize: 13,
              onAction: () => {
                this.selectedPetIndex = index;
                this.selectedPetName = pet.name;
                this.showApplyForm = true;
              }
            })
          }
          .width('100%')
          .margin({ top: 4 })
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
  }

  @Builder
  ApplyForm() {
    Column() {
      Column({ space: 14 }) {
        Text('申请领养 ' + this.selectedPetName)
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)

        TextInput({ placeholder: '您的姓名', text: this.applicantName })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16 })
          .onChange((value: string) => { this.applicantName = value; })

        TextInput({ placeholder: '手机号码', text: this.applicantPhone })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16 })
          .type(InputType.PhoneNumber)
          .onChange((value: string) => { this.applicantPhone = value; })

        TextInput({ placeholder: '家庭住址', text: this.applicantAddress })
          .width('100%').height(48)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16 })
          .onChange((value: string) => { this.applicantAddress = value; })

        TextInput({ placeholder: '申请理由', text: this.applyReason })
          .width('100%').height(72)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12).padding({ left: 16, top: 12 })
          .onChange((value: string) => { this.applyReason = value; })

        Row({ space: 12 }) {
          BounceButton({
            text: '取消', bgColor: '#F0F0F0', textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.showApplyForm = false; this.resetForm(); }
          })
          BounceButton({
            text: '提交申请', bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '48%', customHeight: 44, customRadius: 12,
            onAction: () => { this.submitApplication(); }
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
          Text('领养中心')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width('100%').height(52).padding({ left: 20, right: 16 })

        this.TabSelector()

        if (this.selectedTab === 0) {
          List({ space: 10 }) {
            ForEach(this.adoptPets, (pet: AdoptPet, index: number) => {
              ListItem() {
                this.AdoptCard(pet, index)
              }
            }, (pet: AdoptPet, index: number) => 'adopt_' + pet.id)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })
          .layoutWeight(1)
        } else {
          if (this.applications.length === 0) {
            BounceEmptyState({
              icon: '\uD83D\uDCC4',
              title: '暂无申请记录',
              subtitle: '快去领养一只可爱的宠物吧'
            })
            .layoutWeight(1)
          } else {
            List({ space: 8 }) {
              ForEach(this.applications, (app: AdoptApplication) => {
                ListItem() {
                  BounceCard({ customWidth: '100%', customPadding: 14, customRadius: 14 }) {
                    Column({ space: 6 }) {
                      Row() {
                        Text('申请编号: ' + app.id.substring(0, 8))
                          .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
                        Blank()
                        Text(app.status).fontSize(12).fontWeight(FontWeight.Medium)
                          .fontColor(app.status === '待审核' ? '#FFB74D' : app.status === '通过' ? '#4CAF50' : '#FF6B6B')
                          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                          .backgroundColor(app.status === '待审核' ? '#FFF3E0' : app.status === '通过' ? '#E8F5E9' : '#FFEBEE')
                          .borderRadius(6)
                      }
                      .width('100%')
                      Text('申请人: ' + app.applicantName).fontSize(14).fontColor(ColorConstants.TEXT_PRIMARY)
                      Text(app.reason).fontSize(12).fontColor(ColorConstants.TEXT_SECONDARY).maxLines(2)
                      Text(app.applyDate).fontSize(11).fontColor(ColorConstants.TEXT_TERTIARY)
                    }
                    .width('100%')
                  }
                }
              }, (app: AdoptApplication) => 'app_' + app.id)
            }
            .width('100%').padding({ left: 16, right: 16 }).layoutWeight(1)
          }
        }
      }
      .width('100%').height('100%')

      if (this.showApplyForm) { this.ApplyForm() }
    }
    .width('100%').height('100%')
  }
}
