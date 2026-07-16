import { PetCompanion, ChatRecord, ChatMessageItem, CompanionContext, OFFLINE_REPLIES, generateCompanionId, CompanionMood } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { MemoryService } from './MemoryService';
import { ContextBuilder } from './ContextBuilder';
import { AIService } from './AIService';
import { EmotionService, EmotionAnalysis, EmotionType } from './EmotionService';
import { CompanionStatusService } from './CompanionStatusService';
import { AppEventBus } from '../common/AppEventBus';



export class ChatService {
  private static instance: ChatService;
  private storage: CompanionStorage;
  private lastReplyIndex: number = 0;

  private constructor() {
    this.storage = CompanionStorage.getInstance();
  }

  static getInstance(): ChatService {
    if (!ChatService.instance) {
      ChatService.instance = new ChatService();
    }
    return ChatService.instance;
  }

  private getOfflineReply(): string {
    this.lastReplyIndex = (this.lastReplyIndex + 1) % OFFLINE_REPLIES.length;
    const baseReply = OFFLINE_REPLIES[this.lastReplyIndex];
    return baseReply;
  }

  private detectMood(message: string): CompanionMood {
    const happyWords = ['开心', '高兴', '哈哈', '喜欢', '好棒', '太好了', '爱', '嘻嘻'];
    const sadWords = ['难过', '伤心', '哭', '不开心', '失望', '痛苦', '难受'];
    const anxiousWords = ['担心', '害怕', '紧张', '焦虑', '压力', '怎么办'];

    for (let i = 0; i < happyWords.length; i++) {
      if (message.indexOf(happyWords[i]) !== -1) { return 'happy'; }
    }
    for (let i = 0; i < sadWords.length; i++) {
      if (message.indexOf(sadWords[i]) !== -1) { return 'sad'; }
    }
    for (let i = 0; i < anxiousWords.length; i++) {
      if (message.indexOf(anxiousWords[i]) !== -1) { return 'anxious'; }
    }
    return 'calm';
  }

  private validateMood(input: string): CompanionMood {
    const validMoods: CompanionMood[] = ['calm', 'happy', 'sad', 'anxious', 'excited', 'tired'];
    for (let i = 0; i < validMoods.length; i++) {
      if (input === validMoods[i]) { return validMoods[i]; }
    }
    return 'calm';
  }

  async sendMessage(
    companion: PetCompanion,
    message: string,
    onToken: (token: string) => void,
    onMood: (mood: CompanionMood) => void,
    onComplete: () => void
  ): Promise<void> {
    const storage = this.storage;
    if (!storage.isReady()) {
      onComplete();
      return;
    }

    const userRecord = new ChatRecord();
    userRecord.id = generateCompanionId();
    userRecord.companionId = companion.id;
    userRecord.role = 'user';
    userRecord.content = message;
    userRecord.timestamp = Date.now();

    const emotionResult = EmotionService.analyze(message);
    userRecord.detectedEmotion = EmotionType[emotionResult.emotion];

    await storage.saveChat(userRecord);

    try {
      await MemoryService.getInstance().extractAndSave(message, companion.id);
    } catch (err) {
      console.error('Memory extraction failed:', JSON.stringify(err));
    }

    const detectedMood = this.detectMood(message);
    companion.updateMood(detectedMood);
    await storage.saveCompanion(companion);

    let reply: string;
    let finalMood: CompanionMood = detectedMood;
    try {
      const ctx = await ContextBuilder.getInstance().build(companion.id, companion, message);
      ctx.emotionHint = emotionResult.emotionHint;
      ctx.detectedEmotion = userRecord.detectedEmotion;
      const aiResponse = await AIService.getInstance().sendMessage(ctx, message);
      reply = aiResponse.content;
      if (emotionResult.emotion === EmotionType.ANGRY) {
        reply = '先别生气了，奶糖抱抱你~ 🫂 ' + reply;
      }
      finalMood = this.validateMood(aiResponse.emotion);
    } catch (err) {
      reply = this.getOfflineReply();
      console.error('AI call failed, using offline reply:', JSON.stringify(err));
    }

    onMood(finalMood);
    const chars: string[] = [];
    for (let i = 0; i < reply.length; i++) {
      chars.push(reply.charAt(i));
    }

    let charIndex: number = 0;
    const timer = setInterval(() => {
      if (charIndex < chars.length) {
        onToken(chars[charIndex]);
        charIndex++;
      } else {
        clearInterval(timer);
        this.finishMessage(companion, reply, emotionResult, onComplete);
      }
    }, 40);
  }

  private async finishMessage(companion: PetCompanion, reply: string, emotionResult: EmotionAnalysis, onComplete: () => void): Promise<void> {
    const assistantRecord = new ChatRecord();
    assistantRecord.id = generateCompanionId();
    assistantRecord.companionId = companion.id;
    assistantRecord.role = 'assistant';
    assistantRecord.content = reply;
    assistantRecord.timestamp = Date.now();
    await this.storage.saveChat(assistantRecord);

    await CompanionStatusService.gainMessageExp(companion);
    await CompanionStatusService.gainIntimacy(companion, 1);
    await CompanionStatusService.updateHappinessFromEmotion(companion, emotionResult.emotion);
    await CompanionStatusService.touchInteraction(companion);

    const latest = await this.storage.getCompanionById(companion.id);
    if (latest !== null) {
      AppEventBus.emit('COMPANION_STATUS_CHANGED', latest);
    }

    onComplete();
  }

  async getChatHistory(companionId: string, limit: number): Promise<ChatRecord[]> {
    return this.storage.getChatHistory(companionId, limit);
  }

  async buildContext(companion: PetCompanion, account: string, petName: string): Promise<CompanionContext> {
    const memories = await this.storage.getMemories(companion.id, 5);
    const recentChats = await this.storage.getChatHistory(companion.id, 6);
    const hour = new Date().getHours();
    let timeOfDay = '白天';
    if (hour < 6) { timeOfDay = '凌晨'; }
    else if (hour < 9) { timeOfDay = '早上'; }
    else if (hour < 12) { timeOfDay = '上午'; }
    else if (hour < 14) { timeOfDay = '中午'; }
    else if (hour < 18) { timeOfDay = '下午'; }
    else if (hour < 22) { timeOfDay = '晚上'; }
    else { timeOfDay = '深夜'; }

    const chatItems: ChatMessageItem[] = [];
    for (let i = 0; i < recentChats.length; i++) {
      const item: ChatMessageItem = { role: recentChats[i].role, content: recentChats[i].content };
      chatItems.push(item);
    }

    return {
      name: companion.name,
      species: companion.species,
      personality: companion.personality,
      level: companion.level,
      intimacy: companion.intimacy,
      mood: companion.mood,
      memories: memories.map(m => m.content),
      recentChats: chatItems,
      userName: account,
      petName: petName,
      timeOfDay: timeOfDay
    };
  }
}
