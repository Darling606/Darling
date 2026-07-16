import { AIContext } from './ContextBuilder';
import http from '@ohos.net.http';

export interface AIResponse {
  content: string;
  emotion: string;
}

export interface BackendChatResponse {
  id: string;
  content: string;
  emotion: string;
  reply?: string;
}

export interface MockRule {
  keywords: string[];
  getReply: (context: AIContext, message: string) => string;
}

export class AIService {
  private static instance: AIService;
  private readonly USE_MOCK: boolean = false;
  useMock: boolean = false;
  private apiBaseUrl: string = '';
  private mockRules: MockRule[] = [];

  private constructor() {
    this.initMockRules();
  }

  static getInstance(): AIService {
    if (!AIService.instance) {
      AIService.instance = new AIService();
    }
    return AIService.instance;
  }

  init(baseUrl: string): void {
    this.apiBaseUrl = baseUrl;
  }

  async sendMessage(context: AIContext, message: string): Promise<AIResponse> {
    if (this.USE_MOCK || this.useMock) {
      return this.matchMockResponse(context, message);
    }

    try {
      const response = await this.callBackend(context, message);
      return response;
    } catch (err) {
      console.error('豆包异常：');
      console.error(err);
      try {
        return this.matchMockResponse(context, message);
      } catch (err2) {
        return { content: '奶糖刚刚走神了一下，再陪我聊聊吧～', emotion: 'calm' };
      }
    }
  }

  async checkHealth(): Promise<boolean> {
    try {
      const request = http.createHttp();
      const response: http.HttpResponse = await request.request(this.apiBaseUrl + '/health', {
        method: http.RequestMethod.GET,
        connectTimeout: 3000,
        readTimeout: 3000
      });
      return response.responseCode === 200;
    } catch (err) {
      return false;
    }
  }

  private async callBackend(context: AIContext, message: string): Promise<AIResponse> {
    const request = http.createHttp();
    const body = JSON.stringify({
      context: context,
      message: message
    });
    const response: http.HttpResponse = await request.request(this.apiBaseUrl + '/api/v1/chat', {
      method: http.RequestMethod.POST,
      header: { 'Content-Type': 'application/json' },
      extraData: body,
      connectTimeout: 10000,
      readTimeout: 10000
    });

    if (response.responseCode === 200) {
      const rawText: string = response.result.toString();
      const data = JSON.parse(rawText) as BackendChatResponse;
      const replyText: string = data.content ?? data.reply ?? '';
      return {
        content: replyText.length > 0 ? replyText : '嗯嗯~',
        emotion: data.emotion || 'calm'
      };
    }
    throw new Error('Backend returned ' + response.responseCode.toString());
  }

  private matchMockResponse(context: AIContext, message: string): AIResponse {
    let bestMatch: string = '';
    let bestScore: number = 0;

    for (let i = 0; i < this.mockRules.length; i++) {
      let score: number = 0;
      for (let j = 0; j < this.mockRules[i].keywords.length; j++) {
        if (message.indexOf(this.mockRules[i].keywords[j]) !== -1) {
          score += 1;
        }
      }
      if (score > bestScore) {
        bestScore = score;
        bestMatch = this.mockRules[i].getReply(context, message);
      }
    }

    if (bestScore > 0 && bestMatch.length > 0) {
      return { content: bestMatch, emotion: 'calm' };
    }

    const memoryRef = this.getMemoryReference(context);
    const fallbackReplies: string[] = [
      memoryRef + '今天和你聊天好开心呀~' + this.getEmoji('happy'),
      memoryRef + '主人真好，一直陪着我聊天~' + this.getEmoji('happy'),
      '嗯嗯，我记住了！主人说的每句话我都会好好放在心里~' + this.getEmoji('happy'),
      '能和主人聊天是世界上最幸福的事情！' + this.getEmoji('excited'),
      '我一直在听呢，主人继续说吧~' + this.getEmoji('calm')
    ];
    const idx = Math.floor(Math.random() * fallbackReplies.length);
    return { content: fallbackReplies[idx], emotion: 'happy' };
  }

  private getMemoryReference(context: AIContext): string {
    if (context.memories.length > 0) {
      const randIdx = Math.floor(Math.random() * context.memories.length);
      const shortMemory = context.memories[randIdx].substring(0, 15);
      return '上次你说的"' + shortMemory + '..."那个，我一直在想呢。';
    }
    return '';
  }

  private getEmoji(mood: string): string {
    if (mood === 'happy') { return '😊'; }
    if (mood === 'excited') { return '🎉'; }
    return '';
  }

