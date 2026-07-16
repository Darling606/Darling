import router from '@ohos.router';
import { PetCompanion, ChatRecord, CompanionMood } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { ChatService } from '../service/ChatService';
import { ColorConstants } from '../model/ColorConstants';
import { ToastUtils } from '../model/AnimationUtils';
import { ChatBubble, TypingIndicator } from '../components/CompanionComponents';
import { LineIcon, getMoodIconName } from '../components/LineIcons';
import { VoiceService, RealtimeResult } from '../service/VoiceService';
import { TTSService } from '../service/TTSService';
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { AIService } from '../service/AIService';
import { BackendConfig } from '../model/BackendConfig';

const BACKEND_URL: string = BackendConfig.BASE_URL;

@Entry
@Component
export struct ChatPage {
  @State companion: PetCompanion | null = null;
  @State chatList: ChatRecord[] = [];
  @State inputText: string = '';
  @State currentMood: CompanionMood = 'calm';
  @State isTyping: boolean = false;
  @State replyText: string = '';
  @State isRecording: boolean = false;
  @State isSpeaking: boolean = false;
  @State recordScale: number = 1.0;

  private storage: CompanionStorage = CompanionStorage.getInstance();
  private chatService: ChatService = ChatService.getInstance();
  private scroller: Scroller = new Scroller();
  private voiceService: VoiceService = VoiceService.getInstance();
  private ttsService: TTSService = TTSService.getInstance();

  async aboutToAppear(): Promise<void> {
    await this.storage.init(getContext(this));
    AIService.getInstance().init(BACKEND_URL);
    this.voiceService.init(BACKEND_URL);
    this.ttsService.init(BACKEND_URL);
    const account = 'default_user';
    this.companion = await this.storage.getCompanion(account);
    if (this.companion === null) {
      ToastUtils.show('请先创建伙伴');
      try { router.back(); } catch (err) { }
      return;
    }
    this.currentMood = this.companion!.mood;
    this.chatList = await this.storage.getChatHistory(this.companion!.id, 50);
    setTimeout(() => {
      this.scrollToListBottom();
    }, 0);
  }

  scrollToBottom(): void {
    this.scroller.scrollEdge(Edge.Bottom);
  }

  private scrollToListBottom(): void {
    if (this.scroller) {
      this.scrollToBottom();
    }
  }

