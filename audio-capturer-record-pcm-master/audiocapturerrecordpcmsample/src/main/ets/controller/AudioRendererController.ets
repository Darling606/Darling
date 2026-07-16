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
import { fileIo } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { Constants } from '../common/Constants';
import { Logger } from '../utils/Logger';

const TAG = 'AudioRendererController';

export class AudioRendererController {
  private playFile?: fileIo.File;
  private fileSize: number = 0;
  private readOffset: number = 0;
  private renderer?: audio.AudioRenderer;

  rendererState(): audio.AudioState | undefined {
    return this.renderer !== undefined ? this.renderer.state : undefined;
  }

  async initRenderer(path?: string) {
    try {
      // Config AudioStreamInfo
      let audioStreamInfo: audio.AudioStreamInfo = {
        channels: audio.AudioChannel.CHANNEL_1, // Set channels
        samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_48000,  // Set samplingRate
        sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,  // Set sampleFormat
        encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,  // Set encodingType
      };
      // Config AudioRendererInfo
      let audioRendererInfo: audio.AudioRendererInfo = {
        rendererFlags: 0,
        usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      };
      // Config AudioRendererOptions
      let audioRendererOptions: audio.AudioRendererOptions = {
        streamInfo: audioStreamInfo,
        rendererInfo: audioRendererInfo,
      };

      this.renderer = await audio.createAudioRenderer(audioRendererOptions);
      // Set stateChange callback
      this.renderer.on('stateChange', (state: audio.AudioState) => {
        Logger.info(TAG, `Audio renderer state changed: ${state}`);
      });
      // Set writeData callback
      this.renderer.on('writeData', (buffer: ArrayBuffer) => {
        if (!this.playFile) {
          return;
        }
        let lastLen: number = this.fileSize - this.readOffset;
        let readLen: number = lastLen >= buffer.byteLength ? buffer.byteLength : lastLen;
        try {

          fileIo.readSync(this.playFile.fd, buffer, { offset: this.readOffset, length: readLen });

        } catch (error) {
          Logger.error(TAG, `writeData error. message:${(error as BusinessError).message}`);
        }

        this.readOffset += readLen;
        AppStorage.setOrCreate(Constants.KEY_PREFIX_CURRENT_TIME, this.readOffset);
        if (this.readOffset >= this.fileSize) {
          this.readOffset = 0;
        }
      });
      if (path !== undefined) {
        this.playFile = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
        this.fileSize = fileIo.statSync(path).size;
        this.readOffset = 0;
      }

    } catch (error) {
      if (this.playFile) {
        try {
          fileIo.closeSync(this.playFile.fd);
        } catch (err) {
          Logger.error(TAG, `startRenderer error. message:${(error as BusinessError).message}`);
        }
      }
      Logger.error(TAG, `initRenderer error. message:${(error as BusinessError).message}`);
    }
  }

  async startRenderer() {
    try {
      if (this.renderer === undefined) {
        throw new Error(`Release AudioRenderer at undefined state`);
      }
      let state: audio.AudioState = this.renderer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.renderer = undefined;
        throw new Error(`Start AudioRenderer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_PREPARED && state !== audio.AudioState.STATE_STOPPED &&
        state !== audio.AudioState.STATE_PAUSED) {
        throw new Error(`Start AudioRenderer at wrong state, ${state}`);
      }

      await this.renderer.start();
    } catch (error) {
      Logger.error(TAG, `startRenderer error. message:${(error as BusinessError).message}`);
    }
  }

  async pauseRenderer() {
    try {
      if (this.renderer === undefined) {
        throw new Error(`Release AudioRenderer at undefined state`);
      }
      let state: audio.AudioState = this.renderer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.renderer = undefined;
        throw new Error(`Pause AudioRenderer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_RUNNING) {
        throw new Error(`Pause AudioRenderer at wrong state, ${state}`);
      }
      await this.renderer.pause();
    } catch (error) {
      Logger.error(TAG, `startRenderer error. error:${(error)}`);
    }
  }

  async stopRenderer() {
    try {
      if (this.renderer === undefined) {
        throw new Error(`Release AudioRenderer at undefined state`);
      }
      let state: audio.AudioState = this.renderer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.renderer = undefined;
        throw new Error(`Stop AudioRenderer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_RUNNING && state !== audio.AudioState.STATE_PAUSED) {
        throw new Error(`Stop AudioRenderer at wrong state, ${state}`);
      }
      this.renderer.off('stateChange');
      this.renderer.off('writeData');
      await this.renderer.stop().then(() => {
        this.releaseRenderer();
      });
      fileIo.closeSync(this.playFile?.fd);
    } catch (error) {
      if (this.playFile) {
        try {
          fileIo.closeSync(this.playFile.fd);
        } catch (err) {
          Logger.error(TAG, `stopRenderer error. message:${(error as BusinessError).message}`);
        }
      }
    }
  }

  async releaseRenderer() {
    try {
      if (this.renderer === undefined) {
        throw new Error(`Release AudioRenderer at undefined state`);
      }
      let state: audio.AudioState = this.renderer.state;
      if (state === audio.AudioState.STATE_INVALID) {
        this.renderer = undefined;
        throw new Error(`Release AudioRenderer at invalid state.`);
      }
      if (state !== audio.AudioState.STATE_PAUSED && state !== audio.AudioState.STATE_STOPPED &&
        state !== audio.AudioState.STATE_PREPARED) {
        throw new Error(`Release AudioRenderer at wrong state, ${state}`);
      }
      await this.renderer.release();
    } catch (error) {
      Logger.error(TAG, `releaseRenderer error. error:${(error)}`);
    }
  }
}