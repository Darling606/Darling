import router from '@ohos.router';
import { AuthManager } from '../model/AuthManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton } from '../components/BounceComponents';
import { LineIcon } from '../components/LineIcons';

@Entry
@Component
struct RegisterPage {
  private authManager: AuthManager = AuthManager.getInstance();
  @State account: string = '';
  @State password: string = '';
  @State confirmPassword: string = '';
  @State petName: string = '';
  @State petType: string = '';
  @State isPasswordVisible: boolean = false;

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
  }

  async handleRegister(): Promise<void> {
    if (this.account.length === 0) { ToastUtils.show('请输入账号'); return; }
    if (this.password.length === 0) { ToastUtils.show('请输入密码'); return; }
    if (this.password.length < 4) { ToastUtils.show('密码长度不能少于4位'); return; }
    if (this.password !== this.confirmPassword) { ToastUtils.show('两次密码输入不一致'); return; }
    if (this.petName.length === 0) { ToastUtils.show('请输入宠物名字'); return; }

    try {
      const result = await this.authManager.register(this.account, this.password);
      if (result.success) {
        ToastUtils.showSuccess('注册成功，请登录');
        setTimeout(() => {
          try { router.back(); } catch (err) { console.error('Navigate failed'); }
        }, 1500);
      } else {
        ToastUtils.showError(result.message);
      }
    } catch (err) {
      ToastUtils.showError('注册失败，请重试');
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          Row() {
            Text('\u2190 返回')
              .fontSize(15)
              .fontColor(ColorConstants.PRIMARY)
              .onClick(() => {
                try { router.back(); } catch (err) { console.error('Navigate failed'); }
              })
          }
          .width('100%')
          .padding({ left: 20, top: 16 })

          Column({ space: 8 }) {
            Text('创建账号')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
            Text('注册后即可开始管理您的宠物')
              .fontSize(14)
              .fontColor(ColorConstants.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 16 })

          Column({ space: 14 }) {
            Text('账号信息')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorConstants.TEXT_PRIMARY)
              .alignSelf(ItemAlign.Start)

            TextInput({ placeholder: '请输入账号', text: this.account })
              .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
              .padding({ left: 16, right: 16 }).fontSize(15)
              .onChange((value: string) => { this.account = value; })

            Row() {
              TextInput({ placeholder: '请输入密码', text: this.password })
                .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
                .height(50).layoutWeight(1).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                .padding({ left: 16 }).fontSize(15)
                .onChange((value: string) => { this.password = value; })
              LineIcon({
                name: this.isPasswordVisible ? 'eyeOff' : 'eye',
                iconSize: 18,
                color: ColorConstants.TEXT_TERTIARY
              })
                .padding({ left: 12, right: 12 })
                .onClick(() => { this.isPasswordVisible = !this.isPasswordVisible; })
            }
            .width('100%')

            TextInput({ placeholder: '请确认密码', text: this.confirmPassword })
              .type(InputType.Password)
              .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
              .padding({ left: 16, right: 16 }).fontSize(15)
              .onChange((value: string) => { this.confirmPassword = value; })
          }
          .width('100%')
          .padding({ left: 28, right: 28 })

          Column({ space: 14 }) {
            Text('宠物信息')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(ColorConstants.TEXT_PRIMARY)
              .alignSelf(ItemAlign.Start)

            TextInput({ placeholder: '请输入宠物名字', text: this.petName })
              .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
              .padding({ left: 16, right: 16 }).fontSize(15)
              .onChange((value: string) => { this.petName = value; })

            Row({ space: 10 }) {
              BounceButton({
                text: '猫',
                iconName: 'cat',
                bgColor: this.petType === 'cat' ? ColorConstants.PRIMARY : '#F0F0F0',
                textColor: this.petType === 'cat' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
                customWidth: '31%', customHeight: 42, customRadius: 12,
                fontSize: 14,
                onAction: () => { this.petType = 'cat'; }
              })
              BounceButton({
                text: '狗',
                iconName: 'dog',
                bgColor: this.petType === 'dog' ? ColorConstants.PRIMARY : '#F0F0F0',
                textColor: this.petType === 'dog' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
                customWidth: '31%', customHeight: 42, customRadius: 12,
                fontSize: 14,
                onAction: () => { this.petType = 'dog'; }
              })
              BounceButton({
                text: '其他',
                iconName: 'pet',
                bgColor: this.petType === 'other' ? ColorConstants.PRIMARY : '#F0F0F0',
                textColor: this.petType === 'other' ? '#FFF' : ColorConstants.TEXT_SECONDARY,
                customWidth: '31%', customHeight: 42, customRadius: 12,
                fontSize: 14,
                onAction: () => { this.petType = 'other'; }
              })
            }
            .width('100%')
          }
          .width('100%')
          .padding({ left: 28, right: 28 })

          BounceButton({
            text: '注册',
            bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '85%',
            customHeight: 50,
            customRadius: 12,
            fontSize: 16,
            fontWeight: FontWeight.Medium,
            onAction: () => { this.handleRegister(); }
          })
          .margin({ top: 12, bottom: 32 })
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorConstants.BACKGROUND)
  }
}
