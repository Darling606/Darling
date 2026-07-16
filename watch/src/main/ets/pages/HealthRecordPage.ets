import { router } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';
import { WatchHealthRecord, COLORS } from '../model/WatchDataModels';

@Entry
@Component
struct HealthRecordPage {
  @State weight: string = '';
  @State temperature: string = '';
  @State notes: string = '';
  @State petId: string = '';
  @State isSaving: boolean = false;

  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['petId']) {
      this.petId = params['petId'];
    } else {
      this.loadDefaultPet();
    }
    
    // 设置健康记录回调
    this.dataManager.onHealthRecordChanged = (record: WatchHealthRecord) => {
      // 接收到手机端同步的健康记录
      console.info(`Health record synced from phone: ${record.id}`);
    };
  }

  aboutToDisappear(): void {
    this.dataManager.onHealthRecordChanged = null;
  }

  async loadDefaultPet(): Promise<void> {
    const pets = await this.dataManager.getAllPetInfo();
    if (pets.length > 0) {
      this.petId = pets[0].id;
    }
  }

  async saveRecord(): Promise<void> {
    if (!this.weight && !this.temperature) {
      return;
    }

    this.isSaving = true;

    const record = new WatchHealthRecord();
    record.id = `health_${Date.now()}`;
    record.petId = this.petId;
    record.timestamp = Date.now();
    record.weight = parseFloat(this.weight) || 0;
    record.temperature = parseFloat(this.temperature) || 0;
    record.notes = this.notes;
    record.synced = false;

    await this.dataManager.saveHealthRecord(record);

    this.isSaving = false;
    this.weight = '';
    this.temperature = '';
    this.notes = '';

    router.back();
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(20)
          .fontColor(COLORS.primary)
          .onClick(() => {
            try {
    try {
      router.back();
    } catch (err) {
      console.error('Navigate back failed:', JSON.stringify(err));
    }
            } catch (err) {
              console.error('Navigate back failed:', JSON.stringify(err));
            }
          })
        Text('健康记录')
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

      Column() {
        Text('体重 (kg)')
          .fontSize(14)
          .fontColor(COLORS.textSecondary)
          .width('100%')
          .margin({ bottom: 8 })

        TextInput({ placeholder: '输入体重', text: this.weight })
          .width('100%')
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FFF5F8')
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.weight = value;
          })

        Text('体温 (°C)')
          .fontSize(14)
          .fontColor(COLORS.textSecondary)
          .width('100%')
          .margin({ top: 16, bottom: 8 })

        TextInput({ placeholder: '输入体温', text: this.temperature })
          .width('100%')
          .height(44)
          .borderRadius(22)
          .backgroundColor('#FFF5F8')
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => {
            this.temperature = value;
          })

        Text('备注')
          .fontSize(14)
          .fontColor(COLORS.textSecondary)
          .width('100%')
          .margin({ top: 16, bottom: 8 })

        TextInput({ placeholder: '添加备注...', text: this.notes })
          .width('100%')
          .height(80)
          .borderRadius(16)
          .backgroundColor('#FFF5F8')
          .padding({ left: 16, right: 16, top: 12 })
          .onChange((value: string) => {
            this.notes = value;
          })
      }
      .width('100%')
      .backgroundColor(COLORS.card)
      .borderRadius(16)
      .padding(16)
      .margin({ left: 16, right: 16, top: 16 })

      Button(this.isSaving ? '保存中...' : '一键保存')
        .width('80%')
        .height(44)
        .borderRadius(22)
        .backgroundColor(COLORS.primary)
        .fontColor('#FFFFFF')
        .margin({ top: 24 })
        .enabled(!this.isSaving && (this.weight !== '' || this.temperature !== ''))
        .onClick(() => {
          this.saveRecord();
        })

      Text('保存后将自动同步到手机')
        .fontSize(12)
        .fontColor(COLORS.textHint)
        .margin({ top: 12 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.background)
  }
}
