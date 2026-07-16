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

import { display, window } from '@kit.ArkUI';
import { Constants } from '../common/Constants';
import { Logger } from './Logger';

const TAG: string = '[BreakpointSystem]';

export enum BreakpointTypeEnum {
  XS = 'xs',
  SM = 'sm',
  MD = 'md',
  LG = 'lg',
  XL = 'xl'
}

export interface BreakpointTypes<T> {
  xs?: T;
  sm: T;
  md: T;
  lg: T;
  xl?: T;
}

export class BreakpointType<T> {
  private xs: T;
  private sm: T;
  private md: T;
  private lg: T;
  private xl: T;

  public constructor(param: BreakpointTypes<T>) {
    this.xs = param.xs ?? param.sm;
    this.sm = param.sm;
    this.md = param.md;
    this.lg = param.lg;
    this.xl = param.xl ?? param.lg;
  }

  public getValue(currentBreakpoint: string): T {
    if (currentBreakpoint === BreakpointTypeEnum.XS) {
      return this.xs;
    }
    if (currentBreakpoint === BreakpointTypeEnum.SM) {
      return this.sm;
    }
    if (currentBreakpoint === BreakpointTypeEnum.MD) {
      return this.md;
    }
    if (currentBreakpoint === BreakpointTypeEnum.XL) {
      return this.xl;
    }
    return this.lg;
  }
}

export class BreakpointSystem {
  private static instance: BreakpointSystem;
  private currentBreakpoint: BreakpointTypeEnum = BreakpointTypeEnum.MD;

  public static getInstance(): BreakpointSystem {
    if (!BreakpointSystem.instance) {
      BreakpointSystem.instance = new BreakpointSystem();
    }
    return BreakpointSystem.instance;
  }

  public updateCurrentBreakpoint(breakpoint: BreakpointTypeEnum): void {
    this.currentBreakpoint = breakpoint;
    AppStorage.setOrCreate(Constants.KEY_PREFIX_BREAKPOINT, this.currentBreakpoint);
  }

  public updateWidthBreakpoint(windowSize: window.Size): void {
    try {
      const windowWidthVp = windowSize.width / display.getDefaultDisplaySync().densityPixels;
      let widthBreakpoint: BreakpointTypeEnum = BreakpointTypeEnum.MD;
      if (windowWidthVp < 330) {
        widthBreakpoint = BreakpointTypeEnum.XS;
      } else if (windowWidthVp >= 330 && windowWidthVp < 600) {
        widthBreakpoint = BreakpointTypeEnum.SM;
      } else if (windowWidthVp >= 600 && windowWidthVp < 840) {
        widthBreakpoint = BreakpointTypeEnum.MD;
      } else if (windowWidthVp >= 840 && windowWidthVp < 1440) {
        widthBreakpoint = BreakpointTypeEnum.LG;
      } else {
        widthBreakpoint = BreakpointTypeEnum.XL;
      }
      this.updateCurrentBreakpoint(widthBreakpoint);
    } catch (error) {
      Logger.error(TAG, `Update Breakpoint fail, error: ${error}`);
    }
  }
}