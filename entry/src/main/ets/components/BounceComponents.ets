import { LineIcon, LineIconName } from './LineIcons';
import { ColorConstants } from '../model/ColorConstants';

@Component
export struct BounceButton {
  @State animScale: number = 1;
  @Prop text: string = '';
  @Prop icon: string = '';
  @Prop iconName: LineIconName | '' = '';
  @Prop bgColor: string = ColorConstants.BUTTON_PRIMARY;
  @Prop textColor: string = ColorConstants.BUTTON_PRIMARY_TEXT;
  @Prop customWidth: string = '100%';
  @Prop customHeight: number = 50;
  @Prop customRadius: number = 12;
  @Prop fontSize: number = 15;
  @Prop fontWeight: FontWeight = FontWeight.Medium;
  @Prop outlined: boolean = false;
  onAction: () => void = () => {};

  build() {
    if (this.iconName !== '') {
      Row({ space: this.text.length > 0 ? 8 : 0 }) {
        LineIcon({
          name: this.iconName as LineIconName,
          iconSize: this.fontSize + 3,
          color: this.outlined ? this.bgColor : this.textColor
        })
        if (this.text.length > 0) {
          Text(this.text)
            .fontSize(this.fontSize)
            .fontWeight(this.fontWeight)
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
      .border(this.outlined ? { width: 1.5, color: this.bgColor } : { width: 0, color: 'transparent' })
      .shadow({
        radius: 10,
        color: '#120C100D',
        offsetX: 0,
        offsetY: 2
      })
      .scale({ x: this.animScale, y: this.animScale })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.animScale = 0.98;
        } else if (event.type === TouchType.Up) {
          this.animScale = 1.0;
          this.onAction();
        } else if (event.type === TouchType.Cancel) {
          this.animScale = 1.0;
        }
      })
      .animation({
        duration: 150,
        curve: Curve.EaseInOut
      })
    } else {
      Button(this.icon.length > 0 ? this.icon + ' ' + this.text : this.text)
        .width(this.customWidth)
        .height(this.customHeight)
        .backgroundColor(this.outlined ? 'transparent' : this.bgColor)
        .fontColor(this.outlined ? this.bgColor : this.textColor)
        .fontSize(this.fontSize)
        .fontWeight(this.fontWeight)
        .borderRadius(this.customRadius)
        .border(this.outlined ? { width: 1.5, color: this.bgColor } : {})
        .shadow({
          radius: 10,
          color: '#120C100D',
          offsetX: 0,
          offsetY: 2
        })
        .scale({ x: this.animScale, y: this.animScale })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.animScale = 0.98;
          } else if (event.type === TouchType.Up) {
            this.animScale = 1.0;
            this.onAction();
          } else if (event.type === TouchType.Cancel) {
            this.animScale = 1.0;
          }
        })
        .animation({
          duration: 140,
          curve: Curve.EaseInOut
        })
    }
  }
}

@Component
export struct BounceCard {
  @State animScale: number = 1;
  @Prop customWidth: string = '100%';
  @Prop customPadding: number = 16;
  @Prop customRadius: number = 16;
  @Prop bgColor: string = '#FFFFFF';
  onAction: () => void = () => {};
  @BuilderParam content: () => void = this.defaultContent;

  @Builder
  defaultContent() {}

  build() {
    Column() {
      this.content()
    }
    .width(this.customWidth)
    .padding(this.customPadding)
    .backgroundColor(this.bgColor)
    .borderRadius(this.customRadius)
    .shadow({
      radius: 10,
      color: '#120C100D',
      offsetX: 0,
      offsetY: 2
    })
    .scale({ x: this.animScale, y: this.animScale })
    .onTouch((event: TouchEvent) => {
      if (event.type === TouchType.Down) {
        this.animScale = 0.98;
      } else if (event.type === TouchType.Up) {
        this.animScale = 1.0;
        this.onAction();
      } else if (event.type === TouchType.Cancel) {
        this.animScale = 1.0;
      }
    })
    .animation({
      duration: 140,
      curve: Curve.EaseInOut
    })
  }
}

