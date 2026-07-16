import { PetCompanion } from '../model/CompanionModels';
import { AppEventBus } from '../common/AppEventBus';

export interface Achievement {
  id: string;
  title: string;
  description: string;
  icon: string;
  unlocked: boolean;
  unlockedTime: number;
}

const ACHIEVEMENT_DEFS: Achievement[] = [
  {
    id: 'FIRST_CHAT', title: '初次对话', description: '完成第一次聊天',
    icon: '\uD83D\uDCAC', unlocked: false, unlockedTime: 0
  },
  {
    id: 'CHAT_100', title: '话痨达人', description: '累计聊天100次',
    icon: '\uD83D\uDCAD', unlocked: false, unlockedTime: 0
  },
  {
    id: 'CHAT_500', title: '无话不谈', description: '累计聊天500次',
    icon: '\uD83D\uDDE3', unlocked: false, unlockedTime: 0
  },
  {
    id: 'LEVEL_5', title: '小有所成', description: '达到5级',
    icon: '\u2B50', unlocked: false, unlockedTime: 0
  },
  {
    id: 'LEVEL_10', title: '成长之星', description: '达到10级',
    icon: '\uD83C\uDF1F', unlocked: false, unlockedTime: 0
  },
  {
    id: 'INTIMACY_100', title: '亲密伙伴', description: '亲密度达到100',
    icon: '\uD83D\uDC95', unlocked: false, unlockedTime: 0
  },
  {
    id: 'INTIMACY_500', title: '形影不离', description: '亲密度达到500',
    icon: '\uD83C\uDFE0', unlocked: false, unlockedTime: 0
  },
  {
    id: 'MEMORY_10', title: '记忆萌芽', description: '形成10条记忆',
    icon: '\uD83E\uDDE0', unlocked: false, unlockedTime: 0
  },
  {
    id: 'MEMORY_50', title: '珍贵回忆', description: '形成50条记忆',
    icon: '\uD83D\uDCDA', unlocked: false, unlockedTime: 0
  }
];

export class AchievementService {
  static getUnlockedKeys(companion: PetCompanion): string[] {
    const unlocked: string[] = [];

    if (companion.chatCount >= 1) { unlocked.push('FIRST_CHAT'); }
    if (companion.chatCount >= 100) { unlocked.push('CHAT_100'); }
    if (companion.chatCount >= 500) { unlocked.push('CHAT_500'); }
    if (companion.level >= 5) { unlocked.push('LEVEL_5'); }
    if (companion.level >= 10) { unlocked.push('LEVEL_10'); }
    if (companion.intimacy >= 100) { unlocked.push('INTIMACY_100'); }
    if (companion.intimacy >= 500) { unlocked.push('INTIMACY_500'); }
    if (companion.achievementCount >= 10) { unlocked.push('MEMORY_10'); }
    if (companion.achievementCount >= 50) { unlocked.push('MEMORY_50'); }

    return unlocked;
  }

  static checkAchievements(companion: PetCompanion): Achievement[] {
    const existingIds: string[] = companion.unlockedIds.length > 0
      ? companion.unlockedIds.split(',') : [];
    const unlockedKeys: string[] = AchievementService.getUnlockedKeys(companion);
    const newAchievements: Achievement[] = [];
    const now: number = Date.now();

    for (let i = 0; i < unlockedKeys.length; i++) {
      if (existingIds.indexOf(unlockedKeys[i]) === -1) {
        existingIds.push(unlockedKeys[i]);

        let title: string = '';
        let description: string = '';
        let icon: string = '';
        for (let j = 0; j < ACHIEVEMENT_DEFS.length; j++) {
          if (ACHIEVEMENT_DEFS[j].id === unlockedKeys[i]) {
            title = ACHIEVEMENT_DEFS[j].title;
            description = ACHIEVEMENT_DEFS[j].description;
            icon = ACHIEVEMENT_DEFS[j].icon;
            break;
          }
        }

        const achievement: Achievement = {
          id: unlockedKeys[i],
          title: title,
          description: description,
          icon: icon,
          unlocked: true,
          unlockedTime: now
        };
        newAchievements.push(achievement);
        AppEventBus.emit('ACHIEVEMENT_UNLOCKED', achievement);
      }
    }

    if (newAchievements.length > 0) {
      companion.unlockedIds = existingIds.join(',');
      companion.achievementCount = existingIds.length;
    }

    return newAchievements;
  }

  static getUnlockedCount(companion: PetCompanion): number {
    if (companion.unlockedIds.length === 0) { return 0; }
    return companion.unlockedIds.split(',').length;
  }

  static getAllAchievements(companion: PetCompanion): Achievement[] {
    const result: Achievement[] = [];
    const ids: string[] = companion.unlockedIds.length > 0
      ? companion.unlockedIds.split(',') : [];

    for (let i = 0; i < ACHIEVEMENT_DEFS.length; i++) {
      const isUnlocked: boolean = ids.indexOf(ACHIEVEMENT_DEFS[i].id) !== -1;
      const achievement: Achievement = {
        id: ACHIEVEMENT_DEFS[i].id,
        title: ACHIEVEMENT_DEFS[i].title,
        description: ACHIEVEMENT_DEFS[i].description,
        icon: ACHIEVEMENT_DEFS[i].icon,
        unlocked: isUnlocked,
        unlockedTime: isUnlocked ? 0 : 0
      };
      result.push(achievement);
    }
    return result;
  }
}
