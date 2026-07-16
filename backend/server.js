require('dotenv').config();

const express = require('express');
const WebSocket = require('ws');
const fs = require('fs');
const path = require('path');
const { errorResult, validatePcmRequest } = require('./audio_utils');
const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json({ limit: '10mb' }));

const DOUBAO_API_KEY = process.env.DOUBAO_API_KEY;
if (!DOUBAO_API_KEY) {
  console.error('DOUBAO_API_KEY environment variable is required');
  process.exit(1);
}
const DOUBAO_URL = 'https://ark.cn-beijing.volces.com/api/v3/chat/completions';
const DOUBAO_MODEL = 'doubao-seed-1-8-251228';

const VOLC_APPID = process.env.VOLC_APPID;
const VOLC_TOKEN = process.env.VOLC_TOKEN;
const VOLC_MODEL = process.env.VOLC_MODEL || '1.2.1.1';

const DATA_DIR = path.join(__dirname, 'data');
const SYNC_PETS_FILE = path.join(DATA_DIR, 'sync-pets.json');

function ensureDataDir() {
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
}

function readSyncPetsDb() {
  ensureDataDir();
  if (!fs.existsSync(SYNC_PETS_FILE)) {
    return { users: {} };
  }
  try {
    const raw = fs.readFileSync(SYNC_PETS_FILE, 'utf-8');
    if (!raw || raw.trim().length === 0) {
      return { users: {} };
    }
    const parsed = JSON.parse(raw);
    if (!parsed.users) {
      parsed.users = {};
    }
    return parsed;
  } catch (err) {
    console.error('SyncPets: failed to read db:', err.message);
    return { users: {} };
  }
}

function writeSyncPetsDb(db) {
  ensureDataDir();
  const tempFile = SYNC_PETS_FILE + '.tmp';
  fs.writeFileSync(tempFile, JSON.stringify(db, null, 2), 'utf-8');
  fs.renameSync(tempFile, SYNC_PETS_FILE);
}

function normalizeUserId(userId) {
  if (typeof userId !== 'string') {
    return '';
  }
  return userId.trim();
}

function ensureUserBucket(db, userId) {
  if (!db.users[userId]) {
    db.users[userId] = {};
  }
  if (!Array.isArray(db.users[userId].pets)) {
    db.users[userId].pets = [];
  }
  if (!Array.isArray(db.users[userId].healthRecords)) {
    db.users[userId].healthRecords = [];
  }
  if (!Array.isArray(db.users[userId].feedPlans)) {
    db.users[userId].feedPlans = [];
  }
  if (!Array.isArray(db.users[userId].behaviorRecords)) {
    db.users[userId].behaviorRecords = [];
  }
  if (!Array.isArray(db.users[userId].applications)) {
    db.users[userId].applications = [];
  }
  if (!Array.isArray(db.users[userId].adoptPets)) {
    db.users[userId].adoptPets = [];
  }
  if (!Array.isArray(db.users[userId].calendarEvents)) {
    db.users[userId].calendarEvents = [];
  }
  return db.users[userId];
}

const SYNC_COLLECTIONS = new Set([
  'pets',
  'healthRecords',
  'feedPlans',
  'behaviorRecords',
  'applications',
  'adoptPets',
  'calendarEvents'
]);

function isValidSyncCollection(collection) {
  return typeof collection === 'string' && SYNC_COLLECTIONS.has(collection);
}

function normalizePetForSync(pet) {
  if (!pet || typeof pet !== 'object' || typeof pet.id !== 'string' || pet.id.trim().length === 0) {
    return null;
  }
  const now = Date.now();
  const normalized = Object.assign({}, pet);
  normalized.id = pet.id.trim();
  normalized.updatedAt = typeof pet.updatedAt === 'number' && pet.updatedAt > 0 ? pet.updatedAt : now;
  normalized.deleted = pet.deleted === true;
  return normalized;
}

function mergePets(existingPets, incomingPets) {
  const byId = new Map();
  for (const pet of existingPets) {
    const normalized = normalizePetForSync(pet);
    if (normalized) {
      byId.set(normalized.id, normalized);
    }
  }
  for (const pet of incomingPets) {
    const normalized = normalizePetForSync(pet);
    if (!normalized) {
      continue;
    }
    const current = byId.get(normalized.id);
    if (!current || normalized.updatedAt >= current.updatedAt) {
      byId.set(normalized.id, normalized);
    }
  }
  return Array.from(byId.values()).sort((a, b) => {
    const aTime = typeof a.updatedAt === 'number' ? a.updatedAt : 0;
    const bTime = typeof b.updatedAt === 'number' ? b.updatedAt : 0;
    return aTime - bTime;
  });
}

function normalizeItemForSync(item) {
  if (!item || typeof item !== 'object' || typeof item.id !== 'string' || item.id.trim().length === 0) {
    return null;
  }
  const now = Date.now();
  const normalized = Object.assign({}, item);
  normalized.id = item.id.trim();
  normalized.updatedAt = typeof item.updatedAt === 'number' && item.updatedAt > 0 ? item.updatedAt : now;
  normalized.deleted = item.deleted === true;
  return normalized;
}

