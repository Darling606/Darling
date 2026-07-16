require('dotenv').config();
const fs = require('node:fs');
const path = require('node:path');
const WebSocket = require('ws');

const VOLC_APPID = process.env.VOLC_APPID;
const VOLC_TOKEN = process.env.VOLC_TOKEN;
const VOLC_MODEL = process.env.VOLC_MODEL || '1.2.1.1';

const MSG_TYPE = { FULL_CLIENT_REQ: 0x01, FULL_SERVER_RESP: 0x09, AUDIO_CLIENT_REQ: 0x02, AUDIO_SERVER_RESP: 0x0B, ERROR: 0x0F };
const MSG_FLAG = { NO_SEQ: 0x00, EVENT: 0x04 };
const SERIAL = { RAW: 0x00, JSON: 0x01 };
const COMPRESS = { NONE: 0x00 };
const EVENT_ID = { StartConnection: 1, FinishConnection: 2, StartSession: 100, FinishSession: 102, TaskRequest: 200, EndASR: 400, ConnectionStarted: 50, ConnectionFailed: 51, ConnectionFinished: 52, SessionStarted: 150, SessionFinished: 152, SessionFailed: 153, TTSResponse: 352, TTSEnded: 359, ASRResponse: 451, ASREnded: 459, ChatResponse: 550, ChatEnded: 559, DialogCommonError: 599 };

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function loadSpeechFixture(filePath) {
  const input = fs.readFileSync(filePath);
  if (path.extname(filePath).toLowerCase() === '.pcm') {
    if (input.length % 2 !== 0) throw new Error('PCM fixture must have an even byte length.');
    return input;
  }
  if (path.extname(filePath).toLowerCase() !== '.wav' || input.toString('ascii', 0, 4) !== 'RIFF' ||
      input.toString('ascii', 8, 12) !== 'WAVE') {
    throw new Error('Fixture must be raw .pcm or PCM .wav.');
  }

  let offset = 12;
  let format = null;
  let data = null;
  while (offset + 8 <= input.length) {
    const chunkId = input.toString('ascii', offset, offset + 4);
    const chunkSize = input.readUInt32LE(offset + 4);
    const chunkStart = offset + 8;
    if (chunkId === 'fmt ' && chunkSize >= 16) {
      format = {
        audioFormat: input.readUInt16LE(chunkStart),
        channels: input.readUInt16LE(chunkStart + 2),
        sampleRate: input.readUInt32LE(chunkStart + 4),
        bitsPerSample: input.readUInt16LE(chunkStart + 14)
      };
    } else if (chunkId === 'data') {
      data = input.subarray(chunkStart, chunkStart + chunkSize);
    }
    offset = chunkStart + chunkSize + (chunkSize % 2);
  }

  if (!format || format.audioFormat !== 1 || format.channels !== 1 ||
      format.sampleRate !== 16000 || format.bitsPerSample !== 16 || !data) {
    throw new Error('WAV fixture must be mono 16kHz PCM S16LE.');
  }
  return data;
}

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
    if (offset + 4 <= buf.length) { eventId = buf.readUInt32BE(offset); offset += 4; }
  }
  if (msgFlags & 0x08) {
    if (offset + 4 <= buf.length) { errorCode = buf.readUInt32BE(offset); offset += 4; }
  }
  if (msgFlags & 0x01 || msgFlags & 0x02 || msgFlags & 0x03) {
    if (offset + 4 <= buf.length) { offset += 4; }
  }
  if (msgType === MSG_TYPE.ERROR && msgFlags === 0 && offset === 4) {
    if (offset + 4 <= buf.length) { offset += 4; }
  }
  const isSessionEvent = eventId !== null && !(eventId === 1 || eventId === 2 || eventId === 50 || eventId === 51 || eventId === 52);
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
      try { payload = JSON.parse(payloadBuf.toString('utf-8')); } catch (e) { payload = payloadBuf.toString('utf-8'); }
    } else {
      payload = payloadBuf;
    }
  }
  return { msgType, eventId, sessionId, payload, errorCode };
}