@Component
export struct PressableChip {
  @State animScale: number = 1;
  @Prop text: string = '';
  @Prop selected: boolean = false;
  @Prop selectedBg: string = ColorConstants.BUTTON_PRIMARY;
  @Prop normalBg: string = '#E9EEEA';
  @Prop selectedTextColor: string = ColorConstants.BUTTON_PRIMARY_TEXT;
  @Prop normalTextColor: string = '#6F7671';
  @Prop customHeight: number = 32;
  @Prop customRadius: number = 16;
  @Prop fontSize: number = 13;
  @Prop horizontalPadding: number = 14;
  onAction: () => void = () => {};

  build() {
    Text(this.text)
      .fontSize(this.fontSize)
      .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selected ? this.selectedTextColor : this.normalTextColor)
      .padding({ left: this.horizontalPadding, right: this.horizontalPadding, top: 8, bottom: 8 })
      .height(this.customHeight)
      .backgroundColor(this.selected ? this.selectedBg : this.normalBg)
      .borderRadius(this.customRadius)
      .border({ width: this.selected ? 0 : 1, color: '#D7DDD7' })
      .scale({ x: this.animScale, y: this.animScale })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.animScale = 0.98;
        } else if (event.type === TouchType.Up) {
          this.animScale = 1.0;
          this.onAction();
        } else if (event.type === TouchType.Cancel) {
          this.animScale = 1.0;
        }
      })
      .animation({ duration: 140, curve: Curve.EaseInOut })
  }
}

@Component
export struct BounceEmptyState {
  @Prop icon: string = '';
  @Prop iconName: LineIconName | '' = '';
  @Prop title: string = '';
  @Prop subtitle: string = '';
  @Prop buttonText: string = '';
  onAction: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      if (this.iconName !== '') {
        Column() {
          LineIcon({
            name: this.iconName as LineIconName,
            iconSize: 34,
            color: '#667085'
          })
        }
        .width(72)
        .height(72)
        .borderRadius(12)
        .backgroundColor('#F6F8FB')
        .border({ width: 1, color: '#E7EAF0' })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      } else if (this.icon.length > 0) {
        Text(this.icon)
          .fontSize(48)
          .opacity(0.4)
      }
      Text(this.title)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8A8A8A')
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(13)
          .fontColor('#B0B0B0')
          .maxLines(2)
          .textAlign(TextAlign.Center)
      }
      if (this.buttonText.length > 0) {
        Button(this.buttonText)
          .height(40)
          .padding({ left: 24, right: 24 })
          .backgroundColor(ColorConstants.BUTTON_PRIMARY)
          .fontColor(ColorConstants.BUTTON_PRIMARY_TEXT)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .borderRadius(12)
          .margin({ top: 4 })
          .onClick(() => { this.onAction(); })
          .shadow({
            radius: 10,
            color: '#120C100D',
            offsetX: 0,
            offsetY: 2
          })
      }
    }
    .width('100%')
    .padding({ top: 60, bottom: 60 })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct BounceFab {
  @State animScale: number = 1;
  @Prop icon: string = '+';
  @Prop bgColor: string = ColorConstants.BUTTON_PRIMARY;
  @Prop fabSize: number = 56;
  onAction: () => void = () => {};

  build() {
    Button(this.icon)
      .width(this.fabSize)
      .height(this.fabSize)
      .backgroundColor(this.bgColor)
      .fontColor(ColorConstants.BUTTON_PRIMARY_TEXT)
      .fontSize(24)
      .fontWeight(FontWeight.Normal)
      .borderRadius(this.fabSize / 2)
      .shadow({
        radius: 12,
        color: '#14000000',
        offsetX: 0,
        offsetY: 4
      })
      .scale({ x: this.animScale, y: this.animScale })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Down) {
          this.animScale = 0.94;
        } else if (event.type === TouchType.Up) {
          this.animScale = 1.0;
          this.onAction();
        }
      })
      .animation({
        duration: 150,
        curve: Curve.EaseInOut
      })
  }
}

@Component
export struct BounceBadge {
  @Prop text: string = '';
  @Prop bgColor: string = '#4CAF50';
  @Prop textColor: string = '#FFFFFF';

  build() {
    Text(this.text)
      .fontSize(11)
      .fontColor(this.textColor)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .backgroundColor(this.bgColor)
      .borderRadius(6)
  }
}
