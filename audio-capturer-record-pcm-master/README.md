# 基于AudioCapturer录制音频(ArkTS)

## 项目简介

本示例基于AudioCapturer(ArkTS)实现了音频PCM录制。AudioCapturer用于录制PCM（Pulse Code Modulation）音频数据，开发者可以基于本示例实现录制音频PCM，适用于实现更灵活的录制功能。

## 效果预览

| 手机                                                       | 折叠屏                                                         | 平板                                                             |
|----------------------------------------------------------|-------------------------------------------------------------|----------------------------------------------------------------|
| <img src="screenshots/devices/MainPage.png" alt="Index"> | <img src="screenshots/devices/MainPage_fold.png" alt="Get"> | <img src="screenshots/devices/MainPage_tablet.png" alt="Copy"> |

## 使用说明

1. 打开应用，点击录制按钮进行音频录制。
2. 完成录制后返回，点击音频进行播放。

## 工程目录

```
├──ets                                   // UI层
│  ├──common                             // 公共模块
│  │  └──Constants.ets                   // 参数常量
│  ├──components                  
│  │  └──RecordDialog.ets                // 录制弹窗页面
│  ├──controller                         // 控制模块
│  │  ├──AudioCapturerController.ets     // AudioCapturer音频采集类
│  │  └──AudioRendererController.ets     // AudioRenderer播放类
│  ├──entryability                       // 应用入口函数
│  │  └──EntryAbility.ets
│  ├──entrybackupability
│  │  └──EntryBackupAbility.ets
│  ├──model
│  │  └──RecordFileInfo.ets              // 录制文件实体
│  ├──pages
│  │  └──Index.ets                       // 首页
│  └──utils                              // 组件模块
│     ├──BackgroundTaskUtil.ets          // 后台任务工具类
│     ├──Logger.ets                      // 日志工具类
│     ├──PermissionUtil.ets              // 权限工具类
│     └──StringUtil.ets                  // 字符串工具类
├──resources                             // 静态资源文件
└──module.json5                          // 模块配置信息
```

## 具体实现

1. 在进入录制页面时，创建AudioCapturer对象。
2. 配置AudioCapturer，包括音频配置和回调函数。
3. 开启AudioCapturer，启动音频录制。
4. 点击完成录制后，结束录制。

## 相关权限

1. 允许应用使用麦克风：ohos.permission.MICROPHONE。
2. 允许应用申请特殊类型长时任务：ohos.permission.KEEP_BACKGROUND_RUNNING。

## 约束与限制

1. 本示例仅支持标准系统上运行，支持设备：直板机、双折叠（Mate X系列）、三折叠、阔折叠、平板、电脑。
2. HarmonyOS系统：HarmonyOS 6.0.2 Release及以上。
3. DevEco Studio版本：DevEco Studio 6.1.0 Release及以上。
4. HarmonyOS SDK版本：HarmonyOS 6.1.0 Release SDK及以上。