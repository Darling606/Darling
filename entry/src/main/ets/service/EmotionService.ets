export enum EmotionType {
  ANGRY = 0,
  SAD = 1,
  ANXIOUS = 2,
  TIRED = 3,
  HAPPY = 4,
  CALM = 5
}

export interface EmotionAnalysis {
  emotion: EmotionType;
  confidence: number;
  score: number;
  matchedKeyword: string;
  emotionHint: string;
}

interface EmotionRule {
  type: EmotionType;
  keywords: string[];
  hint: string;
}

const EMOTION_RULES: EmotionRule[] = [
  {
    type: EmotionType.ANGRY,
    keywords: ['生气', '烦死了', '气死我了', '讨厌', '火大', '无语', '想骂人', '忍不了', '破防了', '愤怒', '气死', '烦躁', '恼火'],
    hint: '帮助主人平复情绪，转移话题到轻松的方向'
  },
  {
    type: EmotionType.SAD,
    keywords: ['难过', '伤心', '失落', '哭', '不开心', '失望', '痛苦', '难受', '想哭'],
    hint: '用温柔的语气安慰主人，表达共情和陪伴'
  },
  {
    type: EmotionType.ANXIOUS,
    keywords: ['压力', '紧张', '焦虑', '担心', '害怕', '怎么办', '不安'],
    hint: '安抚主人，告诉主人一切都会好起来，奶糖会一直陪着'
  },
  {
    type: EmotionType.TIRED,
    keywords: ['累', '熬夜', '困', '加班', '疲惫', '辛苦', '好累'],
    hint: '提醒主人注意休息，语气温暖关心，表达心疼'
  },
  {
    type: EmotionType.HAPPY,
    keywords: ['开心', '高兴', '哈哈', '喜欢', '成功', '太好了', '好棒', '快乐', '嘻嘻'],
    hint: '作为主人小伙伴，询问主人开心的事情，并和主人分享快乐'
  }
];

export class EmotionService {
  static analyze(text: string): EmotionAnalysis {
    let bestType: EmotionType = EmotionType.CALM;
    let bestScore: number = 0;
    let bestConfidence: number = 0;
    let matchedKeyword: string = '';

    for (let i = 0; i < EMOTION_RULES.length; i++) {
      const rule = EMOTION_RULES[i];
      let hitCount: number = 0;

      for (let j = 0; j < rule.keywords.length; j++) {
        if (text.indexOf(rule.keywords[j]) !== -1) {
          if (matchedKeyword.length === 0) {
            matchedKeyword = rule.keywords[j];
          }
          hitCount++;
        }
      }

      if (hitCount > 0) {
        const confidence: number = hitCount / rule.keywords.length;
        const score: number = Math.round(confidence * 100);

        if (score > bestScore) {
          bestScore = score;
          bestType = rule.type;
          bestConfidence = confidence;
        }

        if (score === bestScore && rule.type < bestType) {
          bestType = rule.type;
        }
      }
    }

    let emotionHint: string = '';
    if (bestType !== EmotionType.CALM) {
      for (let i = 0; i < EMOTION_RULES.length; i++) {
        if (EMOTION_RULES[i].type === bestType) {
          emotionHint = EMOTION_RULES[i].hint;
          break;
        }
      }
    }

    console.info('[Emotion]', text, EmotionType[bestType], matchedKeyword);

    return {
      emotion: bestType,
      confidence: bestConfidence,
      score: bestScore,
      matchedKeyword: matchedKeyword,
      emotionHint: emotionHint
    };
  }
}
