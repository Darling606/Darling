import router from '@ohos.router';
import { AuthManager } from '../model/AuthManager';
import { StorageManager } from '../model/StorageManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton } from '../components/BounceComponents';
import { LineIcon } from '../components/LineIcons';

@Entry
@Component
struct LoginPage {
  @State account: string = '';
  @State password: string = '';
  @State isPasswordVisible: boolean = false;
  @State isLoading: boolean = false;
  @State rememberAccount: boolean = false;

  private authManager: AuthManager = AuthManager.getInstance();
  private storageManager: StorageManager = StorageManager.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.authManager.init(getContext(this));
    await this.storageManager.init(getContext(this));
    const remember: boolean = await this.authManager.getRememberAccount();
    if (remember) {
      const savedAccount: string = await this.authManager.getSavedAccount();
      if (savedAccount) {
        this.account = savedAccount;
        this.rememberAccount = true;
      }
    }
  }

  async handleLogin(): Promise<void> {
    if (this.account.length === 0) { ToastUtils.show('请输入账号'); return; }
    if (this.password.length === 0) { ToastUtils.show('请输入密码'); return; }
    this.isLoading = true;
    try {
      const result = await this.authManager.login(this.account, this.password);
      if (result.success) {
        if (this.rememberAccount) {
          await this.authManager.setRememberAccount(true);
          await this.authManager.saveAccount(this.account);
        } else {
          await this.authManager.setRememberAccount(false);
          await this.authManager.saveAccount('');
        }
        ToastUtils.showSuccess('登录成功');
        router.replaceUrl({ url: 'pages/Index' });
      } else {
        ToastUtils.showError(result.message);
      }
    } catch (err) {
      ToastUtils.showError('登录失败，请重试');
    } finally {
      this.isLoading = false;
    }
  }

  build() {
    Column() {
      Column({ space: 24 }) {
        Column({ space: 8 }) {
          LineIcon({ name: 'pet', iconSize: 48, color: ColorConstants.PRIMARY })
          Text('宠物管家')
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorConstants.TEXT_PRIMARY)
          Text('记录爱宠的每一个瞬间')
            .fontSize(14)
            .fontColor(ColorConstants.TEXT_SECONDARY)
        }
        .alignItems(HorizontalAlign.Center)
        .margin({ top: 60, bottom: 16 })

        Column({ space: 14 }) {
          TextInput({ placeholder: '请输入账号', text: this.account })
            .height(50)
            .backgroundColor(ColorConstants.SECONDARY_BG)
            .borderRadius(8)
            .padding({ left: 16, right: 16 })
            .fontSize(15)
            .onChange((value: string) => { this.account = value; })

          Row() {
            TextInput({ placeholder: '请输入密码', text: this.password })
              .type(this.isPasswordVisible ? InputType.Normal : InputType.Password)
              .showPasswordIcon(false)
              .height(50)
              .layoutWeight(1)
              .backgroundColor('transparent')
              .padding({ left: 0, right: 4 })
              .fontSize(15)
              .onChange((value: string) => { this.password = value; })
            LineIcon({
              name: this.isPasswordVisible ? 'eyeOff' : 'eye',
              iconSize: 18,
              color: ColorConstants.TEXT_TERTIARY
            })
            .padding({ left: 0, right: 0 })
            .onClick(() => { this.isPasswordVisible = !this.isPasswordVisible; })
          }
          .width('100%')
          .height(50)
          .backgroundColor(ColorConstants.SECONDARY_BG)
          .borderRadius(8)
          .padding({ left: 16, right: 12 })

          Row() {
            Row({ space: 6 }) {
              Toggle({ type: ToggleType.Checkbox, isOn: this.rememberAccount })
                .selectedColor(ColorConstants.BUTTON_PRIMARY)
                .width(18).height(18)
                .onChange((value: boolean) => { this.rememberAccount = value; })
              Text('记住账号')
                .fontSize(13)
                .fontColor(ColorConstants.TEXT_SECONDARY)
            }
            Blank()
            Text('忘记密码?')
              .fontSize(13)
              .fontColor(ColorConstants.PRIMARY)
              .onClick(() => {
                try { router.pushUrl({ url: 'pages/ForgotPasswordPage' }); }
                catch (err) { console.error('Navigate failed'); }
              })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 28, right: 28 })

        BounceButton({
          text: this.isLoading ? '登录中...' : '登录',
          bgColor: ColorConstants.BUTTON_PRIMARY, textColor: ColorConstants.BUTTON_PRIMARY_TEXT,
          customWidth: '85%',
          customHeight: 50,
          customRadius: 8,
          fontSize: 16,
          fontWeight: FontWeight.Medium,
          onAction: () => {
            if (!this.isLoading) { this.handleLogin(); }
          }
        })
        .margin({ top: 8 })

        Row({ space: 6 }) {
          Text('还没有账号?')
            .fontSize(14)
            .fontColor(ColorConstants.TEXT_SECONDARY)
          Text('立即注册')
            .fontSize(14)
            .fontColor(ColorConstants.PRIMARY)
            .fontWeight(FontWeight.Medium)
            .onClick(() => {
              try { router.pushUrl({ url: 'pages/RegisterPage' }); }
              catch (err) { console.error('Navigate failed'); }
            })
        }
        .margin({ top: 24 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(ColorConstants.BACKGROUND)
    .justifyContent(FlexAlign.Center)
  }
}
