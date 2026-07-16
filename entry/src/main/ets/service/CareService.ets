import { PetCompanion } from '../model/CompanionModels';

export interface CareMessage {
  message: string;
  type: string;
}

export class CareService {
  private static lastCareTimes: Map<string, string> = new Map();

  private static getTodayStr(): string {
    return new Date().toISOString().split('T')[0];
  }

  private static isAlreadyCaredToday(companionId: string): boolean {
    const lastDate = CareService.lastCareTimes.get(companionId);
    if (!lastDate) { return false; }
    const today: string = CareService.getTodayStr();
    return lastDate === today;
  }

  private static markCaredToday(companionId: string): void {
    CareService.lastCareTimes.set(companionId, CareService.getTodayStr());
  }

  static checkCare(companion: PetCompanion): CareMessage | null {
    if (companion.lastInteractTime === 0) { return null; }

    const now: number = Date.now();
    const elapsed: number = now - companion.lastInteractTime;
    const hours: number = elapsed / 3600000;

    if (hours >= 72) {
      if (CareService.isAlreadyCaredToday(companion.id)) { return null; }
      CareService.markCaredToday(companion.id);
      return { message: '最近还好吗？奶糖一直在等你呢~', type: 'worry' };
    }

    if (hours >= 48) {
      if (CareService.isAlreadyCaredToday(companion.id)) { return null; }
      CareService.markCaredToday(companion.id);
      return { message: '好久没见到你啦～奶糖好想你', type: 'concern' };
    }

    if (hours >= 24) {
      if (CareService.isAlreadyCaredToday(companion.id)) { return null; }
      CareService.markCaredToday(companion.id);
      return { message: '奶糖有点想你了～快来聊聊天吧', type: 'gentle' };
    }

    return null;
  }
}
