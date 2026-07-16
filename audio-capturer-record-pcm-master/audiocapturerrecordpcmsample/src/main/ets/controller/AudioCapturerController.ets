/*
 * Copyright (c) 2026 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { audio } from '@kit.AudioKit';
import { WriteOptions, fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../utils/Logger';

const TAG = 'AudioCapturerController';

export class AudioCapturerController {
  private context?: Context;
  private tmpPath: string = '';
  private recordFile?: fileIo.File;
  private writeOffset: number = 0;
  private capturer?: audio.AudioCapturer;

  constructor(context: Context | undefined) {
    this.context = context;
  }

  /**
   * Initialize capturer
   * @returns
   */
  // [Start initCapturer]
  async initCapturer(): Promise<void> {
    try {
      // Config AudioStreamInfo
      const audioStreamInfo: audio.AudioStreamInfo = {
        channels: audio.AudioChannel.CHANNEL_1, // Set channel
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,  // Set samplingRate
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,  // Set sampleFormat
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,  // Set encodingType
      };
      // Config AudioCapturerInfo
      const audioCapturerInfo: audio.AudioCapturerInfo = {
        capturerFlags: 0,
        source: audio.SourceType.SOURCE_TYPE_VOICE_COMMUNICATION,
      };
      // Config AudioCapturerOptions
      const audioCapturerOptions: audio.AudioCapturerOptions = {
        streamInfo: audioStreamInfo,
        capturerInfo: audioCapturerInfo,
      };

      this.capturer = await audio.createAudioCapturer(audioCapturerOptions);
      // [Start setWillMute]
      // Set if capturer want to be muted
      this.capturer.setWillMuteWhenInterrupted(true).catch((error: BusinessError) => {
        Logger.error(TAG, `setWillMuteWhenInterrupted error. message:${error.message}`);
      });
      // [End setWillMute]
      // Set stateChange callback
      this.capturer.on('stateChange', (state: audio.AudioState) => {
        Logger.info(TAG, `Audio capturer state changed: ${state}`);
      });
      // Set readData callback
      this.capturer.on('readData', (buffer: ArrayBuffer) => {
        if (!this.recordFile) {
          return;
        }
        let options: WriteOptions = { offset: this.writeOffset, length: buffer.byteLength };
        fileIo.writeSync(this.recordFile.fd, buffer, options);
        this.writeOffset += buffer.byteLength;
      });
    } catch (error) {
      Logger.error(TAG, `initCapturer error. message:${(error as BusinessError).message}`);
    }
  }
  // [End initCapturer]

  /**
   * Start Capturer
   * @returns
   */
  // [Start startCapturer]
  async startCapturer(): Promise<void> {
    try {
      if (this.capturer === undefined) {
        throw new Error(`Release AudioCapturer at undefined state`);
      }
      let state = this.capturer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.capturer = undefined;
        throw new Error(`AudioCapturer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_PREPARED && state !== audio.AudioState.STATE_STOPPED) {
        throw new Error(`Release AudioCapturer at wrong state, ${state}`);
      }
      if (!this.context) {
        throw new Error(`Context is undefined.`);
      }
      this.tmpPath = this.context?.filesDir + '/example.pcm';
      let openMode = fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC;
      this.recordFile = fileIo.openSync(this.tmpPath, openMode);
      this.writeOffset = 0;
      await this.capturer.start();
    } catch (error) {
      Logger.error(TAG, `startCapturer error. message:${(error as BusinessError).message}`);
    }
  }
  // [End startCapturer]

  /**
   * Stop Capturer
   * @returns
   */
  // [Start stopCapturer]
  async stopCapturer(): Promise<void> {
    try {
      if (this.capturer === undefined) {
        throw new Error(`Release AudioCapturer at undefined state`);
      }
      let state = this.capturer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.capturer = undefined;
        throw new Error(`AudioCapturer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_RUNNING) {
        return;
      }
      await this.capturer.stop();
      fileIo.closeSync(this.recordFile?.fd);
    } catch (error) {
      Logger.error(TAG, `stopCapturer error. message:${(error as BusinessError).message}`);
    }
  }
  // [End stopCapturer]

  /**
   * Release Capturer
   * @returns
   */
  // [Start releaseCapturer]
  async releaseCapturer(): Promise<void> {
    try {
      if (this.capturer === undefined) {
        throw new Error(`Release AudioCapturer at undefined state`);
      }
      let state = this.capturer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.capturer = undefined;
        throw new Error(`AudioCapturer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_PREPARED && state !== audio.AudioState.STATE_STOPPED) {
        throw new Error(`Release AudioCapturer at wrong state, ${state}`);
      }
      this.capturer.off('readData');
      await this.capturer.release();
      this.capturer = undefined;
    } catch (error) {
      Logger.error(TAG, `releaseCapturer error. message:${(error as BusinessError).message}`);
    }
  }
  // [End releaseCapturer]
}