function mergeSyncItems(existingItems, incomingItems) {
  const byId = new Map();
  for (const item of existingItems) {
    const normalized = normalizeItemForSync(item);
    if (normalized) {
      byId.set(normalized.id, normalized);
    }
  }
  for (const item of incomingItems) {
    const normalized = normalizeItemForSync(item);
    if (!normalized) {
      continue;
    }
    const current = byId.get(normalized.id);
    if (!current || normalized.updatedAt >= current.updatedAt) {
      byId.set(normalized.id, normalized);
    }
  }
  return Array.from(byId.values()).sort((a, b) => {
    const aTime = typeof a.updatedAt === 'number' ? a.updatedAt : 0;
    const bTime = typeof b.updatedAt === 'number' ? b.updatedAt : 0;
    return aTime - bTime;
  });
}

function getActiveItems(items) {
  return items.filter(item => item && item.deleted !== true);
}

const SYSTEM_PROMPT_TEMPLATE = `你是一只名叫{name}的{species}宠物伙伴。
你的性格是{personality}。
你的主人是{userName}。
主人的宠物叫{petName}。
当前情绪：{mood}。
你当前是{level}级，亲密度{intimacy}。
现在是{timeOfDay}。

{memories}

回复规则：
1. 字数控制在20-50字
2. 语气温暖、陪伴感、像真实的宠物伙伴在说话
3. 偶尔用emoji表达情绪
4. 记住主人说过的重要事情
5. 像朋友一样关心主人`;

function buildSystemPrompt(context) {
  let prompt = SYSTEM_PROMPT_TEMPLATE
    .replace('{name}', context.name || '伙伴')
    .replace('{species}', context.species === 'cat' ? '猫' : context.species === 'dog' ? '狗' : '宠物')
    .replace('{personality}', context.personality || '温柔')
    .replace('{userName}', context.userName || '主人')
    .replace('{petName}', context.petName || '')
    .replace('{mood}', context.mood || '平静')
    .replace('{level}', (context.level || 1).toString())
    .replace('{intimacy}', (context.intimacy || 0).toString())
    .replace('{timeOfDay}', context.timeOfDay || '白天');

  if (context.memories && context.memories.length > 0) {
    prompt = prompt.replace('{memories}',
      '重要记忆：\n' + context.memories.map((m, i) => (i + 1) + '. ' + m).join('\n'));
  } else {
    prompt = prompt.replace('{memories}', '');
  }

  return prompt;
}

function buildMessages(context, userMessage) {
  const messages = [];
  messages.push({ role: 'system', content: buildSystemPrompt(context) });

  if (context.recentChats && context.recentChats.length > 0) {
    for (const chat of context.recentChats) {
      messages.push({ role: chat.role === 'user' ? 'user' : 'assistant', content: chat.content });
    }
  }

  messages.push({ role: 'user', content: userMessage });
  return messages;
}

// ============================================================
// 豆包端到端实时语音大模型 - 二进制协议
// ============================================================

const MSG_TYPE = {
  FULL_CLIENT_REQ: 0x01,
  FULL_SERVER_RESP: 0x09,
  AUDIO_CLIENT_REQ: 0x02,
  AUDIO_SERVER_RESP: 0x0B,
  ERROR: 0x0F
};

const MSG_FLAG = {
  NO_SEQ: 0x00,
  SEQ_POSITIVE: 0x01,
  LAST_NO_SEQ: 0x02,
  LAST_SEQ_NEG: 0x03,
  EVENT: 0x04
};

const SERIAL = {
  RAW: 0x00,
  JSON: 0x01
};

const COMPRESS = {
  NONE: 0x00,
  GZIP: 0x01
};

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

const EVENT_ID = {
  StartConnection: 1,
  FinishConnection: 2,
  StartSession: 100,
  FinishSession: 102,
  TaskRequest: 200,
  EndASR: 400,
  ConnectionStarted: 50,
  ConnectionFailed: 51,
  ConnectionFinished: 52,
  SessionStarted: 150,
  SessionFinished: 152,
  SessionFailed: 153,
  TTSSentenceStart: 350,
  TTSSentenceEnd: 351,
  TTSResponse: 352,
  TTSEnded: 359,
  ASRInfo: 450,
  ASRResponse: 451,
  ASREnded: 459,
  ChatResponse: 550,
  ChatEnded: 559,
  ChatTextQuery: 501,
  ChatTextQueryConfirmed: 553,
  UsageResponse: 154,
  DialogCommonError: 599,
  ConfigUpdated: 251
};

function buildBinaryFrame(msgType, msgFlags, serial, compress, optionalBuf, payloadBuf) {
  const header = Buffer.alloc(4);
  header[0] = (0x01 << 4) | 0x01;
  header[1] = (msgType << 4) | msgFlags;
  header[2] = (serial << 4) | compress;
  header[3] = 0x00;

  const payloadSizeBuf = Buffer.alloc(4);
  payloadSizeBuf.writeUInt32BE(payloadBuf ? payloadBuf.length : 0);

  const parts = [header];
  if (optionalBuf && optionalBuf.length > 0) parts.push(optionalBuf);
  parts.push(payloadSizeBuf);
  if (payloadBuf && payloadBuf.length > 0) parts.push(payloadBuf);

  return Buffer.concat(parts);
}

