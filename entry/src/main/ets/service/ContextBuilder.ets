import { PetCompanion, ChatRecord, CompanionMemory } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { CompanionPrompt, PromptContext } from '../prompt/CompanionPrompt';

export interface AIContext {
  systemPrompt: string;
  memories: string[];
  recentChats: ChatRecord[];
  currentMessage: string;
  companionInfo: PromptContext;
  emotionHint: string;
  detectedEmotion: string;
}

export class ContextBuilder {
  private static instance: ContextBuilder;
  private storage: CompanionStorage;

  private constructor() {
    this.storage = CompanionStorage.getInstance();
  }

  static getInstance(): ContextBuilder {
    if (!ContextBuilder.instance) {
      ContextBuilder.instance = new ContextBuilder();
    }
    return ContextBuilder.instance;
  }

  async build(companionId: string, companion: PetCompanion, message: string): Promise<AIContext> {
    const recentChats: ChatRecord[] = await this.storage.getChatHistory(companionId, 5);
    const importantMemories: CompanionMemory[] = await this.storage.getImportantMemories(companionId, 5);

    const memoryTexts: string[] = [];
    for (let i = 0; i < importantMemories.length; i++) {
      memoryTexts.push(importantMemories[i].content);
    }

    const hour = new Date().getHours();
    let timeOfDay = '白天';
    if (hour < 6) { timeOfDay = '凌晨'; }
    else if (hour < 9) { timeOfDay = '早上'; }
    else if (hour < 12) { timeOfDay = '上午'; }
    else if (hour < 14) { timeOfDay = '中午'; }
    else if (hour < 18) { timeOfDay = '下午'; }
    else if (hour < 22) { timeOfDay = '晚上'; }
    else { timeOfDay = '深夜'; }

    const promptContext: PromptContext = {
      name: companion.name,
      species: companion.species,
      personality: companion.personality,
      level: companion.level,
      intimacy: companion.intimacy,
      mood: companion.mood,
      timeOfDay: timeOfDay,
      memories: memoryTexts
    };

    const systemPrompt: string = CompanionPrompt.build(promptContext);

    return {
      systemPrompt: systemPrompt,
      memories: memoryTexts,
      recentChats: recentChats,
      currentMessage: message,
      companionInfo: promptContext,
      emotionHint: '',
      detectedEmotion: ''
    };
  }

  async buildSystemPrompt(companion: PetCompanion): Promise<string> {
    const importantMemories: CompanionMemory[] = await this.storage.getImportantMemories(companion.id, 5);

    const memoryTexts: string[] = [];
    for (let i = 0; i < importantMemories.length; i++) {
      memoryTexts.push(importantMemories[i].content);
    }

    const hour = new Date().getHours();
    let timeOfDay = '白天';
    if (hour < 6) { timeOfDay = '凌晨'; }
    else if (hour < 9) { timeOfDay = '早上'; }
    else if (hour < 12) { timeOfDay = '上午'; }
    else if (hour < 14) { timeOfDay = '中午'; }
    else if (hour < 18) { timeOfDay = '下午'; }
    else if (hour < 22) { timeOfDay = '晚上'; }
    else { timeOfDay = '深夜'; }

    const promptContext: PromptContext = {
      name: companion.name,
      species: companion.species,
      personality: companion.personality,
      level: companion.level,
      intimacy: companion.intimacy,
      mood: companion.mood,
      timeOfDay: timeOfDay,
      memories: memoryTexts
    };

    return CompanionPrompt.build(promptContext);
  }
}
