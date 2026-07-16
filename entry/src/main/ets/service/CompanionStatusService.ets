import { PetCompanion } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';
import { EmotionType } from './EmotionService';
import { AchievementService } from './AchievementService';

export class CompanionStatusService {
  private static dailyLoginRewarded: boolean = false;
  private static dailyMemoryRewarded: boolean = false;
  private static lastDate: string = '';

  private static checkNewDay(): void {
    const today: string = new Date().toISOString().split('T')[0];
    if (today !== CompanionStatusService.lastDate) {
      CompanionStatusService.lastDate = today;
      CompanionStatusService.dailyLoginRewarded = false;
      CompanionStatusService.dailyMemoryRewarded = false;
    }
  }

  static async gainLoginExp(companion: PetCompanion): Promise<void> {
    CompanionStatusService.checkNewDay();
    if (CompanionStatusService.dailyLoginRewarded) { return; }
    CompanionStatusService.dailyLoginRewarded = true;
    companion.addExp(10);
    companion.updated = Date.now();
    await CompanionStorage.getInstance().saveCompanion(companion);
  }

  static async gainMessageExp(companion: PetCompanion): Promise<void> {
    companion.addExp(5);
    companion.chatCount++;
    companion.updated = Date.now();
    AchievementService.checkAchievements(companion);
    await CompanionStorage.getInstance().saveCompanion(companion);
  }

  static async gainMemoryExp(companion: PetCompanion): Promise<void> {
    CompanionStatusService.checkNewDay();
    if (CompanionStatusService.dailyMemoryRewarded) { return; }
    CompanionStatusService.dailyMemoryRewarded = true;
    companion.addExp(3);
    companion.updated = Date.now();
    await CompanionStorage.getInstance().saveCompanion(companion);
  }

  static async gainIntimacy(companion: PetCompanion, amount: number): Promise<void> {
    companion.addIntimacy(amount);
    companion.updated = Date.now();
    await CompanionStorage.getInstance().saveCompanion(companion);
  }

  static async updateHappinessFromEmotion(companion: PetCompanion, emotion: EmotionType): Promise<void> {
    const delta: number = CompanionStatusService.getHappinessDelta(emotion);
    if (delta !== 0) {
      companion.happiness = Math.min(100, Math.max(0, companion.happiness + delta));
      companion.updated = Date.now();
      await CompanionStorage.getInstance().saveCompanion(companion);
    }
  }

  private static getHappinessDelta(emotion: EmotionType): number {
    if (emotion === EmotionType.HAPPY) { return 5; }
    if (emotion === EmotionType.SAD) { return -3; }
    if (emotion === EmotionType.ANXIOUS) { return -2; }
    if (emotion === EmotionType.ANGRY) { return -4; }
    if (emotion === EmotionType.TIRED) { return -1; }
    return 0;
  }

  static async touchInteraction(companion: PetCompanion): Promise<void> {
    companion.lastInteractTime = Date.now();
    companion.updated = Date.now();
    await CompanionStorage.getInstance().saveCompanion(companion);
  }
}