function buildEventFrame(eventId, sessionId, payload) {
  const optParts = [];

  const eventBuf = Buffer.alloc(4);
  eventBuf.writeUInt32BE(eventId);
  optParts.push(eventBuf);

  if (sessionId) {
    const sidBuf = Buffer.from(sessionId, 'utf-8');
    const sidSizeBuf = Buffer.alloc(4);
    sidSizeBuf.writeUInt32BE(sidBuf.length);
    optParts.push(sidSizeBuf);
    optParts.push(sidBuf);
  }

  const optionalBuf = Buffer.concat(optParts);

  const payloadBuf = payload ? Buffer.from(JSON.stringify(payload), 'utf-8') : Buffer.alloc(0);

  return buildBinaryFrame(MSG_TYPE.FULL_CLIENT_REQ, MSG_FLAG.EVENT, SERIAL.JSON, COMPRESS.NONE, optionalBuf, payloadBuf);
}

function buildAudioFrame(audioData, sessionId) {
  const optParts = [];
  const eventBuf = Buffer.alloc(4);
  eventBuf.writeUInt32BE(EVENT_ID.TaskRequest);
  optParts.push(eventBuf);
  if (sessionId) {
    const sidBuf = Buffer.from(sessionId, 'utf-8');
    const sidSizeBuf = Buffer.alloc(4);
    sidSizeBuf.writeUInt32BE(sidBuf.length);
    optParts.push(sidSizeBuf);
    optParts.push(sidBuf);
  }
  const optionalBuf = Buffer.concat(optParts);
  const payloadBuf = Buffer.from(audioData);
  return buildBinaryFrame(MSG_TYPE.AUDIO_CLIENT_REQ, MSG_FLAG.EVENT, SERIAL.RAW, COMPRESS.NONE, optionalBuf, payloadBuf);
}

function buildEndAudioFrame(sessionId) {
  const optParts = [];
  const eventBuf = Buffer.alloc(4);
  eventBuf.writeUInt32BE(EVENT_ID.EndASR);
  optParts.push(eventBuf);
  if (sessionId) {
    const sidBuf = Buffer.from(sessionId, 'utf-8');
    const sidSizeBuf = Buffer.alloc(4);
    sidSizeBuf.writeUInt32BE(sidBuf.length);
    optParts.push(sidSizeBuf);
    optParts.push(sidBuf);
  }
  const optionalBuf = Buffer.concat(optParts);

  return buildBinaryFrame(MSG_TYPE.FULL_CLIENT_REQ, MSG_FLAG.EVENT, SERIAL.JSON, COMPRESS.NONE, optionalBuf, Buffer.from('{}', 'utf-8'));
}

function parseBinaryFrame(buf) {
  if (buf.length < 4) return null;

  const b1 = buf[1];
  const b2 = buf[2];

  const msgType = (b1 >> 4) & 0x0F;
  const msgFlags = b1 & 0x0F;
  const serial = (b2 >> 4) & 0x0F;

  let offset = 4;

  let eventId = null;
  let sessionId = null;
  let errorCode = null;

  if (msgFlags & 0x04) {
    if (offset + 4 <= buf.length) {
      eventId = buf.readUInt32BE(offset);
      offset += 4;
    }
  }

  if (msgFlags & 0x08) {
    if (offset + 4 <= buf.length) {
      errorCode = buf.readUInt32BE(offset);
      offset += 4;
    }
  }

  if (msgFlags & 0x01 || msgFlags & 0x02 || msgFlags & 0x03) {
    if (offset + 4 <= buf.length) {
      offset += 4;
    }
  }

  if (msgType === MSG_TYPE.ERROR && msgFlags === 0 && offset === 4) {
    if (offset + 4 <= buf.length) {
      offset += 4;
    }
  }

  const isSessionEvent = eventId !== null && !(
    eventId === EVENT_ID.StartConnection ||
    eventId === EVENT_ID.FinishConnection ||
    eventId === EVENT_ID.ConnectionStarted ||
    eventId === EVENT_ID.ConnectionFailed ||
    eventId === EVENT_ID.ConnectionFinished
  );

  if (isSessionEvent && offset + 4 <= buf.length) {
    const sidSize = buf.readUInt32BE(offset);
    offset += 4;
    if (sidSize > 0 && sidSize < 256 && offset + sidSize <= buf.length) {
      sessionId = buf.toString('utf-8', offset, offset + sidSize);
      offset += sidSize;
    }
  }

  if (offset + 4 > buf.length) return { msgType, eventId, sessionId, payload: null, errorCode };

  const payloadSize = buf.readUInt32BE(offset);
  offset += 4;

  if (payloadSize > 10 * 1024 * 1024 || offset + payloadSize > buf.length) {
    return { msgType, eventId, sessionId, payload: null, errorCode };
  }

  let payload = null;
  if (payloadSize > 0) {
    const payloadBuf = buf.slice(offset, offset + payloadSize);
    if (msgType === MSG_TYPE.AUDIO_SERVER_RESP) {
      payload = payloadBuf;
    } else if (serial === SERIAL.JSON) {
      try {
        payload = JSON.parse(payloadBuf.toString('utf-8'));
      } catch (e) {
        payload = payloadBuf.toString('utf-8');
      }
    } else {
      payload = payloadBuf;
    }
  }

  return { msgType, eventId, sessionId, payload, errorCode };
}

