import { audio } from '@kit.AudioKit';
import { fileIo, WriteOptions } from '@kit.CoreFileKit';
import http from '@ohos.net.http';

const SAMPLE_RATE_RECORD: number = 48000;
const SAMPLE_RATE_ASR: number = 16000;
const MIN_AUDIO_DURATION_SECONDS: number = 1.2;
const PCM_TEMP_FILE: string = '/voice_record.pcm';

interface PcmQuality {
  rms: number;
  peak: number;
  silenceRatio: number;
}

export class VoiceService {
  private static instance: VoiceService;
  private capturer: audio.AudioCapturer | null = null;
  private isRecording: boolean = false;
  private apiBaseUrl: string = '';
  private appContext: Context | null = null;
  private tmpPath: string = '';
  private recordFile: fileIo.File | null = null;
  private writeOffset: number = 0;

  static getInstance(): VoiceService {
    if (!VoiceService.instance) {
      VoiceService.instance = new VoiceService();
    }
    return VoiceService.instance;
  }

  init(baseUrl: string): void {
    this.apiBaseUrl = baseUrl;
  }

  async initCapturer(): Promise<void> {
    const audioStreamInfo: audio.AudioStreamInfo = {
      channels: audio.AudioChannel.CHANNEL_1,
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    const audioCapturerInfo: audio.AudioCapturerInfo = {
      capturerFlags: 0,
      source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION
    };

    const audioCapturerOptions: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo,
      capturerInfo: audioCapturerInfo
    };

    this.capturer = await audio.createAudioCapturer(audioCapturerOptions);

    try {
      this.capturer.setWillMuteWhenInterrupted(true);
    } catch (e) {
      console.log('VoiceService: setWillMuteWhenInterrupted not supported');
    }

    this.capturer.on('stateChange', (state: audio.AudioState) => {
      console.log('VoiceService: AudioCapturer state changed: ' + state.toString());
    });

    this.capturer.on('readData', (buffer: ArrayBuffer) => {
      if (!this.recordFile) {
        return;
      }
      try {
        const options: WriteOptions = { offset: this.writeOffset, length: buffer.byteLength };
        fileIo.writeSync(this.recordFile!.fd, buffer, options);
        this.writeOffset += buffer.byteLength;
      } catch (e) {
        console.error('VoiceService: writeSync error: ' + JSON.stringify(e));
      }
    });

    console.log('VoiceService: AudioCapturer initialized, 48kHz VOICE_COMMUNICATION');
  }

