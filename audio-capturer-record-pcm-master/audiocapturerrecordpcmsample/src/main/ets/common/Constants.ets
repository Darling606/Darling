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

import { Permissions } from '@kit.AbilityKit';

export class Constants {
  public static MICROPHONE_PERMISSION: Permissions = 'ohos.permission.MICROPHONE';
  public static readonly KEY_PREFIX: string = 'AudioCapturerRecordPCM';
  public static readonly KEY_PREFIX_BREAKPOINT: string = Constants.KEY_PREFIX + 'CurrentBreakpoint';
  public static readonly KEY_PREFIX_CURRENT_TIME: string = Constants.KEY_PREFIX + 'CurrentTime';
}