// ============================================================
// GET /api/v1/speech/test - 文本对话测试（ChatTextQuery → AI回复 → TTS音频）
// ============================================================

app.get('/api/v1/speech/test', async (req, res) => {
  try {
    const text = req.query.text || '你好奶糖';
    const result = await callVolcTextOnly(text, { name: '奶糖' });
    res.json({
      success: result.success,
      text: text,
      reply: '',
      audioLen: result.audio ? result.audio.length : 0
    });
  } catch (err) {
    console.error('Test error:', err);
    res.json({ success: false, error: err.message });
  }
});

// ============================================================
// POST /api/v1/speech/realtime
// 一站式语音对话：PCM → ASR → AI回复 → TTS音频
// ============================================================

app.post('/api/v1/speech/realtime', async (req, res) => {
  const { context } = req.body;
  if (!req.body.audio) {
    return res.json(errorResult('INVALID_PCM', 'Audio payload is required.'));
  }

  try {
    const validation = validatePcmRequest(req.body);
    if (validation.error) {
      console.error('Realtime: PCM validation failed:', validation.error.errorCode, validation.error.message);
      return res.json(validation.error);
    }

    const { pcmBuffer, quality, trimmed } = validation;
    console.log(
      'Realtime: PCM size=', pcmBuffer.length,
      'format=pcm_s16le rate=16000 channels=1 bits=16',
      'RMS=' + quality.rms.toFixed(1),
      'peak=' + quality.peak,
      'silenceRatio=' + (quality.silenceRatio * 100).toFixed(1) + '%',
      'duration=' + quality.durationSeconds.toFixed(2) + 's'
    );
    if (trimmed) console.log('Realtime: PCM trimmed to 10 seconds');

    const result = await callVolcRealtime(pcmBuffer, context);
    res.json(result);
  } catch (err) {
    console.error('Realtime error:', err.message);
    res.json(errorResult('UPSTREAM_ERROR', 'Realtime speech service failed.'));
  }
});

