import router from '@ohos.router';
import { AuthManager } from '../model/AuthManager';
import { StorageManager } from '../model/StorageManager';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { BounceButton } from '../components/BounceComponents';
import { LineIcon, LineIconButton, LineIconName } from '../components/LineIcons';
import { PetProfilePage } from './PetProfilePage';
import { PetHealthPage } from './PetHealthPage';
import { PetBehaviorPage } from './PetBehaviorPage';
import { PetAdoptPage } from './PetAdoptPage';
import { CompanionHomePage } from './CompanionHomePage';

@Entry
@Component
struct Index {
  @State currentIndex: number = 0;
  @State showLogoutDialog: boolean = false;
  @State account: string = '';
  @State curBp: string = 'compact';
  @StorageLink('petDataVersion') petDataVersion: number = 0;

  private authManager: AuthManager = AuthManager.getInstance();
  private storageManager: StorageManager = StorageManager.getInstance();
  private tabLabels: string[] = ['首页', '健康', '行为', '领养', '伙伴'];
  private tabIcons: LineIconName[] = ['home', 'navHealth', 'navBehavior', 'adopt', 'companion'];
  private readonly selectedTabBg: string = ColorConstants.BUTTON_PRIMARY;

  private selectedTabIcon(iconName: LineIconName): Resource {
    switch (iconName) {
      case 'home': return $r('app.media.px_home_white');
      case 'navHealth': return $r('app.media.px_nav_health_white');
      case 'navBehavior': return $r('app.media.px_nav_behavior_white');
      case 'adopt': return $r('app.media.px_adopt_white');
      case 'companion': return $r('app.media.px_companion_white');
      default: return $r('app.media.px_home_white');
    }
  }

  async aboutToAppear(): Promise<void> {
    try {
      AppStorage.setOrCreate('petDataVersion', 0);
      await this.authManager.init(getContext(this));
      await this.storageManager.init(getContext(this));
      const isLoggedIn: boolean = await this.authManager.isLoggedIn();
      if (!isLoggedIn) {
        router.replaceUrl({ url: 'pages/LoginPage' });
        return;
      }
      this.account = await this.authManager.getAccount();
    } catch (err) {
      console.error('Index init failed:', JSON.stringify(err));
    }
  }

  handleLogout(): void {
    try {
      this.authManager.logout();
      this.showLogoutDialog = false;
      ToastUtils.showSuccess('已退出登录');
      router.replaceUrl({ url: 'pages/LoginPage' });
    } catch (err) {
      console.error('Logout failed:', JSON.stringify(err));
    }
  }

  private updateBreakpoint(width: number): void {
    if (width >= 840) {
      this.curBp = 'expanded';
    } else if (width >= 600) {
      this.curBp = 'medium';
    } else {
      this.curBp = 'compact';
    }
  }

  @Builder
  TopBar() {
    Row() {
      Row({ space: 8 }) {
        LineIcon({ name: 'pet', iconSize: 18, color: ColorConstants.TEXT_PRIMARY })
        Text('宠物管家')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)
      }
      Blank()
      LineIconButton({
        iconName: 'redoWhite',
        bgColor: ColorConstants.BUTTON_PRIMARY,
        textColor: '#FFFFFF',
        customWidth: '40vp',
        customHeight: 40,
        customRadius: 14,
        iconSize: 16,
        onAction: () => { this.showLogoutDialog = true; }
      })
    }
    .width('100%')
    .height(56)
    .padding({ left: 20, right: 16 })
    .backgroundColor(ColorConstants.CARD_BACKGROUND)
    .border({ width: { bottom: 1 }, color: '#EEF0F3' })
  }

  @Builder
  TabItemBuilder(index: number, label: string, iconName: LineIconName) {
    Column({ space: 5 }) {
      if (this.currentIndex === index) {
        Column({ space: 4 }) {
          Image(this.selectedTabIcon(iconName))
            .width(15)
            .height(15)
            .objectFit(ImageFit.Contain)
          Text(label)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .width(48)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.selectedTabBg)
        .borderRadius(18)
      } else {
        Column({ space: 4 }) {
          LineIcon({
            name: iconName,
            iconSize: 15,
            color: ColorConstants.TEXT_PRIMARY
          })
          Text(label)
            .fontSize(11)
            .fontWeight(FontWeight.Normal)
            .fontColor(ColorConstants.TEXT_PRIMARY)
        }
        .width(48)
        .height(42)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height(68)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  LogoutDialog() {
    Column() {
      Column({ space: 20 }) {
        Text('确认退出登录')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(ColorConstants.TEXT_PRIMARY)
        Text('退出后需要重新登录')
          .fontSize(14)
          .fontColor(ColorConstants.TEXT_SECONDARY)
        Row({ space: 12 }) {
          BounceButton({
            text: '取消',
            bgColor: '#F0F0F0',
            textColor: ColorConstants.TEXT_SECONDARY,
            customWidth: '45%',
            customHeight: 44,
            customRadius: 8,
            fontSize: 14,
            fontWeight: FontWeight.Medium,
            onAction: () => { this.showLogoutDialog = false; }
          })
          BounceButton({
            text: '退出',
            bgColor: ColorConstants.ERROR,
            textColor: '#FFFFFF',
            customWidth: '45%',
            customHeight: 44,
            customRadius: 8,
            fontSize: 14,
            fontWeight: FontWeight.Medium,
            onAction: () => { this.handleLogout(); }
          })
        }
        .width('100%')
      }
      .width('80%')
      .padding(28)
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .borderRadius(12)
      .shadow({ radius: 20, color: '#26000000', offsetX: 0, offsetY: 8 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Stack() {
      Column() {
        this.TopBar()
        Tabs({ barPosition: BarPosition.End, index: this.currentIndex }) {
          TabContent() { PetProfilePage({ layoutMode: this.curBp }) }
          .tabBar(this.TabItemBuilder(0, this.tabLabels[0], this.tabIcons[0]))
          TabContent() { PetHealthPage() }
          .tabBar(this.TabItemBuilder(1, this.tabLabels[1], this.tabIcons[1]))
          TabContent() { PetBehaviorPage() }
          .tabBar(this.TabItemBuilder(2, this.tabLabels[2], this.tabIcons[2]))
          TabContent() { PetAdoptPage() }
          .tabBar(this.TabItemBuilder(3, this.tabLabels[3], this.tabIcons[3]))
          TabContent() { CompanionHomePage() }
          .tabBar(this.TabItemBuilder(4, this.tabLabels[4], this.tabIcons[4]))
        }
        .width('100%')
        .layoutWeight(1)
        .barMode(BarMode.Fixed)
        .scrollable(true)
        .animationDuration(300)
        .onChange((index: number) => { this.currentIndex = index; })
        .shadow({ radius: 10, color: '#0F000000', offsetX: 0, offsetY: -2 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(ColorConstants.BACKGROUND)
      if (this.showLogoutDialog) { this.LogoutDialog() }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const width: number = Number(newArea.width);
      if (width > 0) {
        this.updateBreakpoint(width);
      }
    })
  }
}
