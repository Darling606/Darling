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

import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../utils/Logger';
import { secToTimeStr } from '../utils/StringUtil';
import { startContinuousTask, stopContinuousTask } from '../utils/BackgroundTaskUtil';
import { AudioCapturerController } from '../controller/AudioCapturerController';
import { BreakpointType, BreakpointTypeEnum } from '../utils/BreakpointSystem';
import { Constants } from '../common/Constants';

@Component
export struct RecordDialog {
  @State timeStr: string = '00:00:00';
  @State isStop: boolean = false;
  @Link isRecord: boolean;
  @StorageProp(Constants.KEY_PREFIX_BREAKPOINT) currentBreakpoint: string = BreakpointTypeEnum.SM;
  private recorderController: AudioCapturerController =
    new AudioCapturerController(this.getUIContext().getHostContext()!);
  private seconds: number = 0;
  private timer: number = 0;

  aboutToAppear() {
    try {
      this.recorderController.initCapturer().then(() => {
        this.recorderController.startCapturer();
      });
      this.getRecordTime();
    } catch (error) {
      Logger.error('TAG', `getDefaultDisplaySync error. message:${(error as BusinessError).message}`);
    }
    startContinuousTask(this.getUIContext().getHostContext());
  }

  aboutToDisappear(): void {
    clearInterval(this.timer);
    stopContinuousTask(this.getUIContext().getHostContext());
  }

  getRecordTime(): void {
    this.timer = setInterval(() => {
      if (!this.isStop) {
        this.seconds += 1;
        this.timeStr = secToTimeStr(this.seconds);
      }
    }, 1000);
  }

  stopCapturer(): void {
    this.isRecord = false;
    this.recorderController.stopCapturer().then(() => {
      this.recorderController.releaseCapturer();
    })
  }

  build() {
    Column() {
      Row() {
        Text('Record')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)

        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.xmark'))
            .padding(11)
        }
        .width(40)
        .aspectRatio(1)
        .backgroundColor('#0C000000')
        .onClick(() => {
          this.stopCapturer();
        })
      }
      .width('100%')
      .height(56)
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 8 })
      .padding({
        left: 16,
        right: 16,
        top: 8,
        bottom: 8
      })

      Column() {
        Row() {
          Text(this.timeStr)
            .fontSize(24)
            .fontWeight(600)
            .fontColor('rgba(0, 0, 0, 0.9)')
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
      }
      .margin({
        left: 16,
        right: 16
      })
      .height(new BreakpointType({
        xs: 138,
        sm: 236,
        md: 236,
        lg: 236,
        xl: 236
      }).getValue(this.currentBreakpoint))
      .borderRadius(20)
      .backgroundColor(Color.White)
      .justifyContent(FlexAlign.Center)

      Row() {
        Button({ type: ButtonType.Circle }) {
          Rect({ radius: 4 })
            .width(20)
            .aspectRatio(1)
            .fill(Color.White)
        }
        .width(56)
        .height(56)
        .margin({ left: 24, right: 24 })
        .aspectRatio(1)
        .backgroundColor(Color.Red)
        .onClick(() => {
          this.stopCapturer();
        })
      }
      .margin({
        left: 58,
        right: 58,
        top: new BreakpointType({
          xs: 24,
          sm: 24,
          md: 56,
          lg: 56,
          xl: 56
        }).getValue(this.currentBreakpoint),
        bottom: new BreakpointType({
          xs: 24,
          sm: 24,
          md: 56,
          lg: 56,
          xl: 56
        }).getValue(this.currentBreakpoint)
      })
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .borderRadius({
      topLeft: 45,
      topRight: 45
    })
  }
}