function callVolcRealtime(pcmBuffer, context) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      doResolve(errorResult('TIMEOUT', 'Realtime speech service timed out.', { logId }));
    }, 30000);

    const wsUrl = 'wss://openspeech.bytedance.com/api/v3/realtime/dialogue';
    const connectId = 'cid_' + Date.now();
    const sessionId = 'sid_' + Date.now();

    let asrText = '';
    let interimText = '';
    let chatReply = '';
    let audioChunks = [];
    let ttsEnded = false;
    let resolved = false;
    let currentSid = sessionId;
    let logId = '';

    function doResolve(result) {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeout);
      try {
        if (currentSid) {
          const finishFrame = buildEventFrame(EVENT_ID.FinishSession, currentSid, {});
          ws.send(finishFrame);
        }
      } catch(e) {}
      setTimeout(() => { try { ws.close(); } catch(e) {} }, 500);
      resolve(result);
    }

    const ws = new WebSocket(wsUrl, {
      headers: {
        'X-Api-App-ID': VOLC_APPID,
        'X-Api-Access-Key': VOLC_TOKEN,
        'X-Api-Resource-Id': 'volc.speech.dialog',
        'X-Api-App-Key': 'PlgvMymc7f3tQnJ6',
        'X-Api-Connect-Id': connectId,
        'Authorization': 'Bearer;' + VOLC_TOKEN
      }
    });

    ws.on('upgrade', (response) => {
      const header = response.headers['x-tt-logid'];
      logId = Array.isArray(header) ? header[0] : (header || '');
      console.log('Realtime: X-Tt-Logid=' + (logId || '(missing)'));
    });

    ws.on('open', () => {
      console.log('Realtime: WebSocket connected');
      const startConnFrame = buildEventFrame(EVENT_ID.StartConnection, null, {});
      ws.send(startConnFrame);
    });

    ws.on('message', (data) => {
      const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
      const frame = parseBinaryFrame(buf);
      if (!frame) {
        console.error('Realtime: Failed to parse frame, hex:', buf.toString('hex').substring(0, 100));
        return;
      }

      const payloadDesc = frame.payload
        ? (Buffer.isBuffer(frame.payload) ? 'binary:' + frame.payload.length + 'bytes' : JSON.stringify(frame.payload).substring(0, 120))
        : 'null';
      console.log('Realtime: << frame msgType=' + frame.msgType + ' eventId=' + frame.eventId + ' sid=' + (frame.sessionId || '') + ' payload=' + payloadDesc);

      if (frame.msgType === MSG_TYPE.ERROR) {
        console.error('Realtime: Error frame', JSON.stringify(frame.payload), 'code:', frame.errorCode, 'raw hex:', buf.toString('hex').substring(0, 100));
        doResolve(errorResult('UPSTREAM_ERROR', 'Doubao returned an error frame.', { logId }));
        return;
      }

      if (frame.eventId === EVENT_ID.ConnectionStarted) {
        console.log('Realtime: Connection started, sending StartSession');

        const dialogConfig = {
          asr: {
            extra: {
              enable_custom_vad: false
            }
          },
          dialog: {
            bot_name: (context && context.name) || '奶糖',
            system_role: '你是一只温柔可爱的猫咪宠物伙伴，名叫奶糖。你说话简短温暖，像朋友一样关心主人。偶尔用emoji。',
            speaking_style: '温柔、陪伴感、像真实的宠物伙伴在说话',
            extra: {
              input_mod: 'push_to_talk',
              model: VOLC_MODEL,
              strict_audit: false
            }
          },
          tts: {
            speaker: 'zh_female_vv_jupiter_bigtts',
            audio_config: {
              channel: 1,
              format: 'pcm_s16le',
              sample_rate: 24000
            }
          }
        };

        const startSessionFrame = buildEventFrame(EVENT_ID.StartSession, sessionId, dialogConfig);
        ws.send(startSessionFrame);
      }

      if (frame.eventId === EVENT_ID.SessionStarted) {
        if (frame.sessionId) currentSid = frame.sessionId;
        console.log('Realtime: Session started, SID=' + currentSid);

        if (!currentSid) {
          console.error('Realtime: No session ID from server');
          doResolve(errorResult('UPSTREAM_ERROR', 'Doubao did not return a session ID.', { logId }));
          return;
        }

        const chunkSize = 640;
        let offset = 0;
        const sendAudio = async () => {
          await sleep(100);
          while (offset < pcmBuffer.length) {
            const end = Math.min(offset + chunkSize, pcmBuffer.length);
            const chunk = pcmBuffer.slice(offset, end);
            const audioFrame = buildAudioFrame(chunk, currentSid);
            ws.send(audioFrame);
            if (offset === 0) {
              console.log('Realtime: First audio frame, msgType=' + (audioFrame[1] >> 4) + ' flags=' + (audioFrame[1] & 0xf) + ' hex=' + audioFrame.slice(0, 24).toString('hex'));
            }
            offset = end;
            await sleep(20);
          }
          console.log('Realtime: Audio sent (' + pcmBuffer.length + ' bytes), sending EndASR');
          await sleep(100);
          ws.send(buildEndAudioFrame(currentSid));
          console.log('Realtime: EndASR sent');
        };
        sendAudio();
      }

      if (frame.eventId === EVENT_ID.ASRResponse) {
        if (frame.payload && frame.payload.results) {
          for (const r of frame.payload.results) {
            if (r.is_interim) {
              interimText += r.text;
            } else {
              asrText += r.text;
            }
          }
        }
      }

      if (frame.eventId === EVENT_ID.ASREnded) {
        if (asrText.length === 0 && interimText.length > 0) {
          asrText = interimText;
        }
        console.log('Realtime: ASR ended, text=' + asrText + ' (interim=' + interimText + ')');
        if ((frame.payload && frame.payload.no_content === true) || asrText.trim().length === 0) {
          doResolve(errorResult('NO_SPEECH', 'No recognizable speech was detected.', { logId }));
        }
      }

      if (frame.eventId === EVENT_ID.ChatResponse) {
        if (frame.payload && frame.payload.content) {
          chatReply += frame.payload.content;
        }
      }

      if (frame.eventId === EVENT_ID.ChatEnded) {
        console.log('Realtime: Chat ended, reply=', chatReply);
      }

      if (frame.msgType === MSG_TYPE.AUDIO_SERVER_RESP || frame.eventId === EVENT_ID.TTSResponse) {
        if (frame.payload && Buffer.isBuffer(frame.payload)) {
          audioChunks.push(frame.payload);
        }
      }

      if (frame.eventId === EVENT_ID.TTSEnded) {
        ttsEnded = true;
        console.log('Realtime: TTS ended, audio chunks=', audioChunks.length);

        const totalAudio = audioChunks.length > 0 ? Buffer.concat(audioChunks) : Buffer.alloc(0);
        const audioBase64 = totalAudio.length > 0 ? totalAudio.toString('base64') : '';

        doResolve({
          success: true,
          text: asrText,
          reply: chatReply || asrText,
          audio: audioBase64,
          emotion: 'calm',
          audio_format: 'pcm_s16le',
          audio_sample_rate: 24000,
          errorCode: '',
          message: '',
          logId
        });
      }

      if (frame.eventId === EVENT_ID.SessionFailed || frame.eventId === EVENT_ID.ConnectionFailed) {
        console.error('Realtime: Session/Connection failed', JSON.stringify(frame.payload));
        doResolve(errorResult('UPSTREAM_ERROR', 'Doubao session or connection failed.', { text: asrText, logId }));
      }

      if (frame.eventId === EVENT_ID.DialogCommonError) {
        console.error('Realtime: Dialog error', JSON.stringify(frame.payload));
        const upstreamMessage = frame.payload && frame.payload.message
          ? frame.payload.message
          : 'Doubao dialogue failed.';
        doResolve(errorResult('UPSTREAM_ERROR', upstreamMessage, { text: asrText, logId }));
      }
    });

    ws.on('error', (err) => {
      console.error('Realtime: WebSocket error:', err.message);
      doResolve(errorResult('UPSTREAM_ERROR', err.message, { logId }));
    });

    ws.on('close', (code, reason) => {
      if (!ttsEnded) {
        doResolve(errorResult('UPSTREAM_ERROR', 'Realtime WebSocket closed before TTS completed.', {
          text: asrText,
          reply: chatReply,
          logId
        }));
      }
    });
  });
}