async function test() {
  const fixturePath = process.argv[2];
  if (!fixturePath) {
    throw new Error('Usage: npm run test:realtime -- <speech.pcm|speech.wav>');
  }
  const pcmBuffer = loadSpeechFixture(fixturePath);
  if (pcmBuffer.length < 38400) throw new Error('Speech fixture must be at least 1.2 seconds.');
  console.log('Test: Loaded', pcmBuffer.length, 'bytes from', fixturePath);

  const wsUrl = 'wss://openspeech.bytedance.com/api/v3/realtime/dialogue';
  const connectId = 'test_cid_' + Date.now();
  const sessionId = 'test_sid_' + Date.now();
  let currentSid = sessionId;
  let asrText = '';
  let interimText = '';
  let chatReply = '';
  let audioChunks = [];

  const result = await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      resolve({ success: false, text: asrText, reply: chatReply, audio: '', timeout: true });
    }, 30000);

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
      const logId = response.headers['x-tt-logid'];
      console.log('Test: X-Tt-Logid=' + (Array.isArray(logId) ? logId[0] : (logId || '(missing)')));
    });

    ws.on('open', () => {
      console.log('Test: WS connected');
      ws.send(buildEventFrame(EVENT_ID.StartConnection, null, {}));
    });

    ws.on('message', async (data) => {
      const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
      const frame = parseBinaryFrame(buf);
      if (!frame) { console.error('Test: Parse failed'); return; }

      const pDesc = frame.payload
        ? (Buffer.isBuffer(frame.payload) ? 'bin:' + frame.payload.length : JSON.stringify(frame.payload).substring(0, 100))
        : 'null';
      console.log('Test: << mt=' + frame.msgType + ' ev=' + frame.eventId + ' sid=' + (frame.sessionId||'') + ' p=' + pDesc);

      if (frame.msgType === MSG_TYPE.ERROR) {
        console.error('Test: ERROR', JSON.stringify(frame.payload));
        clearTimeout(timeout);
        resolve({ success: false, error: JSON.stringify(frame.payload) });
        return;
      }

      if (frame.eventId === EVENT_ID.ConnectionStarted) {
        console.log('Test: ConnectionStarted, sending StartSession');
        const dialogConfig = {
          asr: { extra: { enable_custom_vad: false } },
          dialog: {
            bot_name: '奶糖',
            system_role: '你是一只温柔可爱的猫咪宠物伙伴，名叫奶糖。你说话简短温暖，像朋友一样关心主人。偶尔用emoji。',
            speaking_style: '温柔、陪伴感、像真实的宠物伙伴在说话',
            extra: { input_mod: 'push_to_talk', model: VOLC_MODEL, strict_audit: false }
          },
          tts: {
            speaker: 'zh_female_vv_jupiter_bigtts',
            audio_config: { channel: 1, format: 'pcm_s16le', sample_rate: 24000 }
          }
        };
        ws.send(buildEventFrame(EVENT_ID.StartSession, sessionId, dialogConfig));
      }

      if (frame.eventId === EVENT_ID.SessionStarted) {
        if (frame.sessionId) currentSid = frame.sessionId;
        console.log('Test: SessionStarted, SID=' + currentSid);
        await sleep(100);

        const chunkSize = 640;
        let offset = 0;
        while (offset < pcmBuffer.length) {
          const end = Math.min(offset + chunkSize, pcmBuffer.length);
          const chunk = pcmBuffer.slice(offset, end);
          ws.send(buildAudioFrame(chunk, currentSid));
          offset = end;
          await sleep(20);
        }
        console.log('Test: Audio sent, waiting 100ms before EndASR');
        await sleep(100);
        ws.send(buildEndAudioFrame(currentSid));
        console.log('Test: EndASR sent');
      }

      if (frame.eventId === EVENT_ID.ASRResponse) {
        if (frame.payload && frame.payload.results) {
          for (const r of frame.payload.results) {
            if (r.is_interim) interimText += r.text;
            else asrText += r.text;
          }
          console.log('Test: ASR results, final=' + asrText + ' interim=' + interimText);
        }
      }

      if (frame.eventId === EVENT_ID.ASREnded) {
        if (asrText.length === 0 && interimText.length > 0) asrText = interimText;
        console.log('Test: ASREnded, text=' + asrText);
      }

      if (frame.eventId === EVENT_ID.ChatResponse) {
        if (frame.payload && frame.payload.content) chatReply += frame.payload.content;
      }

      if (frame.eventId === EVENT_ID.ChatEnded) {
        console.log('Test: ChatEnded, reply=' + chatReply);
      }

      if (frame.msgType === MSG_TYPE.AUDIO_SERVER_RESP || frame.eventId === EVENT_ID.TTSResponse) {
        if (frame.payload && Buffer.isBuffer(frame.payload)) audioChunks.push(frame.payload);
      }

      if (frame.eventId === EVENT_ID.TTSEnded) {
        console.log('Test: TTSEnded, audioChunks=' + audioChunks.length);
        const totalAudio = audioChunks.length > 0 ? Buffer.concat(audioChunks) : Buffer.alloc(0);
        clearTimeout(timeout);
        try {
          ws.send(buildEventFrame(EVENT_ID.FinishSession, currentSid, {}));
        } catch(e) {}
        setTimeout(() => { try { ws.close(); } catch(e) {} }, 500);
        resolve({
          success: true,
          text: asrText,
          reply: chatReply,
          audioLen: totalAudio.length,
          emotion: 'calm'
        });
      }

      if (frame.eventId === EVENT_ID.SessionFailed || frame.eventId === EVENT_ID.ConnectionFailed || frame.eventId === EVENT_ID.DialogCommonError) {
        console.error('Test: Failure event', frame.eventId, JSON.stringify(frame.payload));
        clearTimeout(timeout);
        resolve({ success: false, text: asrText, reply: chatReply, error: JSON.stringify(frame.payload) });
      }
    });

    ws.on('error', (err) => {
      console.error('Test: WS error:', err.message);
      clearTimeout(timeout);
      resolve({ success: false, error: err.message });
    });

    ws.on('close', (code, reason) => {
      console.log('Test: WS closed, code=' + code);
    });
  });

  console.log('\n===== TEST RESULT =====');
  console.log(JSON.stringify(result, null, 2));
}

test().catch(err => console.error('Test failed:', err));