  async toggleRecording(): Promise<void> {
    if (this.isRecording) {
      this.isRecording = false;
      animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
        this.recordScale = 1.0;
      });
      const resultStr: string | null = await this.voiceService.stopRecording();
      if (resultStr === '__MICROPHONE_UNAVAILABLE__') {
        ToastUtils.show('模拟器不支持麦克风，请在真机上测试');
        return;
      }
      if (resultStr === '__AUDIO_TOO_SHORT__') {
        ToastUtils.show('录音时间太短，请说完后再点击停止');
        return;
      }
      if (resultStr !== null && resultStr.length > 0) {
        try {
          const realtime: RealtimeResult = JSON.parse(resultStr) as RealtimeResult;
          if (realtime.success) {
            const userText: string = realtime.text || '';
            if (userText.length > 0) {
              const userMsg = new ChatRecord();
              userMsg.id = 'user_' + Date.now();
              userMsg.companionId = this.companion!.id;
              userMsg.role = 'user';
              userMsg.content = userText;
              userMsg.timestamp = Date.now();
              this.chatList.push(userMsg);
              await this.storage.saveChat(userMsg);
            }

            const replyText: string = realtime.reply || '';
            if (replyText.length > 0) {
              const aiMsg = new ChatRecord();
              aiMsg.id = 'ai_' + Date.now();
              aiMsg.companionId = this.companion!.id;
              aiMsg.role = 'assistant';
              aiMsg.content = replyText;
              aiMsg.timestamp = Date.now();
              this.chatList.push(aiMsg);
              await this.storage.saveChat(aiMsg);
            }

            this.scrollToListBottom();

            if (realtime.audio.length > 0) {
              this.isSpeaking = true;
              this.ttsService.playPcmBase64(
                realtime.audio,
                realtime.audio_sample_rate || 24000,
                () => { this.isSpeaking = true; },
                () => { this.isSpeaking = false; }
              );
            }
          } else {
            if (realtime.errorCode === 'NO_SPEECH') {
              ToastUtils.show('没有听清，请说久一点');
            } else if (realtime.errorCode === 'AUDIO_TOO_SHORT') {
              ToastUtils.show('录音时间太短，请说完后再点击停止');
            } else if (realtime.errorCode === 'INVALID_PCM') {
              ToastUtils.show('录音格式异常，请重试');
            } else if (realtime.errorCode === 'TIMEOUT') {
              ToastUtils.show('语音服务响应超时，请重试');
            } else {
              ToastUtils.show(realtime.message || '语音对话失败，请重试');
            }
          }
        } catch (e) {
          console.error('parse realtime result error:', e);
          ToastUtils.show('语音对话失败，请重试');
        }
      } else {
        ToastUtils.show('语音识别失败，请重试');
      }
    } else {
      try {
        const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
        const result =
          await atManager.requestPermissionsFromUser(getContext(this), ['ohos.permission.MICROPHONE'] as Permissions[]);
        if (result.authResults.length > 0 && result.authResults[0] === 0) {
          await this.voiceService.startRecording(getContext(this));
          this.isRecording = true;
          animateTo({ duration: 300, curve: Curve.EaseOut }, () => {
            this.recordScale = 1.3;
          });
        } else {
          ToastUtils.show('需要麦克风权限才能录音');
        }
      } catch (err) {
        console.error('toggleRecording failed:', err);
        ToastUtils.show('录音启动失败');
      }
    }
  }

  aboutToDisappear(): void {
    this.voiceService.release();
    this.ttsService.release();
  }

  async sendMessage(): Promise<void> {
    const text = this.inputText.trim();
    if (text.length === 0 || this.companion === null || this.isTyping) { return; }

    this.isTyping = true;
    this.replyText = '';
    const companion = this.companion!;

    const userMsg = new ChatRecord();
    userMsg.id = 'user_' + Date.now();
    userMsg.companionId = companion.id;
    userMsg.role = 'user';
    userMsg.content = text;
    userMsg.timestamp = Date.now();
    this.chatList.push(userMsg);
    this.inputText = '';

    await this.chatService.sendMessage(
      companion,
      text,
      (token: string) => {
        this.replyText += token;
        this.scrollToListBottom();
      },
      (mood: CompanionMood) => {
        this.currentMood = mood;
      },
      () => {
        const aiMsg = new ChatRecord();
        aiMsg.id = 'ai_' + Date.now();
        aiMsg.companionId = companion.id;
        aiMsg.role = 'assistant';
        aiMsg.content = this.replyText;
        aiMsg.timestamp = Date.now();
        this.chatList.push(aiMsg);
        this.replyText = '';
        this.isTyping = false;

        this.companion = companion;
        this.scrollToListBottom();
      }
    );
  }

  build() {
    Column() {
      Row() {
        Text('\u2190')
          .fontSize(20).fontColor(ColorConstants.PRIMARY).fontWeight(FontWeight.Normal)
          .padding({ left: 4, right: 12, top: 8, bottom: 8 })
          .onClick(() => { try { router.back(); } catch (err) { } })

        if (this.companion !== null) {
      if (this.isSpeaking) {
        Row({ space: 6 }) {
          LineIcon({ name: 'volume', iconSize: 13, color: ColorConstants.TEXT_TERTIARY })
          Text('\u5976\u7CD6\u6B63\u5728\u8BF4\u8BDD...')
            .fontSize(12).fontColor(ColorConstants.TEXT_TERTIARY)
        }
        .padding({ left: 16, top: 4, bottom: 2 })
      }

          Row({ space: 8 }) {
            Text(this.companion!.name)
              .fontSize(17).fontWeight(FontWeight.Bold).fontColor(ColorConstants.TEXT_PRIMARY)
            LineIcon({ name: getMoodIconName(this.currentMood), iconSize: 16, color: ColorConstants.TEXT_TERTIARY })
          }
          .layoutWeight(1)
        }
      }
      .width('100%').height(52).padding({ left: 16, right: 16 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
      .shadow({ radius: 12, color: ColorConstants.SHADOW_COLOR, offsetX: 0, offsetY: 4 })

      if (this.chatList.length === 0 && !this.isTyping) {
        Column({ space: 12 }) {
          LineIcon({ name: 'pet', iconSize: 48, color: ColorConstants.TEXT_TERTIARY })
            .opacity(0.3)
          Text('开始和你的伙伴聊天吧')
            .fontSize(15).fontColor(ColorConstants.TEXT_TERTIARY)
          Text('我会一直在这里陪着你')
            .fontSize(13).fontColor('#CCCCCC')
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 0, scroller: this.scroller }) {
          ForEach(this.chatList, (record: ChatRecord) => {
            ListItem() {
              ChatBubble({
                role: record.role,
                content: record.content,
                timestamp: record.timestamp
              })
            }
          }, (record: ChatRecord) => 'chat_' + record.id)

          if (this.isTyping && this.replyText.length > 0) {
            ListItem() {
              ChatBubble({
                role: 'assistant',
                content: this.replyText,
                timestamp: Date.now()
              })
            }
          }
        }
        .width('100%').height('100%').layoutWeight(1)
        .onAppear(() => {
          this.scrollToBottom();
        })
      }

      if (this.isTyping) {
        Row() {
          TypingIndicator({ visible: true })
          Blank()
        }
        .width('100%').padding({ left: 16 })
      }

      Row({ space: 8 }) {
        Stack() {
          Circle()
            .width(52).height(52)
            .fill('#33FF4444')
            .scale({ x: this.recordScale, y: this.recordScale })
            .opacity(this.isRecording ? 1 : 0)
            .animation(this.isRecording
              ? { duration: 800, curve: Curve.EaseInOut, iterations: -1 }
              : { duration: 300, curve: Curve.EaseOut })
          Circle()
            .width(44).height(44)
            .fill(this.isRecording ? '#FF4444' : '#F0F0F0')
            .animation({ duration: 200, curve: Curve.EaseOut })
          LineIcon({
            name: this.isRecording ? 'stop' : 'mic',
            iconSize: 20,
            color: this.isRecording ? '#FFFFFF' : ColorConstants.TEXT_TERTIARY
          })
            .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .width(52).height(52)
        .onClick(() => { this.toggleRecording(); })

        TextInput({ placeholder: '说点什么...', text: this.inputText })
          .height(44).layoutWeight(1)
          .backgroundColor(ColorConstants.SECONDARY_BG).borderRadius(22)
          .padding({ left: 18, right: 18 }).fontSize(15)
          .onChange((value: string) => { this.inputText = value; })

        Text('\u2191')
          .fontSize(20).fontWeight(FontWeight.Bold)
          .fontColor(this.inputText.trim().length > 0 ? '#FFFFFF' : ColorConstants.TEXT_TERTIARY)
          .width(40).height(40).textAlign(TextAlign.Center)
          .borderRadius(20)
          .backgroundColor(this.inputText.trim().length > 0 ? ColorConstants.PRIMARY : '#E0E0E0')
          .onClick(() => { this.sendMessage(); })
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor(ColorConstants.CARD_BACKGROUND)
    }
    .width('100%').height('100%')
    .backgroundColor(ColorConstants.BACKGROUND)
  }
}