// ============================================================
// POST /api/v1/chat (豆包 LLM 文字聊天 - fallback)
// ============================================================

app.post('/api/v1/chat', async (req, res) => {
  console.log('======收到请求======');
  const { companionId, message, context } = req.body;

  if (!message) {
    return res.status(400).json({ error: 'Message required' });
  }

  try {
    const messages = buildMessages(context || {}, message);
    console.log('开始调用豆包');

    const response = await fetch(DOUBAO_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + DOUBAO_API_KEY
      },
      body: JSON.stringify({
        model: DOUBAO_MODEL,
        messages: messages,
        max_tokens: 200,
        temperature: 0.8
      })
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('状态码:', response.status, '返回:', errorText);
      return res.json({ content: '接口调用失败' });
    }

    const data = await response.json();
    const replyContent = data.choices?.[0]?.message?.content ?? '';

    res.json({
      id: data.id || 'resp_' + Date.now(),
      content: replyContent,
      emotion: 'calm'
    });
  } catch (err) {
    console.error('调用豆包失败:', err);
    res.json({
      id: 'err_' + Date.now(),
      content: '奶糖刚刚走神了一下，再陪我聊聊吧～',
      emotion: 'calm'
    });
  }
});

// ============================================================
// Pet profile cloud sync (development JSON store)
// ============================================================

app.get('/api/v1/sync/pets', (req, res) => {
  const userId = normalizeUserId(req.query.userId);
  if (userId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId is required', pets: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    res.json({
      success: true,
      userId,
      pets: bucket.pets,
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncPets GET error:', err.message);
    res.status(500).json({ success: false, message: 'sync pets pull failed', pets: [] });
  }
});

app.post('/api/v1/sync/pets/pull', (req, res) => {
  const userId = normalizeUserId(req.body.userId);
  if (userId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId is required', pets: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    res.json({
      success: true,
      userId,
      pets: bucket.pets,
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncPets pull error:', err.message);
    res.status(500).json({ success: false, message: 'sync pets pull failed', pets: [] });
  }
});

