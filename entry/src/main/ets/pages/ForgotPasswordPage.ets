import router from '@ohos.router';
import { AuthManager } from '../model/AuthManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton } from '../components/BounceComponents';
import { LineIcon } from '../components/LineIcons';

@Entry
@Component
struct ForgotPasswordPage {
  @State account: string = '';
  @State petName: string = '';
  @State petBirthday: string = '';
  @State step: number = 1;
  @State newPassword: string = '';
  @State confirmNewPassword: string = '';
  @State isPasswordVisible: boolean = false;

  private authManager: AuthManager = AuthManager.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
  }

  handleVerify(): void {
    if (this.account.length === 0) { ToastUtils.show('请输入账号'); return; }
    if (this.petName.length === 0) { ToastUtils.show('请输入宠物名字'); return; }
    if (this.petBirthday.length === 0) { ToastUtils.show('请输入宠物生日'); return; }
    this.step = 2;
  }

  async handleResetPassword(): Promise<void> {
    if (this.newPassword.length === 0) { ToastUtils.show('请输入新密码'); return; }
    if (this.newPassword.length < 4) { ToastUtils.show('密码长度不能少于4位'); return; }
    if (this.newPassword !== this.confirmNewPassword) { ToastUtils.show('两次密码输入不一致'); return; }

    try {
      const result = await this.authManager.resetPassword(this.account, this.newPassword);
      if (result.success) {
        ToastUtils.showSuccess('密码重置成功');
        setTimeout(() => {
          try { router.back(); } catch (err) { console.error('Navigate failed'); }
        }, 1500);
      } else {
        ToastUtils.showError(result.message);
      }
    } catch (err) {
      ToastUtils.showError('密码重置失败，请重试');
    }
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 20 }) {
          Row() {
            Text(this.step === 1 ? '\u2190 返回' : '\u2190 上一步')
              .fontSize(15)
              .fontColor(ColorConstants.PRIMARY)
              .onClick(() => {
                if (this.step === 1) {
                  try { router.back(); } catch (err) { console.error('Navigate failed'); }
                } else {
                  this.step = 1;
                }
              })
          }
          .width('100%')
          .padding({ left: 20, top: 16 })

          Column({ space: 8 }) {
            Text(this.step === 1 ? '找回密码' : '重置密码')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(ColorConstants.TEXT_PRIMARY)
            Text(this.step === 1 ? '输入账号和宠物信息验证身份' : '请设置新密码')
              .fontSize(14)
              .fontColor(ColorConstants.TEXT_SECONDARY)
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 16 })

          if (this.step === 1) {
            Column({ space: 14 }) {
              TextInput({ placeholder: '请输入账号', text: this.account })
                .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                .padding({ left: 16, right: 16 }).fontSize(15)
                .onChange((value: string) => { this.account = value; })

              TextInput({ placeholder: '请输入宠物名字', text: this.petName })
                .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                .padding({ left: 16, right: 16 }).fontSize(15)
                .onChange((value: string) => { this.petName = value; })

              TextInput({ placeholder: '请输入宠物生日 (如 2023-01-01)', text: this.petBirthday })
                .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                .padding({ left: 16, right: 16 }).fontSize(15)
                .onChange((value: string) => { this.petBirthday = value; })
            }
            .width('100%')
            .padding({ left: 28, right: 28 })
          } else {
            Column({ space: 14 }) {
              Row() {
                TextInput({ placeholder: '请输入新密码', text: this.newPassword })
                  .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
                  .height(50).layoutWeight(1).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                  .padding({ left: 16 }).fontSize(15)
                  .onChange((value: string) => { this.newPassword = value; })
                LineIcon({
                  name: this.isPasswordVisible ? 'eyeOff' : 'eye',
                  iconSize: 18,
                  color: ColorConstants.TEXT_TERTIARY
                })
                  .padding({ left: 12, right: 12 })
                  .onClick(() => { this.isPasswordVisible = !this.isPasswordVisible; })
              }
              .width('100%')

              TextInput({ placeholder: '请确认新密码', text: this.confirmNewPassword })
                .type(InputType.Password)
                .height(50).backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(12)
                .padding({ left: 16, right: 16 }).fontSize(15)
                .onChange((value: string) => { this.confirmNewPassword = value; })
            }
            .width('100%')
            .padding({ left: 28, right: 28 })
          }

          BounceButton({
            text: this.step === 1 ? '验证' : '重置密码',
            bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
            customWidth: '85%',
            customHeight: 50,
            customRadius: 12,
            fontSize: 16,
            fontWeight: FontWeight.Medium,
            onAction: () => {
              if (this.step === 1) { this.handleVerify(); }
              else { this.handleResetPassword(); }
            }
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
