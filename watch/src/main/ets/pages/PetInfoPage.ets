import { router } from '@kit.ArkUI';
import { DistributedDataManager } from '../model/DistributedDataManager';
import { WatchPetInfo, COLORS } from '../model/WatchDataModels';

@Entry
@Component
struct PetInfoPage {
  @State pet: WatchPetInfo | null = null;
  @State petId: string = '';

  private dataManager: DistributedDataManager = DistributedDataManager.getInstance();

  async loadPetInfo(): Promise<void> {
    this.pet = await this.dataManager.getPetInfo(this.petId);
  }

  async loadDefaultPet(): Promise<void> {
    const pets = await this.dataManager.getAllPetInfo();
    if (pets.length > 0) {
      this.pet = pets[0];
    }
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params && params['petId']) {
      this.petId = params['petId'];
      this.loadPetInfo();
    } else {
      this.loadDefaultPet();
    }

    this.dataManager.onPetInfoChanged = (pet: WatchPetInfo) => {
      this.pet = pet;
    };
  }

  aboutToDisappear(): void {
    this.dataManager.onPetInfoChanged = null;
  }

  build() {
    Column() {
      Row() {
        Text('<')
          .fontSize(20)
          .fontColor(COLORS.primary)
          .onClick(() => {
            try {
              router.back();
            } catch (err) {
              console.error('Navigate back failed:', JSON.stringify(err));
            }
          })
        Text('宠物详情')
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

      if (this.pet) {
        Column() {
          if (this.pet.avatar) {
            Image(this.pet.avatar)
              .width(100)
              .height(100)
              .borderRadius(50)
          } else {
            Text(this.pet.name.substring(0, 1))
              .fontSize(40)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .textAlign(TextAlign.Center)
              .width(100)
              .height(100)
              .borderRadius(50)
              .backgroundColor(COLORS.primary)
          }

          Text(this.pet.name)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLORS.textPrimary)
            .margin({ top: 12 })

          Text(`${this.pet.type} · ${this.pet.breed}`)
            .fontSize(14)
            .fontColor(COLORS.textSecondary)
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 20 })

        Column() {
          this.InfoRow('品种', this.pet.breed)
          this.InfoRow('性别', this.pet.gender)
          this.InfoRow('生日', this.pet.birthday)
          this.InfoRow('最新体重', `${this.pet.lastWeight}kg`)
          this.InfoRow('最新体温', `${this.pet.lastTemperature}°C`)
        }
        .width('100%')
        .backgroundColor(COLORS.card)
        .borderRadius(16)
        .padding(16)
        .margin({ left: 16, right: 16, top: 20 })
      } else {
        Column() {
          Text('?')
            .fontSize(40)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .textAlign(TextAlign.Center)
            .width(100)
            .height(100)
            .borderRadius(50)
            .backgroundColor(COLORS.primaryLight)

          Text('暂无宠物数据')
            .fontSize(14)
            .fontColor(COLORS.textHint)
            .margin({ top: 12 })

          Text('请在手机端添加宠物')
            .fontSize(12)
            .fontColor(COLORS.textHint)
            .margin({ top: 4 })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 60 })
      }

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLORS.background)
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor(COLORS.textSecondary)
        .width(80)
      Text(value)
        .fontSize(14)
        .fontColor(COLORS.textPrimary)
        .layoutWeight(1)
    }
    .width('100%')
    .height(44)
    .border({ width: { bottom: 1 }, color: '#F0F0F0' })
  }
}
