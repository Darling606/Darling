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

import { abilityAccessCtrl, common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { RecordFileInfo } from '../model/RecordFileInfo';
import { Constants } from '../common/Constants';
import {
  checkPermission,
  isGlobalMicToggle,
  isMicrophoneMute,
  openPermissionsSetting,
  requestPermissions
} from '../utils/PermissionUtil';
import { Logger } from '../utils/Logger';
import { RecordDialog } from '../components/RecordDialog';
import { toDateStr, toTimeStr } from '../utils/StringUtil';
import { AudioRendererController } from '../controller/AudioRendererController';
import { BreakpointType, BreakpointTypeEnum } from '../utils/BreakpointSystem';

const TAG: string = 'Index';

@Entry
@Component
struct Index {
  @State isPlay: boolean = false;
  @State isRecord: boolean = false;
  @State recordFiles: RecordFileInfo[] = [];
  @StorageLink(Constants.KEY_PREFIX_CURRENT_TIME) currentTime: number = 0;
  @StorageProp(Constants.KEY_PREFIX_BREAKPOINT) currentBreakpoint: string = BreakpointTypeEnum.SM;
  private context: Context = this.getUIContext().getHostContext()!;
  private audioRendererController?: AudioRendererController;
  private timeout: number = -1;

  aboutToAppear(): void {
    AppStorage.setOrCreate(Constants.KEY_PREFIX_CURRENT_TIME, 0);
    checkPermission(Constants.MICROPHONE_PERMISSION)
      .then((status: abilityAccessCtrl.GrantStatus) => {
        if (status === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
          requestPermissions(this.context as common.UIAbilityContext, [Constants.MICROPHONE_PERMISSION]);
        }
      })
      .catch((err: BusinessError) => {
        Logger.error(TAG, `Check permission failed, ${JSON.stringify(err)}`);
      });
    this.loadAudioFiles();
  }

  aboutToDisappear(): void {
    this.playerRelease();
    AppStorage.delete(Constants.KEY_PREFIX_CURRENT_TIME);
    AppStorage.delete(Constants.KEY_PREFIX_BREAKPOINT);
  }

  onPageHide(): void {
    if (this.isPlay) {
      this.audioRendererController?.pauseRenderer();
      this.isPlay = false;
    }
  }

  async loadAudioFiles() {
    try {
      let dataPath: string = this.context.filesDir;
      let fileNames: string[] = fs.listFileSync(dataPath);
      let len: number = fileNames.length;
      let recordFiles: RecordFileInfo[] = [];
      for (let i = 0; i < len; i++) {
        if (fileNames[i] === 'example.pcm') {
          let path: string = dataPath + `/${fileNames[i]}`;
          let stat: fs.Stat = fs.statSync(path);
          let mtime: number = stat.mtime;
          let size: number = stat.size;
          recordFiles.push({ name: fileNames[i], modifiedTime: mtime, size: size });
          if (!this.audioRendererController) {
            this.audioRendererController = new AudioRendererController();
            this.audioRendererController.initRenderer(path);
          }
          break;
        }
      }
      this.recordFiles = recordFiles;
    } catch (error) {
      Logger.error(TAG, `loadAudioFiles error. message:${(error as BusinessError).message}`);
    }
  }

  async playerRelease(): Promise<void> {
    this.isPlay = false;
    AppStorage.setOrCreate(Constants.KEY_PREFIX_CURRENT_TIME, 0);
    this.audioRendererController?.stopRenderer().then(() => {
      this.audioRendererController = undefined;
    });
  }

  debounce(fn: Function, wait: number = 300) {
    if (this.timeout !== -1) {
      clearTimeout(this.timeout);
    }
    this.timeout = setTimeout(fn.bind(this), wait);
  }

  @Builder
  recordDialogBuilder() {
    RecordDialog({ isRecord: this.isRecord })
  }

  @Builder
  listCard(info: RecordFileInfo) {
    Column() {
      Row() {
        Column({ space: 8 }) {
          Text(info.name)
            .maxLines(1)
            .fontSize(18)
            .fontWeight(600)
            .fontColor('rgb(25, 25, 25)')
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(toDateStr(info.modifiedTime))
            .maxLines(1)
            .fontSize(12.5)
            .fontWeight(400)
            .fontColor('rgba(0, 0, 0, 0.6)')
        }
        .height('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)

        Row({ space: 16 }) {
          Text(toTimeStr(info.size))
            .maxLines(1)
            .fontSize(18)
            .fontWeight(600)
            .fontColor('rgba(9, 3, 3, 0.9)')

          Button() {
            Image(this.isPlay ? $r('app.media.pause') : $r('app.media.play'))
              .onClick(() => {
                this.debounce(() => {
                  if (this.isPlay) {
                    this.audioRendererController?.pauseRenderer();
                    this.isPlay = false;
                  } else {
                    this.audioRendererController?.startRenderer();
                    this.isPlay = true;
                  }
                }, 100);
              })
          }
          .width(28)
          .aspectRatio(1)
          .backgroundColor(Color.Transparent)
        }
        .height('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.End)
        .alignItems(VerticalAlign.Center)
      }
      .height('50%')

      Column() {
        Progress({ value: this.currentTime, total: info.size, type: ProgressType.Linear })
          .color('#0A59F7')
          .width('100%')
        Row() {
          Text(toTimeStr(this.currentTime))
            .maxLines(1)
            .fontSize(12.5)
            .fontWeight(400)
            .fontColor('rgba(0, 0, 0, 0.6)')

          Text(toTimeStr(info.size))
            .maxLines(1)
            .fontSize(12.5)
            .fontWeight(400)
            .fontColor('rgba(0, 0, 0, 0.6)')
        }
        .padding({ top: 8 })
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .padding({ top: 16 })
      .width('100%')
      .height('50%')
    }
    .width('100%')
    .height('100%')
    .borderRadius(14)
    .backgroundColor(Color.White)
    .padding(16)
  }

  @Builder
  deleteCard(index: number) {
    Row() {
      Button({ type: ButtonType.Circle }) {
        Image($r('app.media.trash'))
          .padding(5)
          .fillColor(Color.White)
      }
      .width(35)
      .aspectRatio(1)
      .backgroundColor(Color.Red)
      .onClick(() => {
        this.playerRelease().then(() => {
          let context: Context = this.getUIContext().getHostContext()!;
          let path: string = context.filesDir + `/${this.recordFiles[index].name}`;
          try {
            fs.unlinkSync(path);
          } catch (error) {
            Logger.error(TAG, `Unlink record file failed, path: ${path}, ${(error as BusinessError).message}`);
            return;
          }
          this.recordFiles.splice(index, 1);
        });
      })
    }
    .padding(10)
    .height('100%')
  }

  build() {
    Stack({
      alignContent: this.currentBreakpoint === BreakpointTypeEnum.LG ||
        this.currentBreakpoint === BreakpointTypeEnum.XL ? Alignment.End : Alignment.Bottom
    }) {
      Flex({ direction: FlexDirection.Column }) {
        Text($r('app.string.record_audio_base_on_audiocapturer'))
          .width('100%')
          .fontSize(30)
          .fontWeight(700)
          .lineHeight(40)
          .margin({
            top: new BreakpointType({
              xs: 8,
              sm: 44,
              md: 46,
              lg: 46,
              xl: 46
            }).getValue(this.currentBreakpoint)
          })
          .padding({
            left: new BreakpointType({
              xs: 16,
              sm: 16,
              md: 24,
              lg: 24,
              xl: 32
            }).getValue(this.currentBreakpoint),
            right: new BreakpointType({
              xs: 16,
              sm: 16,
              md: 24,
              lg: 24,
              xl: 32
            }).getValue(this.currentBreakpoint)
          })
          .textAlign(TextAlign.Start)

        List({ space: 8 }) {
          ForEach(
            this.recordFiles,
            (info: RecordFileInfo, index: number) => {
              ListItem() {
                this.listCard(info)
              }
              .height(120)
              .width('100%')
              .borderRadius(14)
              .swipeAction({
                end: {
                  builder: () => {
                    this.deleteCard(index)
                  }
                }
              })
            },
            (info: RecordFileInfo) => JSON.stringify(info)
          )
        }
        .width('100%')
        .height('100%')
        .layoutWeight(1)
        .contentEndOffset(10)
        .contentStartOffset(10)
        .padding({
          top: new BreakpointType({
            xs: 16,
            sm: 18,
            md: 18,
            lg: 18,
            xl: 42
          }).getValue(this.currentBreakpoint),
          left: new BreakpointType({
            xs: 16,
            sm: 16,
            md: 104,
            lg: 237,
            xl: 207
          }).getValue(this.currentBreakpoint),
          right: new BreakpointType({
            xs: 16,
            sm: 16,
            md: 104,
            lg: 237,
            xl: 207
          }).getValue(this.currentBreakpoint)
        })
      }
      .width('100%')
      .height('100%')

      Button({ type: ButtonType.Circle }) {
        Circle()
          .width(20)
          .aspectRatio(1)
          .fill(Color.White)
      }
      .width(56)
      .aspectRatio(1)
      .backgroundColor('#0A59F7')
      .margin({
        bottom: new BreakpointType({
          xs: 16,
          sm: 80,
          md: 80,
          lg: 0,
          xl: 0
        }).getValue(this.currentBreakpoint),
        right: new BreakpointType({
          xs: 0,
          sm: 0,
          md: 0,
          lg: 80,
          xl: 80
        }).getValue(this.currentBreakpoint)
      })
      .onClick(() => {
        isGlobalMicToggle(this.context as common.UIAbilityContext).then(() => {
          isMicrophoneMute().then((isMute) => {
            if (!isMute) {
              checkPermission(Constants.MICROPHONE_PERMISSION)
                .then((status: abilityAccessCtrl.GrantStatus) => {
                  if (status === abilityAccessCtrl.GrantStatus.PERMISSION_DENIED) {
                    openPermissionsSetting(this.context as common.UIAbilityContext, [Constants.MICROPHONE_PERMISSION])
                      .then(grantStatus => {
                        let isGranted: boolean = true;
                        for (let i = 0; i < grantStatus.length; i++) {
                          if (grantStatus[i] !== 0) {
                            isGranted = false;
                          }
                        }
                        if (isGranted) {
                          this.playerRelease();
                          this.isRecord = true;
                        }
                      });
                  } else {
                    this.playerRelease();
                    this.isRecord = true;
                  }
                })
                .catch((err: BusinessError) => {
                  Logger.error(TAG, `Check permission failed, ${JSON.stringify(err)}`);
                });
            }
          })
        })
      })
      .bindSheet($$this.isRecord, this.recordDialogBuilder(), {
        height: new BreakpointType({
          xs: 318,
          sm: 444,
          md: 472,
          lg: 472,
          xl: 472
        }).getValue(this.currentBreakpoint),
        preferType: SheetType.CENTER,
        showClose: false,
        dragBar: false,
        shouldDismiss: (() => {
          this.isRecord = true;
        }),
        backgroundColor: '#F1F3F5',
        onDisappear: (() => {
          this.loadAudioFiles();
        })
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background_color'))
  }
}