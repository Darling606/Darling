import audio from '@ohos.multimedia.audio';
import http from '@ohos.net.http';

export class TTSService {
  private static instance: TTSService;
  private audioRenderer: audio.AudioRenderer | null = null;
  private speaking: boolean = false;
  private apiBaseUrl: string = '';
  private onPlayStart: (() => void) | null = null;
  private onPlayEnd: (() => void) | null = null;

  static getInstance(): TTSService {
    if (!TTSService.instance) {
      TTSService.instance = new TTSService();
    }
    return TTSService.instance;
  }

  init(baseUrl: string): void {
    this.apiBaseUrl = baseUrl;
  }

  async speak(text: string, onStart?: () => void, onComplete?: () => void): Promise<void> {
    if (this.speaking) {
      this.stop();
    }

    if (text.length === 0) {
      if (onComplete) { onComplete(); }
      return;
    }

    this.onPlayStart = onStart || null;
    this.onPlayEnd = onComplete || null;

    try {
      const audioBase64: string | null = await this.synthesizeSpeech(text);
      if (audioBase64 === null || audioBase64.length === 0) {
        this.finishPlayback();
        return;
      }

      const pcmBytes: number[] = this.base64ToBytes(audioBase64);

      this.speaking = true;
      if (this.onPlayStart) { this.onPlayStart(); }

      await this.playPcmRaw(pcmBytes, 24000);

      this.finishPlayback();
    } catch (err) {
      console.error('TTSService speak error:', JSON.stringify(err));
      this.finishPlayback();
    }
  }

  private async synthesizeSpeech(text: string): Promise<string | null> {
    if (this.apiBaseUrl.length === 0) return null;
    try {
      const request = http.createHttp();
      const body: string = JSON.stringify({ text: text.substring(0, 200) });

      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/speech/synthesize',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: body,
          connectTimeout: 5000,
          readTimeout: 15000
        }
      );

      if (response.responseCode === 200) {
        const rawText: string = response.result.toString();
        const data = JSON.parse(rawText) as Record<string, Object>;
        const audioValue: string = (data['audio'] as string) || '';
        return audioValue.length > 0 ? audioValue : null;
      }
      return null;
    } catch (err) {
      console.error('TTSService synthesizeSpeech error:', JSON.stringify(err));
      return null;
    }
  }

  private async playPcmRaw(pcmBytes: number[], sampleRate: number): Promise<void> {
    const totalLen: number = pcmBytes.length;
    const buf: ArrayBuffer = new ArrayBuffer(totalLen);
    const view: Uint8Array = new Uint8Array(buf);
    for (let i = 0; i < totalLen; i++) {
      view[i] = pcmBytes[i];
    }

    this.audioRenderer = await (audio.createAudioRenderer({
      rendererInfo: {
        usage: audio.StreamUsage.STREAM_USAGE_MEDIA,
        rendererFlags: 0
      },
      streamInfo: {
        samplingRate: sampleRate,
        channels: audio.AudioChannel.CHANNEL_1,
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
      }
    }) as Promise<audio.AudioRenderer>);
    console.log('TTSService: AudioRenderer created');

    const renderer: audio.AudioRenderer = this.audioRenderer!;
    try {
      await renderer.start();
      console.log('TTSService: AudioRenderer started');

      const CHUNK: number = 4096;
      let offset: number = 0;
      while (offset < totalLen) {
        const end: number = Math.min(offset + CHUNK, totalLen);
        await renderer.write(buf.slice(offset, end));
        offset = end;
      }

      await renderer.drain();
      console.log('TTSService: AudioRenderer drain done');
    } finally {
      if (this.audioRenderer === renderer) {
        try { await renderer.stop(); } catch (e) {}
        try { await renderer.release(); } catch (e) {}
        this.audioRenderer = null;
      }
    }
  }

  async playPcmBase64(pcmBase64: string, sampleRate: number, onStart?: () => void, onComplete?: () => void): Promise<void> {
    console.log('TTSService: playPcmBase64 START', 'base64Len=' + pcmBase64.length, 'sampleRate=' + sampleRate);
    if (this.speaking) {
      this.stop();
    }

    if (pcmBase64.length === 0) {
      if (onComplete) { onComplete(); }
      return;
    }

    this.onPlayStart = onStart || null;
    this.onPlayEnd = onComplete || null;

    try {
      const pcmBytes: number[] = this.base64ToBytes(pcmBase64);

      this.speaking = true;
      if (this.onPlayStart) { this.onPlayStart(); }

      await this.playPcmRaw(pcmBytes, sampleRate);

      this.finishPlayback();
    } catch (err) {
      console.error('TTSService playPcmBase64 error:', JSON.stringify(err));
      this.finishPlayback();
    }
  }

  stop(): void {
    if (this.audioRenderer) {
      try { this.audioRenderer.stop(); } catch (e) {}
      try { this.audioRenderer.release(); } catch (e) {}
      this.audioRenderer = null;
    }
    this.finishPlayback();
  }

  release(): void {
    this.stop();
  }

  isSpeaking(): boolean {
    return this.speaking;
  }

  private finishPlayback(): void {
    this.speaking = false;
    if (this.onPlayEnd) {
      this.onPlayEnd();
    }
  }

  private base64ToBytes(base64: string): number[] {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const result: number[] = [];
    let i: number = 0;

    while (i < base64.length) {
      const chC: string = base64.charAt(i + 2);
      const chD: string = base64.charAt(i + 3);
      const a: number = chars.indexOf(base64.charAt(i++));
      const b: number = chars.indexOf(base64.charAt(i++));
      const c: number = chC === '=' ? 0 : chars.indexOf(chC);
      i++;
      const d: number = chD === '=' ? 0 : chars.indexOf(chD);
      i++;

      const bitmap: number = (a << 18) | (b << 12) | (c << 6) | d;
      result.push((bitmap >> 16) & 255);
      if (chC !== '=') { result.push((bitmap >> 8) & 255); }
      if (chD !== '=') { result.push(bitmap & 255); }
    }
    return result;
  }
}
