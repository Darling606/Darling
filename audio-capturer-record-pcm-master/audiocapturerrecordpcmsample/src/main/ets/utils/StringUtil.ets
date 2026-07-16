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

export function toStr(value: number): string {
  return value >= 10 ? value.toString() : '0' + value;
}

export function toDateStr(mtime: number): string {
  let date: Date = new Date(mtime * 1000);
  let years: number = date.getFullYear();
  let month: number = date.getMonth() + 1;
  let day: number = date.getDate();
  let hours: number = date.getHours();
  let minutes: number = date.getMinutes();
  return `${toStr(years)}/${toStr(month)}/${(toStr(day))}  ${toStr(hours)}:${toStr(minutes)}`;
}

export function toTimeStr(size: number): string {
  let duration: number = Math.round(size / (48000 * 2 * 1));
  return secToTimeStr(duration);
}

export function secToTimeStr(duration: number): string {
  let seconds: number = Math.floor(duration % 60);
  let minutes: number = Math.floor(duration / 60) % 60;
  let hours: number = Math.floor(duration / 3600);
  return `${toStr(hours)}:${toStr(minutes)}:${toStr(seconds)}`;
}

export function sizeToTime(size: number): number {
  return Math.round(size / (48000 * 2 * 1));
}