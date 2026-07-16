import { getMoodText, CompanionMood } from '../model/CompanionModels';
import { ColorConstants } from '../model/ColorConstants';
import { LineIcon, MinimalPetAvatar, getMoodIconName } from './LineIcons';

@Component
export struct CompanionAvatar {
  @Prop species: string = 'cat';
  @Prop mood: CompanionMood = 'calm';
  @Prop avatarSize: number = 120;

  private getMoodAvatarSource(): Resource {
    switch (this.mood) {
      case 'happy':
        return $r('app.media.mood_happy');
      case 'sad':
        return $r('app.media.mood_sad');
      case 'anxious':
        return $r('app.media.mood_anxious');
      case 'excited':
        return $r('app.media.mood_excited');
      case 'tired':
        return $r('app.media.mood_tired');
      case 'calm':
      default:
        return $r('app.media.mood_calm');
    }
  }

  build() {
    Column() {
      Column() {
        Image(this.getMoodAvatarSource())
          .width(this.avatarSize * 0.34)
          .height(this.avatarSize * 0.34)
          .objectFit(ImageFit.Contain)
      }
      .width(this.avatarSize)
      .height(this.avatarSize)
      .borderRadius(18)
      .backgroundColor('#FAFBFC')
      .border({ width: 1, color: '#E7EAF0' })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }
}

@Component
export struct ChatBubble {
  @Prop role: string = 'assistant';
  @Prop content: string = '';
  @Prop timestamp: number = 0;
  @Prop emotion: string = '';

  build() {
    Row() {
      if (this.role === 'assistant') {
        Row({ space: 8 }) {
          MinimalPetAvatar({
            species: 'cat',
            avatarSize: 36,
            bgColor: '#FAFBFC',
            color: ColorConstants.TEXT_PRIMARY,
            radius: 10
          })

          Column({ space: 4 }) {
            Text(this.content)
              .fontSize(15)
              .fontColor('#333333')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor('#F6F8FB')
              .borderRadius({ topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 })

            Text(this.formatTime(this.timestamp))
              .fontSize(11)
              .fontColor('#BBBBBB')
              .padding({ left: 8 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%').padding({ left: 12, right: 60, top: 4, bottom: 4 })
        .justifyContent(FlexAlign.Start)
      } else {
        Row({ space: 8 }) {
          Column({ space: 4 }) {
            Text(this.content)
              .fontSize(15)
              .fontColor('#FFFFFF')
              .padding({ left: 14, right: 14, top: 10, bottom: 10 })
              .backgroundColor('#FF7FAF')
              .borderRadius({ topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })

            Text(this.formatTime(this.timestamp))
              .fontSize(11)
              .fontColor('#BBBBBB')
              .padding({ right: 8 })
              .alignSelf(ItemAlign.End)
          }
          .alignItems(HorizontalAlign.End)
          .layoutWeight(1)
        }
        .width('100%').padding({ left: 60, right: 12, top: 4, bottom: 4 })
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
  }

  private formatTime(ts: number): string {
    if (ts === 0) { return ''; }
    const date = new Date(ts);
    const h = date.getHours().toString().padStart(2, '0');
    const m = date.getMinutes().toString().padStart(2, '0');
    return h + ':' + m;
  }
}

@Component
export struct TypingIndicator {
  @Prop visible: boolean = false;
  @State dotIndex: number = 0;
  private timer: number = -1;

  aboutToAppear(): void {
    if (this.visible) {
      this.timer = setInterval(() => {
        this.dotIndex = (this.dotIndex + 1) % 3;
      }, 300);
    }
  }

  aboutToDisappear(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  build() {
    if (this.visible) {
      Row({ space: 4 }) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#BBBBBB')
          .opacity(this.dotIndex >= 0 ? 1 : 0.3)
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#BBBBBB')
          .opacity(this.dotIndex >= 1 ? 1 : 0.3)
        Column()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor('#BBBBBB')
          .opacity(this.dotIndex >= 2 ? 1 : 0.3)
      }
      .padding({ left: 20, top: 8, bottom: 4 })
    }
  }
}

@Component
export struct LevelRing {
  @Prop level: number = 1;
  @Prop exp: number = 0;
  @Prop maxExp: number = 100;
  @Prop ringSize: number = 80;

  build() {
    Column({ space: 6 }) {
      Stack() {
        Column()
          .width(this.ringSize)
          .height(this.ringSize)
          .backgroundColor('#F0F0F0')
          .borderRadius(this.ringSize / 2)

        Column()
          .width(this.ringSize - 6)
          .height(this.ringSize - 6)
          .backgroundColor('#FFFFFF')
          .borderRadius((this.ringSize - 6) / 2)

        Column({ space: 2 }) {
          Text(this.level.toString())
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(ColorConstants.PRIMARY)
          Text('LV')
            .fontSize(10)
            .fontColor('#AAAAAA')
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width(this.ringSize)
      .height(this.ringSize)

      Text('EXP ' + this.exp.toString() + '/' + this.maxExp.toString())
        .fontSize(11)
        .fontColor('#AAAAAA')
    }
    .alignItems(HorizontalAlign.Center)
  }
}

@Component
export struct MoodLabel {
  @Prop mood: CompanionMood = 'calm';

  build() {
    Row({ space: 6 }) {
      LineIcon({
        name: getMoodIconName(this.mood),
        iconSize: 18,
        color: '#667085'
      })
      Text(getMoodText(this.mood))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#333333')
    }
  }
}
