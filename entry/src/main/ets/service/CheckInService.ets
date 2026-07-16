import { PetCompanion } from '../model/CompanionModels';
import { CompanionStorage } from '../model/CompanionStorage';

const CHECKIN_REWARDS: number[] = [10, 15, 20, 25, 30, 35, 50];

export class CheckInService {
  private static getTodayStr(): string {
    return new Date().toISOString().split('T')[0];
  }

  private static getYesterdayStr(): string {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    return d.toISOString().split('T')[0];
  }

  static checkToday(companion: PetCompanion): boolean {
    const today: string = CheckInService.getTodayStr();
    return companion.lastCheckInDate !== today;
  }

  static async performCheckIn(companion: PetCompanion): Promise<number> {
    const today: string = CheckInService.getTodayStr();

    if (companion.lastCheckInDate === today) {
      return 0;
    }

    const yesterday: string = CheckInService.getYesterdayStr();
    if (companion.lastCheckInDate === yesterday) {
      companion.checkInDays++;
    } else {
      companion.checkInDays = 1;
    }

    if (companion.checkInDays > 7) {
      companion.checkInDays = 1;
    }

    const rewardIndex: number = companion.checkInDays - 1;
    const rewardExp: number = CHECKIN_REWARDS[rewardIndex];

    companion.lastCheckInDate = today;
    companion.addExp(rewardExp);
    companion.updated = Date.now();
    await CompanionStorage.getInstance().saveCompanion(companion);

    return rewardExp;
  }

  static getStreakText(days: number): string {
    return '\u5DF2\u8FDE\u7EED\u7B7E\u5230 ' + days.toString() + ' \u5929';
  }
}
