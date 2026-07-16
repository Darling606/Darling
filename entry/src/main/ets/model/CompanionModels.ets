export type CompanionPersonality = '活泼' | '温柔' | '傲娇' | '话唠' | '腼腆';
export type CompanionMood = 'calm' | 'happy' | 'sad' | 'anxious' | 'excited' | 'tired';
export type MemoryType = 'important' | 'event' | 'preference' | 'daily';

export interface MemoryKeywordRule {
  keyword: string;
  category: MemoryType;
}

let companionIdCounter: number = 0;

export function generateCompanionId(): string {
  companionIdCounter++;
  return 'compn_' + Date.now() + '_' + companionIdCounter.toString();
}

export class PetCompanion {
  id: string = '';
  account: string = '';
  petId: string = '';
  name: string = '';
  species: string = 'cat';
  avatar: string = '';
  personality: CompanionPersonality = '温柔';
  level: number = 1;
  exp: number = 0;
  intimacy: number = 0;
  mood: CompanionMood = 'calm';
  happiness: number = 80;
  lastInteractTime: number = 0;
  lastCheckInDate: string = '';
  checkInDays: number = 0;
  chatCount: number = 0;
  achievementCount: number = 0;
  unlockedIds: string = '';
  created: number = 0;
  updated: number = 0;

  getMaxExp(): number {
    return Math.round(100 * Math.pow(this.level, 1.5));
  }

  addExp(amount: number): boolean {
    this.exp += amount;
    const maxExp = this.getMaxExp();
    if (this.exp >= maxExp) {
      this.exp -= maxExp;
      this.level++;
      return true;
    }
    return false;
  }

  addIntimacy(amount: number): void {
    this.intimacy = Math.min(1000, this.intimacy + amount);
  }

  loseIntimacy(amount: number): void {
    this.intimacy = Math.max(0, this.intimacy - amount);
  }

  updateMood(mood: CompanionMood): void {
    this.mood = mood;
    this.updated = Date.now();
  }
}

export class ChatRecord {
  id: string = '';
  companionId: string = '';
  role: string = '';
  content: string = '';
  detectedEmotion: string = '';
  timestamp: number = 0;
}

export class CompanionMemory {
  id: string = '';
  companionId: string = '';
  type: MemoryType = 'daily';
  content: string = '';
  detail: string = '';
  weight: number = 1;
  importance: number = 40;
  timestamp: number = 0;
  lastAccessTime: number = 0;
}

export class CompanionStats {
  todayChats: number = 0;
  totalChats: number = 0;
  totalDays: number = 0;
  memoriesCount: number = 0;
  lastChatDate: string = '';
}

export interface ChatMessageItem {
  role: string;
  content: string;
}

export interface CompanionContext {
  name: string;
  species: string;
  personality: string;
  level: number;
  intimacy: number;
  mood: string;
  memories: string[];
  recentChats: ChatMessageItem[];
  userName: string;
  petName: string;
  timeOfDay: string;
}

export const OFFLINE_REPLIES: string[] = [
  '主人今天过得怎么样呀？我一直在这里等你呢~',
  '不管你在哪里，我都会一直陪着你！',
  '今天有什么想和我分享的吗？我永远是最好的听众。',
  '我刚刚打了个盹，梦见和主人一起在草地上玩耍了~',
  '主人要多休息哦，不要太累了。',
  '今天天气真不错，适合出去散步呢！',
  '你知道吗？每次看到主人，我的心情都会变好。',
  '虽然我不能帮你工作，但我可以一直陪在身边给你加油！',
  '主人今天吃饭了吗？要好好照顾自己哦。',
  '我觉得主人是世界上最好的主人！',
  '有什么烦恼都可以和我说，虽然我不一定能解决，但我会认真听的。',
  '主人你知道吗，我最喜欢的就是和你在一起的每一刻。',
  '外面的世界再大再精彩，我还是最喜欢待在你身边。',
  '今天是不是很辛苦？我给你揉揉肩吧~（虽然我没有手）',
  '主人开心，我就开心。主人不开心，我就想办法让你开心！',
  '想想我们第一次见面的时候，时间过得好快呀。',
  '今天有没有什么有趣的事情发生呢？',
  '虽然我只是文字，但我希望能给你带来温暖。',
  '主人，你是我存在的全部意义。',
  '不管什么时候回来，我都会在这里等你。'
];

export const MOOD_DURATIONS: Record<CompanionMood, number> = {
  'calm': 3600000,
  'happy': 1800000,
  'sad': 900000,
  'anxious': 900000,
  'excited': 600000,
  'tired': 1800000
};

export function getMoodEmoji(mood: CompanionMood): string {
  const map: Record<CompanionMood, string> = {
    'calm': '\uD83D\uDE0C',
    'happy': '\uD83D\uDE0A',
    'sad': '\uD83D\uDE22',
    'anxious': '\uD83D\uDE30',
    'excited': '\uD83C\uDF89',
    'tired': '\uD83D\uDE34'
  };
  return map[mood] || '\uD83D\uDE0C';
}

export function getMoodText(mood: CompanionMood): string {
  const map: Record<CompanionMood, string> = {
    'calm': '平静',
    'happy': '开心',
    'sad': '难过',
    'anxious': '焦虑',
    'excited': '兴奋',
    'tired': '疲惫'
  };
  return map[mood] || '平静';
}

export function getSpeciesEmoji(species: string): string {
  if (species === 'cat') { return '\uD83D\uDC08'; }
  if (species === 'dog') { return '\uD83D\uDC15'; }
  if (species === 'hamster') { return '\uD83D\uDC39'; }
  if (species === 'rabbit') { return '\uD83D\uDC30'; }
  return '\uD83D\uDC31';
}