  async startRecording(context: Context): Promise<void> {
    if (this.isRecording) return;

    this.appContext = context;
    this.writeOffset = 0;

    try {
      if (this.capturer === null) {
        await this.initCapturer();
      }

      const state: audio.AudioState = this.capturer!.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.capturer = null;
        throw new Error('AudioCapturer at invalid state');
      }
      if (state !== audio.AudioState.STATE_PREPARED && state !== audio.AudioState.STATE_STOPPED) {
        console.log('VoiceService: Capturer state=' + state.toString() + ', releasing and re-init');
        this.capturer!.off('readData');
        await this.capturer!.release();
        this.capturer = null;
        await this.initCapturer();
      }

      this.tmpPath = context.filesDir + PCM_TEMP_FILE;
      const openMode: number = fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC;
      this.recordFile = fileIo.openSync(this.tmpPath, openMode);
      this.writeOffset = 0;

      await this.capturer!.start();
      this.isRecording = true;
      console.log('VoiceService: Recording started, file=' + this.tmpPath);
    } catch (err) {
      console.error('VoiceService startRecording error: ' + JSON.stringify(err));
      if (this.recordFile) {
        fileIo.closeSync(this.recordFile.fd);
        this.recordFile = null;
      }
      throw new Error('AudioCapturer failed');
    }
  }

  async stopRecording(): Promise<string | null> {
    if (!this.isRecording || !this.capturer) return null;
    this.isRecording = false;

    try {
      const state: audio.AudioState = this.capturer.state;
      if (state === audio.AudioState.STATE_RUNNING) {
        await this.capturer.stop();
      }
      if (this.recordFile) {
        fileIo.closeSync(this.recordFile.fd);
        this.recordFile = null;
      }
      console.log('VoiceService: Recording stopped, file size=' + this.writeOffset.toString());
    } catch (err) {
      console.error('VoiceService stop error: ' + JSON.stringify(err));
      if (this.recordFile) {
        try { fileIo.closeSync(this.recordFile.fd); } catch (e) {}
        this.recordFile = null;
      }
    }

    if (this.writeOffset === 0) {
      this.releaseCapturer();
      return null;
    }

    let pcmBuffer: ArrayBuffer;
    try {
      const stat: fileIo.Stat = fileIo.statSync(this.tmpPath);
      const fileSize: number = stat.size;
      if (fileSize === 0) {
        this.releaseCapturer();
        return null;
      }
      pcmBuffer = new ArrayBuffer(fileSize);
      const file: fileIo.File = fileIo.openSync(this.tmpPath, fileIo.OpenMode.READ_ONLY);
      fileIo.readSync(file.fd, pcmBuffer);
      fileIo.closeSync(file.fd);
    } catch (err) {
      console.error('VoiceService read PCM file error: ' + JSON.stringify(err));
      this.releaseCapturer();
      return null;
    }

    const resampled: Int16Array = this.resample48kTo16k(pcmBuffer);
    console.log('VoiceService: Resampled ' + pcmBuffer.byteLength.toString() + ' -> ' +
      resampled.buffer.byteLength.toString() + ' bytes');

    const quality: PcmQuality = this.calculateQuality(resampled);
    const durationSeconds: number = resampled.length / SAMPLE_RATE_ASR;
    console.log('VoiceService: PCM quality check, RMS=' + quality.rms.toFixed(1) +
      ' peak=' + quality.peak.toString() +
      ' silenceRatio=' + (quality.silenceRatio * 100).toFixed(1) + '%' +
      ' duration=' + durationSeconds.toFixed(2) + 's' +
      ' rawBytes=' + pcmBuffer.byteLength.toString() +
      ' asrBytes=' + resampled.buffer.byteLength.toString());

    if (quality.rms < 100) {
      console.error('VoiceService: PCM RMS too low, microphone may not be available');
      this.releaseCapturer();
      return '__MICROPHONE_UNAVAILABLE__';
    }

    if (durationSeconds < MIN_AUDIO_DURATION_SECONDS) {
      console.error('VoiceService: Audio too short, ' +
        durationSeconds.toFixed(2) + 's');
      this.releaseCapturer();
      return '__AUDIO_TOO_SHORT__';
    }

    try {
      const pcmBytes: Uint8Array = new Uint8Array(resampled.buffer);
      const pcmBase64: string = this.uint8ArrayToBase64(pcmBytes);
      console.log('VoiceService: Sending PCM to realtime API, size=' + pcmBytes.length.toString());

      const result: RealtimeResult | null = await this.sendRealtime(pcmBase64);
      if (result) {
        console.log('VoiceService: Realtime result - text:' + result.text +
          ' reply:' + result.reply + ' audioLen:' + result.audio.length.toString() +
          ' errorCode:' + (result.errorCode || ''));
        this.releaseCapturer();
        return JSON.stringify(result);
      }
      this.releaseCapturer();
      return null;
    } catch (err) {
      console.error('VoiceService recognize error: ' + JSON.stringify(err));
      this.releaseCapturer();
      return null;
    }
  }

  private resample48kTo16k(pcmBuffer: ArrayBuffer): Int16Array {
    const src: Int16Array = new Int16Array(pcmBuffer);
    const srcLen: number = src.length;
    const ratio: number = SAMPLE_RATE_RECORD / SAMPLE_RATE_ASR;
    const dstLen: number = Math.floor(srcLen / ratio);
    const dst: Int16Array = new Int16Array(dstLen);

    for (let i: number = 0; i < dstLen; i++) {
      const srcIdx: number = i * 3;
      if (srcIdx + 2 < srcLen) {
        const sum: number = src[srcIdx] + src[srcIdx + 1] + src[srcIdx + 2];
        dst[i] = Math.round(sum / 3);
      } else if (srcIdx < srcLen) {
        dst[i] = src[srcIdx];
      }
    }

    return dst;
  }

  private calculateQuality(samples: Int16Array): PcmQuality {
    let sumSquares: number = 0;
    let peak: number = 0;
    let silentSamples: number = 0;
    const len: number = samples.length;
    for (let i: number = 0; i < len; i++) {
      const s: number = samples[i];
      sumSquares += s * s;
      const absolute: number = Math.abs(s);
      if (absolute > peak) {
        peak = absolute;
      }
      if (absolute < 100) {
        silentSamples++;
      }
    }
    return {
      rms: len > 0 ? Math.sqrt(sumSquares / len) : 0,
      peak: peak,
      silenceRatio: len > 0 ? silentSamples / len : 1
    };
  }

  private async releaseCapturer(): Promise<void> {
    if (this.capturer) {
      try {
        this.capturer.off('readData');
        const state: audio.AudioState = this.capturer.state;
        if (state === audio.AudioState.STATE_PREPARED || state === audio.AudioState.STATE_STOPPED) {
          await this.capturer.release();
        } else if (state === audio.AudioState.STATE_RUNNING) {
          await this.capturer.stop();
          await this.capturer.release();
        }
        console.log('VoiceService: AudioCapturer released');
      } catch (e) {
        console.error('VoiceService releaseCapturer error: ' + JSON.stringify(e));
      }
      this.capturer = null;
    }

    try {
      if (this.tmpPath.length > 0 && this.appContext) {
        fileIo.unlinkSync(this.tmpPath);
      }
    } catch (e) {}
  }

  private async sendRealtime(audioBase64: string): Promise<RealtimeResult | null> {
    if (this.apiBaseUrl.length === 0) return null;
    try {
      const request = http.createHttp();
      const body: string = JSON.stringify({
        audio: audioBase64,
        format: 'pcm_s16le',
        sample_rate: SAMPLE_RATE_ASR,
        channels: 1,
        bits_per_sample: 16
      });

      const response: http.HttpResponse = await request.request(
        this.apiBaseUrl + '/api/v1/speech/realtime',
        {
          method: http.RequestMethod.POST,
          header: { 'Content-Type': 'application/json' },
          extraData: body,
          connectTimeout: 10000,
          readTimeout: 60000
        }
      );

      if (response.responseCode === 200) {
        const rawText: string = response.result.toString();
        const data = JSON.parse(rawText) as Record<string, Object>;
        return {
          success: (data['success'] as boolean) || false,
          text: (data['text'] as string) || '',
          reply: (data['reply'] as string) || '',
          audio: (data['audio'] as string) || '',
          emotion: (data['emotion'] as string) || 'calm',
          audio_format: (data['audio_format'] as string) || 'pcm_s16le',
          audio_sample_rate: (data['audio_sample_rate'] as number) || 24000,
          errorCode: (data['errorCode'] as string) || '',
          message: (data['message'] as string) || '',
          logId: (data['logId'] as string) || ''
        };
      }
      console.error('VoiceService: Realtime API response code not 200 ' + response.responseCode.toString());
      return null;
    } catch (err) {
      console.error('VoiceService sendRealtime error: ' + JSON.stringify(err));
      return null;
    }
  }

  getState(): boolean { return this.isRecording; }

  release(): void {
    this.isRecording = false;
    if (this.recordFile) {
      try { fileIo.closeSync(this.recordFile.fd); } catch (e) {}
      this.recordFile = null;
    }
    if (this.capturer) {
      try {
        this.capturer.off('readData');
        this.capturer.stop();
        this.capturer.release();
        console.log('VoiceService: Released AudioCapturer');
      } catch (e) {
        console.error('VoiceService release error: ' + JSON.stringify(e));
      }
      this.capturer = null;
    }
    try {
      if (this.tmpPath.length > 0 && this.appContext) {
        fileIo.unlinkSync(this.tmpPath);
      }
    } catch (e) {}
  }

  private uint8ArrayToBase64(bytes: Uint8Array): string {
    const chars: string = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    let result: string = '';
    let i: number = 0;
    const len: number = bytes.length;
    while (i < len) {
      const a: number = bytes[i++];
      const hasB: boolean = i < len;
      const b: number = hasB ? bytes[i++] : 0;
      const hasC: boolean = i < len;
      const c: number = hasC ? bytes[i++] : 0;
      const bitmap: number = (a << 16) | (b << 8) | c;
      result += chars.charAt((bitmap >> 18) & 63);
      result += chars.charAt((bitmap >> 12) & 63);
      result += hasB ? chars.charAt((bitmap >> 6) & 63) : '=';
      result += hasC ? chars.charAt(bitmap & 63) : '=';
    }
    return result;
  }
}

export interface RealtimeResult {
  success: boolean;
  text: string;
  reply: string;
  audio: string;
  emotion: string;
  audio_format: string;
  audio_sample_rate: number;
  errorCode?: string;
  message?: string;
  logId?: string;
}
