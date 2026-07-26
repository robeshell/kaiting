# 开听 路线图

最后更新：2026-07-26

任务细节以 [GitHub Project](https://github.com/users/robeshell/projects/2) 为准。本文件只保留能力地图与仍开放项。

## 能力地图

| 能力域 | 已有 | 仍开放 |
| --- | --- | --- |
| 平台 | 四端播放；Android/iOS 后台媒体；应用内更新 | Windows SMTC；真机 Files / 通知矩阵 |
| 播放 | 模式、队列、无缝（非 Web）、会话、睡眠定时 | 淡入淡出、ReplayGain、均衡器 |
| 资料库 | 扫描/增量、搜索拼音、收藏/历史/歌单、多碟 | 智能歌单、元数据编辑、备份恢复 |
| 网络 | WebDAV Range、离线下载、诊断与重试 | 第二协议；用户状态云同步（**暂不做**） |
| 体验 | 浅色玻璃 UI、桌面快捷键、首次引导 | 无障碍、正式本地化 |
| 工程 | `release.dart`、测试、Pages | 开源许可、完整签名与视觉 CI |

## 阶段

| 阶段 | 状态（相对 1.0.8） |
| --- | --- |
| M1 核心可用 | 基本完成 |
| M2 跨平台 Beta | 进行中（Windows SMTC / 真机验收） |
| M3 性能与可靠性 | 部分完成（有基准；缺备份与真机资源） |
| M4 体验增强 | 未开始 |

## 近期优先

1. Windows SMTC 与格式矩阵（阻塞跨平台 Beta 关单）
2. 资料库备份 / 恢复（SND-507）
3. 真机抽检：后台、通知、WebDAV 弱网

证据与格式细节见 [ARCHITECTURE.md](./ARCHITECTURE.md)、[AUDIO_FORMAT_MATRIX.md](./AUDIO_FORMAT_MATRIX.md)；性能微基准见 [../benchmark/README.md](../benchmark/README.md)。
