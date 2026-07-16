import { CompanionMemory, MemoryType, MemoryKeywordRule, ChatRecord, CompanionContext, ChatMessageItem, generateCompanionId } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';

const MEMORY_KEYWORDS: MemoryKeywordRule[] = [
  { keyword: '喜欢', category: 'preference' },
  { keyword: '最爱', category: 'preference' },
  { keyword: '讨厌', category: 'preference' },
  { keyword: '正在', category: 'event' },
  { keyword: '项目', category: 'event' },
  { keyword: '工作', category: 'event' },
  { keyword: '加班', category: 'event' },
  { keyword: '梦想', category: 'important' },
  { keyword: '计划', category: 'event' },
  { keyword: '养了', category: 'important' },
  { keyword: '生日', category: 'important' },
  { keyword: '第一次', category: 'important' },
  { keyword: '重要', category: 'important' },
  { keyword: '每天', category: 'preference' },
  { keyword: '总是', category: 'preference' },
  { keyword: '希望', category: 'important' },
  { keyword: '决定', category: 'event' },
  { keyword: '开始', category: 'event' }
];

export class MemoryService {
  private static instance: MemoryService;
  private storage: CompanionStorage;

  private constructor() {
    this.storage = CompanionStorage.getInstance();
  }

  static getInstance(): MemoryService {
    if (!MemoryService.instance) {
      MemoryService.instance = new MemoryService();
    }
    return MemoryService.instance;
  }

  private calculateImportance(category: MemoryType, weight: number): number {
    const base: number = category === 'important' ? 60 : category === 'preference' ? 50 : 40;
    const adjusted: number = base + weight * 3;
    const clamped: number = Math.min(100, Math.max(10, adjusted));
    return clamped;
  }

  extractMemory(message: string, companionId: string): CompanionMemory | null {
    let matchedKeyword: string = '';
    let matchedCategory: MemoryType = 'daily';

    for (let i = 0; i < MEMORY_KEYWORDS.length; i++) {
      if (message.indexOf(MEMORY_KEYWORDS[i].keyword) !== -1) {
        matchedKeyword = MEMORY_KEYWORDS[i].keyword;
        matchedCategory = MEMORY_KEYWORDS[i].category;
        break;
      }
    }

    if (matchedKeyword.length === 0) {
      return null;
    }

    const keywordIndex = message.indexOf(matchedKeyword);
    const start = Math.max(0, keywordIndex - 8);
    const end = Math.min(message.length, keywordIndex + matchedKeyword.length + 20);
    const content = message.substring(start, end).trim();

    const memory = new CompanionMemory();
    memory.id = generateCompanionId();
    memory.companionId = companionId;
    memory.type = matchedCategory;
    memory.content = content;
    memory.detail = '关键词: ' + matchedKeyword;
    memory.weight = matchedCategory === 'important' ? 8 : matchedCategory === 'preference' ? 6 : 4;
    memory.importance = this.calculateImportance(matchedCategory, memory.weight);
    memory.timestamp = Date.now();
    memory.lastAccessTime = Date.now();

    return memory;
  }

  async extractAndSave(message: string, companionId: string): Promise<void> {
    const memory = this.extractMemory(message, companionId);
    if (memory !== null) {
      await this.saveMemory(memory);
    }
  }

  async saveMemory(memory: CompanionMemory): Promise<void> {
    await this.storage.saveMemory(memory);
  }

  async getImportantMemories(companionId: string, limit: number): Promise<CompanionMemory[]> {
    return this.storage.getImportantMemories(companionId, limit);
  }

  async getAllMemories(companionId: string): Promise<CompanionMemory[]> {
    return this.storage.getAllMemories(companionId);
  }

  async deleteMemory(memoryId: string): Promise<void> {
    await this.storage.deleteMemory(memoryId);
  }

  async updateMemory(memory: CompanionMemory): Promise<void> {
    memory.lastAccessTime = Date.now();
    await this.storage.updateMemory(memory);
  }

  async buildContext(companionId: string, companionName: string, userName: string): Promise<CompanionContext> {
    const chatHistory: ChatRecord[] = await this.storage.getChatHistory(companionId, 10);
    const importantMemories: CompanionMemory[] = await this.getImportantMemories(companionId, 5);

    const chatItems: ChatMessageItem[] = [];
    for (let i = 0; i < chatHistory.length; i++) {
      const item: ChatMessageItem = { role: chatHistory[i].role, content: chatHistory[i].content };
      chatItems.push(item);
    }

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

    return {
      name: companionName,
      species: 'cat',
      personality: '温柔',
      level: 1,
      intimacy: 0,
      mood: 'calm',
      memories: memoryTexts,
      recentChats: chatItems,
      userName: userName,
      petName: '',
      timeOfDay: timeOfDay
    };
  }
}