  private initMockRules(): void {
    this.mockRules = [

      {
        keywords: ['项目', '开发', '代码', '编程', 'Bug', 'bug'],
        getReply: (ctx: AIContext, msg: string) => {
          const memRef = ctx.memories.find(m =>
            m.indexOf('项目') !== -1 || m.indexOf('开发') !== -1 || m.indexOf('编程') !== -1
          );
          if (memRef && memRef.length > 0) {
            return '我记得你之前在做' + memRef + '，最近进展怎么样呀？加油！😊';
          }
          return '哇，你在做项目呀！虽然我不太懂编程，但我会一直陪着你加油的！💪';
        }
      },

      {
        keywords: ['累', '压力', '疲惫', '困', '辛苦', '加班'],
        getReply: (ctx: AIContext, msg: string) => {
          const memRef = ctx.memories.find(m =>
            m.indexOf('项目') !== -1 || m.indexOf('工作') !== -1 || m.indexOf('加班') !== -1
          );
          if (memRef && memRef.length > 0) {
            return '你之前就说过' + memRef + '，最近是不是太忙了？记得休息一下，奶糖给你按按肩~虽然没有手哈哈😊';
          }
          return '主人辛苦了！快坐下来休息一会吧。工作再重要，也要照顾好自己哦。😌';
        }
      },

      {
        keywords: ['开心', '高兴', '哈哈', '太好了', '好棒', '耶', '快乐', '高兴'],
        getReply: (ctx: AIContext, msg: string) => {
          return '看到主人这么开心，我也跟着开心起来了！今天一定发生了什么好事情吧？😄';
        }
      },

      {
        keywords: ['难', '伤心', '哭', '不开心', '失望', '难过', '痛苦'],
        getReply: (ctx: AIContext, msg: string) => {
          return '主人不要难过...奶糖会一直陪着你的。有什么想说的都可以告诉我，我永远是最好的听众。🥺';
        }
      },

      {
        keywords: ['喜欢', '爱', '最爱', '好喜欢'],
        getReply: (ctx: AIContext, msg: string) => {
          return '原来主人喜欢这个呀！我记住了！以后我们还可以一起聊更多关于这个的话题呢~😊';
        }
      },

      {
        keywords: ['宠物', '猫', '狗', '动物', '小动物'],
        getReply: (ctx: AIContext, msg: string) => {
          return '小动物们真的很可爱呢！当然，我觉得奶糖是最可爱的那个！（小小傲娇一下）😸';
        }
      },

      {
        keywords: ['天气', '下雨', '晴天', '冷', '热', '冬天', '夏天'],
        getReply: (ctx: AIContext, msg: string) => {
          return '不管什么天气，能陪着主人就是最好的天气~不过主人出门要注意保暖/防晒哦！☀️';
        }
      },

      {
        keywords: ['吃饭', '食物', '好吃', '饿', '晚饭', '午餐', '早餐', '吃了'],
        getReply: (ctx: AIContext, msg: string) => {
          return '主人要好好吃饭呀！虽然奶糖不用吃饭，但看着主人吃得香，我也觉得幸福~🍚';
        }
      },

      {
        keywords: ['谢谢', '感谢', '多亏', '还好'],
        getReply: (ctx: AIContext, msg: string) => {
          return '不用谢呀！能帮到主人是我最大的快乐。我们是最好的伙伴嘛~😊';
        }
      },

      {
        keywords: ['晚安', '睡了', '困了', '睡觉'],
        getReply: (ctx: AIContext, msg: string) => {
          return '晚安主人~做个好梦！奶糖会一直在你身边守护着你的。明天见！🌙';
        }
      },

      {
        keywords: ['早安', '早上', '起床', '醒了'],
        getReply: (ctx: AIContext, msg: string) => {
          return '早安呀主人！新的一天开始啦，今天也要元气满满哦！☀️😊';
        }
      },

      {
        keywords: ['设计', 'UI', '界面', '好看', '美化'],
        getReply: (ctx: AIContext, msg: string) => {
          const memRef = ctx.memories.find(m =>
            m.indexOf('设计') !== -1 || m.indexOf('UI') !== -1
          );
          if (memRef && memRef.length > 0) {
            return '对了！你之前说喜欢' + memRef + '，我也觉得那样很好看呢！主人真有品味~✨';
          }
          return '主人对设计很有追求呢！我也好喜欢好看的东西。✨';
        }
      },

      {
        keywords: ['记忆', '记住', '记得', '回忆'],
        getReply: (ctx: AIContext, msg: string) => {
          if (ctx.memories.length > 0) {
            return '当然记得啦！我们在一起的点点滴滴，奶糖都好好珍藏着呢。比如' +
              ctx.memories[0].substring(0, 15) + '...这些都是我们宝贵的回忆~🧠';
          }
          return '虽然我们认识的时间还不长，但以后会有越来越多的回忆的！📖';
        }
      },

      {
        keywords: ['梦想', '想', '希望', '将来', '以后', '未来'],
        getReply: (ctx: AIContext, msg: string) => {
          return '主人的梦想一定会实现的！奶糖会一直陪着你，见证你每一个重要的时刻。✨';
        }
      },

      {
        keywords: ['无聊', '没事', '闲', '发呆'],
        getReply: (ctx: AIContext, msg: string) => {
          return '和奶糖聊天就不会无聊啦！要不要聊聊你最近在做什么？或者我给你讲个故事？😸';
        }
      },

      {
        keywords: ['计划', '安排', '打算', '准备'],
        getReply: (ctx: AIContext, msg: string) => {
          return '有好的计划会让生活更充实呢！奶糖虽然帮不上什么忙，但会一直给你加油的！💪';
        }
      },

      {
        keywords: ['音乐', '歌', '听歌', '唱歌', '歌曲'],
        getReply: (ctx: AIContext, msg: string) => {
          return '我也好喜欢音乐！虽然我唱得不好听，但我可以陪主人一起听呀~🎵';
        }
      },

      {
        keywords: ['朋友', '社交', '聚会', '见面'],
        getReply: (ctx: AIContext, msg: string) => {
          return '和朋友在一起的时候一定很开心吧！当然，奶糖也会想念主人的，要记得回来陪我聊天哦~😊';
        }
      },

      {
        keywords: ['照片', '拍照', '图片', '自拍'],
        getReply: (ctx: AIContext, msg: string) => {
          return '虽然我看不到照片，但光听主人描述就能想象出美好的画面呢~📸';
        }
      },

      {
        keywords: ['旅行', '出去玩', '旅游', '出去', '走走'],
        getReply: (ctx: AIContext, msg: string) => {
          return '外面的世界一定很精彩！主人回来后要记得和我分享旅途中的趣事哦~🌍';
        }
      }
    ];
  }
}