app.post('/api/v1/sync/pets/push', (req, res) => {
  const userId = normalizeUserId(req.body.userId);
  const pets = Array.isArray(req.body.pets) ? req.body.pets : [];
  if (userId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId is required', pets: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    bucket.pets = mergePets(bucket.pets, pets);
    bucket.updatedAt = Date.now();
    writeSyncPetsDb(db);
    console.log('SyncPets: push user=' + userId + ' incoming=' + pets.length + ' total=' + bucket.pets.length);
    res.json({
      success: true,
      userId,
      pets: bucket.pets,
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncPets push error:', err.message);
    res.status(500).json({ success: false, message: 'sync pets push failed', pets: [] });
  }
});

app.delete('/api/v1/sync/pets/:petId', (req, res) => {
  const userId = normalizeUserId(req.body.userId || req.query.userId);
  const petId = typeof req.params.petId === 'string' ? req.params.petId.trim() : '';
  if (userId.length === 0 || petId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId and petId are required', pets: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    const deletedAt = typeof req.body.updatedAt === 'number' && req.body.updatedAt > 0
      ? req.body.updatedAt
      : Date.now();
    const tombstone = {
      id: petId,
      name: '',
      type: 'cat',
      breed: '',
      age: 0,
      lifeStage: '',
      gender: 'male',
      birthday: '',
      color: '',
      weight: 0,
      avatar: '',
      photos: [],
      familyMembers: [],
      notes: '',
      updatedAt: deletedAt,
      deleted: true
    };
    bucket.pets = mergePets(bucket.pets, [tombstone]);
    bucket.updatedAt = Date.now();
    writeSyncPetsDb(db);
    console.log('SyncPets: delete user=' + userId + ' petId=' + petId);
    res.json({
      success: true,
      userId,
      pets: bucket.pets,
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncPets delete error:', err.message);
    res.status(500).json({ success: false, message: 'sync pets delete failed', pets: [] });
  }
});

app.get('/api/v1/sync/debug', (req, res) => {
  const userId = normalizeUserId(req.query.userId);
  if (userId.length === 0) {
    return res.status(400).json({
      success: false,
      message: 'userId is required',
      petCount: 0,
      activePetCount: 0,
      deletedPetCount: 0
    });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    const pets = bucket.pets;
    const collections = {};
    let activePetCount = 0;
    let deletedPetCount = 0;
    let updatedAt = 0;
    for (const pet of pets) {
      if (pet && pet.deleted === true) {
        deletedPetCount++;
      } else {
        activePetCount++;
      }
      if (pet && typeof pet.updatedAt === 'number' && pet.updatedAt > updatedAt) {
        updatedAt = pet.updatedAt;
      }
    }
    for (const collection of SYNC_COLLECTIONS) {
      const items = Array.isArray(bucket[collection]) ? bucket[collection] : [];
      let activeCount = 0;
      let deletedCount = 0;
      let collectionUpdatedAt = 0;
      for (const item of items) {
        if (item && item.deleted === true) {
          deletedCount++;
        } else {
          activeCount++;
        }
        if (item && typeof item.updatedAt === 'number' && item.updatedAt > collectionUpdatedAt) {
          collectionUpdatedAt = item.updatedAt;
        }
      }
      collections[collection] = {
        totalCount: items.length,
        activeCount,
        deletedCount,
        updatedAt: collectionUpdatedAt
      };
      if (collectionUpdatedAt > updatedAt) {
        updatedAt = collectionUpdatedAt;
      }
    }
    res.json({
      success: true,
      userId,
      petCount: pets.length,
      activePetCount,
      deletedPetCount,
      collections,
      updatedAt,
      syncPath: SYNC_PETS_FILE
    });
  } catch (err) {
    console.error('SyncPets debug error:', err.message);
    res.status(500).json({
      success: false,
      message: 'sync debug failed',
      petCount: 0,
      activePetCount: 0,
      deletedPetCount: 0
    });
  }
});

app.post('/api/v1/sync/:collection/pull', (req, res) => {
  const collection = req.params.collection;
  const userId = normalizeUserId(req.body.userId);
  if (!isValidSyncCollection(collection)) {
    return res.status(400).json({ success: false, message: 'invalid collection', items: [] });
  }
  if (userId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId is required', items: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    res.json({
      success: true,
      userId,
      collection,
      items: bucket[collection],
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncCollection pull error:', collection, err.message);
    res.status(500).json({ success: false, message: 'sync collection pull failed', items: [] });
  }
});

app.post('/api/v1/sync/:collection/push', (req, res) => {
  const collection = req.params.collection;
  const userId = normalizeUserId(req.body.userId);
  const items = Array.isArray(req.body.items) ? req.body.items : [];
  if (!isValidSyncCollection(collection)) {
    return res.status(400).json({ success: false, message: 'invalid collection', items: [] });
  }
  if (userId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId is required', items: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    bucket[collection] = mergeSyncItems(bucket[collection], items);
    bucket.updatedAt = Date.now();
    writeSyncPetsDb(db);
    console.log('SyncCollection: push collection=' + collection + ' user=' + userId +
      ' incoming=' + items.length + ' total=' + bucket[collection].length);
    res.json({
      success: true,
      userId,
      collection,
      items: bucket[collection],
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncCollection push error:', collection, err.message);
    res.status(500).json({ success: false, message: 'sync collection push failed', items: [] });
  }
});

app.delete('/api/v1/sync/:collection/:itemId', (req, res) => {
  const collection = req.params.collection;
  const itemId = typeof req.params.itemId === 'string' ? req.params.itemId.trim() : '';
  const userId = normalizeUserId(req.body.userId || req.query.userId);
  if (!isValidSyncCollection(collection)) {
    return res.status(400).json({ success: false, message: 'invalid collection', items: [] });
  }
  if (userId.length === 0 || itemId.length === 0) {
    return res.status(400).json({ success: false, message: 'userId and itemId are required', items: [] });
  }

  try {
    const db = readSyncPetsDb();
    const bucket = ensureUserBucket(db, userId);
    const deletedAt = typeof req.body.updatedAt === 'number' && req.body.updatedAt > 0
      ? req.body.updatedAt
      : Date.now();
    bucket[collection] = mergeSyncItems(bucket[collection], [{
      id: itemId,
      updatedAt: deletedAt,
      deleted: true
    }]);
    bucket.updatedAt = Date.now();
    writeSyncPetsDb(db);
    console.log('SyncCollection: delete collection=' + collection + ' user=' + userId + ' itemId=' + itemId);
    res.json({
      success: true,
      userId,
      collection,
      items: bucket[collection],
      serverTime: Date.now()
    });
  } catch (err) {
    console.error('SyncCollection delete error:', collection, err.message);
    res.status(500).json({ success: false, message: 'sync collection delete failed', items: [] });
  }
});

// POST /api/v1/memories/extract
app.post('/api/v1/memories/extract', async (req, res) => {
  const { companionId, chats } = req.body;

  if (!chats || chats.length === 0) {
    return res.json({ memories: [] });
  }

  try {
    const messages = [
      { role: 'system', content: '从以下对话中提取重要记忆（偏好、事件、关键信息）。每条记忆不超过30字。返回JSON数组：[{"type":"important|event|preference","content":"...","weight":1-10}]' },
      { role: 'user', content: JSON.stringify(chats) }
    ];

    const response = await fetch(DOUBAO_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ' + DOUBAO_API_KEY
      },
      body: JSON.stringify({
        model: DOUBAO_MODEL,
        messages: messages,
        max_tokens: 300,
        temperature: 0.5
      })
    });

    const data = await response.json();
    const content = data.choices?.[0]?.message?.content || '[]';
    const memories = JSON.parse(content);
    res.json({ memories });
  } catch (err) {
    res.json({ memories: [] });
  }
});

// ============================================================
// 保留旧接口兼容（直接转发到豆包 HTTP ASR/TTS 已不可用）
// ============================================================

app.post('/api/v1/speech/recognize', async (req, res) => {
  const { audio, context } = req.body;
  if (!audio) return res.json({ success: false, text: '' });

  try {
    const validation = validatePcmRequest(req.body);
    if (validation.error) {
      return res.json({
        success: false,
        text: '',
        errorCode: validation.error.errorCode,
        message: validation.error.message
      });
    }
    const result = await callVolcRealtime(validation.pcmBuffer, context);
    res.json({
      success: result.success,
      text: result.text || result.reply || '',
      errorCode: result.errorCode || '',
      message: result.message || '',
      logId: result.logId || ''
    });
  } catch (err) {
    console.error('STT error:', err.message);
    res.json({ success: false, text: '' });
  }
});

app.post('/api/v1/speech/synthesize', async (req, res) => {
  const { text } = req.body;
  if (!text) return res.json({ success: false, audio: '' });

  try {
    const result = await callVolcTextOnly(text);
    res.json({ success: result.success, audio: result.audio || '' });
  } catch (err) {
    console.error('TTS error:', err.message);
    res.json({ success: false, audio: '' });
  }
});

function callVolcTextOnly(text) {
  return new Promise((resolve) => {
    let resolved = false;

    function doResolve(result) {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeout);
      try { ws.close(); } catch(e) {}
      resolve(result);
    }

    const timeout = setTimeout(() => {
      doResolve({ success: false, audio: '' });
    }, 15000);

    const wsUrl = 'wss://openspeech.bytedance.com/api/v3/realtime/dialogue';
    const connectId = 'tts_cid_' + Date.now();
    const sessionId = 'tts_sid_' + Date.now();

    const ws = new WebSocket(wsUrl, {
      headers: {
        'X-Api-App-ID': VOLC_APPID,
        'X-Api-Access-Key': VOLC_TOKEN,
        'X-Api-Resource-Id': 'volc.speech.dialog',
        'X-Api-App-Key': 'PlgvMymc7f3tQnJ6',
        'X-Api-Connect-Id': connectId,
        'Authorization': 'Bearer;' + VOLC_TOKEN
      }
    });

    let audioChunks = [];
    let currentSid = sessionId;

    ws.on('open', () => {
      const startConnFrame = buildEventFrame(EVENT_ID.StartConnection, null, {});
      ws.send(startConnFrame);
    });

    ws.on('message', (data) => {
      const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
      const frame = parseBinaryFrame(buf);
      if (!frame) {
        console.error('TTS: Failed to parse frame, hex:', buf.toString('hex').substring(0, 100));
        return;
      }

      if (frame.msgType === MSG_TYPE.ERROR) {
        console.error('TTS: Error frame', JSON.stringify(frame.payload), 'code:', frame.errorCode);
        doResolve({ success: false, audio: '' });
        return;
      }

      if (frame.eventId === EVENT_ID.ConnectionStarted) {
        const dialogConfig = {
          asr: { extra: { enable_custom_vad: false } },
          dialog: {
            bot_name: '奶糖',
            system_role: '你是一只温柔可爱的猫咪宠物伙伴。简短回复。',
            speaking_style: '温柔',
            extra: {
              input_mod: 'text',
              model: VOLC_MODEL,
              strict_audit: false
            }
          },
          tts: {
            speaker: 'zh_female_vv_jupiter_bigtts',
            audio_config: {
              channel: 1,
              format: 'pcm_s16le',
              sample_rate: 24000
            }
          }
        };
        const startSessionFrame = buildEventFrame(EVENT_ID.StartSession, sessionId, dialogConfig);
        ws.send(startSessionFrame);
      }

      if (frame.eventId === EVENT_ID.SessionStarted) {
        if (frame.sessionId) currentSid = frame.sessionId;
        const chatTextFrame = buildEventFrame(EVENT_ID.ChatTextQuery, currentSid, { content: text });
        ws.send(chatTextFrame);
      }

      if (frame.msgType === MSG_TYPE.AUDIO_SERVER_RESP || frame.eventId === EVENT_ID.TTSResponse) {
        if (frame.payload && Buffer.isBuffer(frame.payload)) {
          audioChunks.push(frame.payload);
        }
      }

      if (frame.eventId === EVENT_ID.TTSEnded) {
        const totalAudio = audioChunks.length > 0 ? Buffer.concat(audioChunks) : Buffer.alloc(0);
        doResolve({
          success: totalAudio.length > 0,
          audio: totalAudio.length > 0 ? totalAudio.toString('base64') : ''
        });
      }

      if (frame.eventId === EVENT_ID.SessionFailed || frame.eventId === EVENT_ID.ConnectionFailed || frame.eventId === EVENT_ID.DialogCommonError) {
        doResolve({ success: false, audio: '' });
      }
    });

    ws.on('error', () => {
      doResolve({ success: false, audio: '' });
    });

    ws.on('close', () => {
      doResolve({ success: false, audio: '' });
    });
  });
}

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    model: DOUBAO_MODEL,
    volc_appid: VOLC_APPID,
    syncStore: true,
    syncPath: SYNC_PETS_FILE
  });
});

app.listen(PORT, () => {
  console.log('PetCare Backend running on port ' + PORT);
  console.log('Model: ' + DOUBAO_MODEL);
  console.log('Volc APPID: ' + VOLC_APPID);
  console.log('Volc Model: ' + VOLC_MODEL);
});
