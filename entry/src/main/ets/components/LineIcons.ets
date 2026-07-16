import { PetType } from '../model/PetModels';
import { ColorConstants } from '../model/ColorConstants';

export type LineIconName =
  'home' | 'health' | 'behavior' | 'activity' | 'adopt' | 'companion' |
  'navHealth' | 'navBehavior' |
  'pet' | 'cat' | 'dog' | 'rabbit' | 'calendar' | 'trash' | 'edit' |
  'chat' | 'book' | 'trophy' | 'flame' | 'heart' | 'brain' |
  'eye' | 'eyeOff' | 'logout' | 'plus' | 'dot' | 'list' |
  'food' | 'water' | 'vaccine' | 'mapPin' | 'volume' | 'mic' |
  'stop' | 'star' | 'lock' | 'cake' | 'scale' | 'sparkles' |
  'bell' | 'bot' | 'smile' | 'sad' | 'calm' | 'excited' | 'tired' |
  'redoWhite' | 'healthWhite';

export function getPetIconName(type: PetType | string): LineIconName {
  if (type === 'cat') { return 'cat'; }
  if (type === 'dog') { return 'dog'; }
  if (type === 'rabbit') { return 'rabbit'; }
  return 'pet';
}

export function getMoodIconName(mood: string): LineIconName {
  if (mood === 'happy') { return 'smile'; }
  if (mood === 'sad' || mood === 'anxious') { return 'sad'; }
  if (mood === 'excited') { return 'sparkles'; }
  if (mood === 'tired') { return 'tired'; }
  return 'calm';
}

@Component
export struct LineIcon {
  @Prop name: LineIconName = 'pet';
  @Prop iconSize: number = 20;
  @Prop color: string = ColorConstants.TEXT_PRIMARY;

  private source(): Resource {
    switch (this.name) {
      case 'home': return $r('app.media.px_home');
      case 'health': return $r('app.media.px_health');
      case 'behavior': return $r('app.media.px_behavior');
      case 'activity': return $r('app.media.px_behavior');
      case 'navHealth': return $r('app.media.px_nav_health');
      case 'navBehavior': return $r('app.media.px_nav_behavior');
      case 'adopt': return $r('app.media.px_adopt');
      case 'companion': return $r('app.media.px_companion');
      case 'pet': return $r('app.media.px_cat');
      case 'cat': return $r('app.media.px_cat');
      case 'dog': return $r('app.media.px_dog');
      case 'rabbit': return $r('app.media.ic_rabbit');
      case 'calendar': return $r('app.media.px_calendar');
      case 'trash': return $r('app.media.ic_trash_2');
      case 'edit': return $r('app.media.ic_pencil');
      case 'chat': return $r('app.media.px_chat');
      case 'book': return $r('app.media.px_book');
      case 'trophy': return $r('app.media.px_trophy');
      case 'flame': return $r('app.media.ic_flame');
      case 'heart': return $r('app.media.px_heart');
      case 'brain': return $r('app.media.ic_brain');
      case 'eye': return $r('app.media.ic_eye');
      case 'eyeOff': return $r('app.media.ic_eye_off');
      case 'logout': return $r('app.media.ic_log_out');
      case 'plus': return $r('app.media.px_plus');
      case 'dot': return $r('app.media.ic_circle');
      case 'list': return $r('app.media.px_book');
      case 'food': return $r('app.media.px_food');
      case 'water': return $r('app.media.px_water');
      case 'vaccine': return $r('app.media.px_vaccine');
      case 'mapPin': return $r('app.media.px_map_pin');
      case 'volume': return $r('app.media.ic_volume_2');
      case 'mic': return $r('app.media.ic_mic');
      case 'stop': return $r('app.media.ic_square');
      case 'star': return $r('app.media.px_star');
      case 'lock': return $r('app.media.px_lock');
      case 'cake': return $r('app.media.ic_cake');
      case 'scale': return $r('app.media.px_health');
      case 'sparkles': return $r('app.media.ic_sparkles');
      case 'bell': return $r('app.media.px_trophy');
      case 'bot': return $r('app.media.ic_bot');
      case 'smile': return $r('app.media.px_chat');
      case 'sad': return $r('app.media.ic_frown');
      case 'excited': return $r('app.media.ic_zap');
      case 'tired': return $r('app.media.px_heart');
      case 'calm': return $r('app.media.ic_meh');
      case 'redoWhite': return $r('app.media.px_redo_white');
      case 'healthWhite': return $r('app.media.px_health_white_action');
      default: return $r('app.media.px_cat');
    }
  }

  private usesTemplate(): boolean {
    return this.name !== 'redoWhite' && this.name !== 'healthWhite';
  }

  build() {
    Image(this.source())
      .width(this.iconSize)
      .height(this.iconSize)
      .renderMode(this.usesTemplate() ? ImageRenderMode.Template : ImageRenderMode.Original)
      .fillColor(this.usesTemplate() ? this.color : Color.Transparent)
      .objectFit(ImageFit.Contain)
  }
}

@Component
export struct LineIconButton {
  @State animScale: number = 1;
  @Prop iconName: LineIconName = 'plus';
  @Prop text: string = '';
  @Prop bgColor: string = ColorConstants.BUTTON_PRIMARY;
  @Prop textColor: string = ColorConstants.BUTTON_PRIMARY_TEXT;
  @Prop customWidth: string = '100%';
  @Prop customHeight: number = 44;
  @Prop customRadius: number = 8;
  @Prop iconSize: number = 18;
  @Prop fontSize: number = 14;
  @Prop outlined: boolean = false;
  onAction: () => void = () => {};

  build() {
    Row({ space: this.text.length > 0 ? 8 : 0 }) {
      LineIcon({ name: this.iconName, iconSize: this.iconSize, color: this.outlined ? this.bgColor : this.textColor })
      if (this.text.length > 0) {
        Text(this.text)
          .fontSize(this.fontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.outlined ? this.bgColor : this.textColor)
          .maxLines(1)
      }
    }
    .width(this.customWidth)
    .height(this.customHeight)
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.outlined ? 'transparent' : this.bgColor)
    .borderRadius(this.customRadius)
    .border(this.outlined ? { width: 1, color: this.bgColor } : { width: 0, color: 'transparent' })
    .shadow({
      radius: this.outlined ? 0 : 8,
      color: '#120C100D',
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.animScale, y: this.animScale })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animScale = 0.98;
      } else if (event.type === TouchType.Up) {
        this.animScale = 1;
        this.onAction();
      } else if (event.type === TouchType.Cancel) {
        this.animScale = 1;
      }
    })
    .animation({ duration: 140, curve: Curve.EaseOut })
  }
}

@Component
export struct MinimalPetAvatar {
  @Prop species: string = 'cat';
  @Prop avatarSize: number = 72;
  @Prop bgColor: string = '#F7F8FA';
  @Prop color: string = ColorConstants.TEXT_PRIMARY;
  @Prop radius: number = 8;

  build() {
    Column() {
      LineIcon({
        name: getPetIconName(this.species),
        iconSize: Math.round(this.avatarSize * 0.48),
        color: this.color
      })
    }
    .width(this.avatarSize)
    .height(this.avatarSize)
    .borderRadius(this.radius)
    .backgroundColor(this.bgColor)
    .border({ width: 1, color: '#E7EAF0' })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
