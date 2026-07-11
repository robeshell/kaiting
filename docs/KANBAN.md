# Sound Next 开发看板

最后更新：2026-07-11

本文件是开发顺序的唯一事实来源。**进行中**最多只能有一张卡；代码完成后
移入**待验证**；只有验收条件和相关平台构建全部通过，才能移入**已完成**。

## 当前焦点

**SND-301 — 实现 WebDAV 连接存储和发现**

播放状态已经在迷你播放器和正在播放页使用同一展示模型。下一步实现
WebDAV 连接的增删改查、安全凭据和 OPTIONS/PROPFIND 发现。

## 进行中

| 编号 | 优先级 | 卡片 | 验收标准 |
| --- | --- | --- | --- |
| SND-301 | P0 | 实现 WebDAV 连接存储和发现。 | 连接增删改查、安全凭据、OPTIONS/PROPFIND，以及明确的认证和网络错误。 |

## 接下来

| 编号 | 优先级 | 卡片 | 验收标准 | 依赖 |
| --- | --- | --- | --- | --- |
| SND-302 | P0 | 将 WebDAV 目录索引到共享资料库。 | 远程歌曲与本地歌曲使用相同领域模型；重扫与来源不可用行为确定。 | SND-301 |

## 待验证

| 编号 | 已通过 | 待完成 |
| --- | --- | --- |
| SND-202 | 八种引擎 phase 使用一个 `PlaybackVisualState` 映射；迷你播放器和正在播放页对 loading、buffering、paused、completed、error 的文案与语义组件测试一致；buffering 保留 play-when-ready，可暂停；loading 禁用主操作；completed 从零重播；error 可重新 load，并展示可重试错误横幅。 | macOS 与 Android 使用真实本地/限速远程音频观察 loading、buffering、暂停、完成和错误视觉；iPhone/iPad 与 Windows 随对应平台回归验证。 |
| SND-201 | 23 个 session 测试覆盖安全 JSON 往返、歌词、存取/清理/损坏容错、controller 恢复队列/索引且不加载 engine、恢复后 toggle、先 seek 后 play、resume 一次性消费、index 钳制和持久化隔离；组件测试证明恢复曲目和进度可见但不自动播放、连续播放每 2 秒 checkpoint、进入后台立即 flush。应用先完成 session bootstrap 再创建唯一 controller；原生写 app documents，开发 Web 使用无文件系统内存降级；认证 header 不进入会话文件。 | macOS 真机重启验证：播放中退出 → 重启恢复队列/位置但不自动播放 → 按播放从恢复位置开始；Android ARM64 同条件回归。 |
| SND-105 | 40 个控制器测试覆盖播放、暂停、seek、上一首（>=4s 重播 + <4s 切歌）、下一首（含循环）、完成自动切歌、重复完成事件去重、队列位置竞态保护、旧 session 完成事件拒绝、真实重叠 load 的 generation 隔离、队列替换、toggle 空闲启动和空队列处理；playTrack 在 queue 不含 track 时退回单曲队列。 | macOS 用真实已扫描目录做队列操作回归（切歌/完成/seek/mini player 状态）；Android ARM64 模拟器同条件回归。 |
| SND-104 | Repository 记录到界面模型的元数据、封面、媒体 URI 和歌词映射测试通过；资料库的加载、空状态和真实歌曲点击播放组件测试通过；产品 `lib/` 不再包含演示专辑、歌词、NAS 或播放列表。 | Android 和 macOS 用真实已扫描目录回归资料库、专辑详情、封面和点击播放；Windows 与 iPhone/iPad 随 SND-102/103 一起验证。 |
| SND-102 | Android 16 ARM64：SAF 选择 `Music` 后强制停止并重启，仍恢复为”已授权”；macOS：NSOpenPanel 选择 `Music`、保存 bookmark、退出并重启后恢复为 `available`；iOS/iPadOS Universal target 已接入系统文件夹选择器与 bookmark，Swift 使用 iOS 13 SDK 类型检查通过。 | Windows 主机验证选择/重启/目录失效；安装可用的 iOS Platform 或连接 iPhone/iPad，验证 Files 文件夹选择、退出重启和 bookmark 恢复。 |
| SND-103 | 真实 MP3/FLAC fixture 的标题、艺人、专辑、曲序、时长、封面和歌词解析测试通过；损坏文件会跳过；Android 16 SAF 实测首次索引 2 首，删除 MP3 后重扫原子收敛为 1 首，扫描版本 1 → 2。 | Windows 验证文件系统目录扫描；iPhone/iPad 验证 Files/iCloud 文件夹扫描；macOS 用真实用户目录做最终 UI 回归。 |

## 阻塞

| 编号 | 优先级 | 卡片 | 阻塞原因 | 解除方式 |
| --- | --- | --- | --- | --- |
| SND-401 | P0 | 在 Windows 验证本地与认证 WebDAV 播放。 | 当前 macOS 主机不能运行 Windows 构建和 WinRT 播放器。 | 在 Windows 机器执行既定播放矩阵，记录 Range、seek 和系统媒体控制结果。 |

## 后续队列

按从上到下的顺序执行。

| 编号 | 优先级 | 卡片 | 验收摘要 |
| --- | --- | --- | --- |
| SND-303 | P0 | 增加 WebDAV 缓存和无索引 MP3 兜底。 | 缓存有可配置上限且不会无限增长；无法精确远程 seek 时行为明确。 |
| SND-402 | P0 | Android 后台播放和通知控制。 | 熄屏后继续播放；元数据和播放/暂停/上下一首保持同步。 |
| SND-403 | P0 | Windows 系统媒体控制。 | SMTC 元数据和控制动作与队列、播放器保持同步。 |
| SND-404 | P0 | iPhone/iPad 后台播放和系统媒体控制。 | 锁屏或切到后台后继续播放；锁屏界面、控制中心和耳机控制与队列保持同步。 |
| SND-405 | P0 | iPhone/iPad 自适应布局与 Files 回归。 | iPhone 竖横屏和 iPad 分屏/全屏布局可用；Files/iCloud 文件夹授权、扫描、重启恢复通过。 |
| SND-501 | P1 | 搜索和资料库筛选。 | 可按标题、专辑、艺人和流派搜索，且不会阻塞 UI。 |
| SND-502 | P1 | 大资料库性能验证。 | 记录 1,000 和 10,000 首的扫描时间与内存；滚动和播放保持流畅。 |
| SND-503 | P1 | 生产级错误恢复和诊断。 | 可重试错误、离线来源、损坏音频和凭据过期均有可操作状态。 |
| SND-601 | P2 | 播放列表编辑、收藏和更多视觉细节。 | 只有通过下方第一版门槛后才能开始。 |

## 已完成

| 编号 | 结果 |
| --- | --- |
| SND-001 | 使用 Flutter 重建资料库、专辑、正在播放、来源设置和响应式迷你播放器，并保留原设计语言。 |
| SND-002 | 建立以 `PlaybackEngine` snapshot 为唯一进度来源的架构，包括 session generation 和旧进度保护。 |
| SND-003 | 生产播放统一使用 `just_audio`，移除 MediaKit 与 macOS CocoaPods。 |
| SND-004 | 在 macOS 和 Android 16 ARM64 验证最终代码的本地 MP3/FLAC、认证 WebDAV MP3/FLAC 和 120 秒 seek。 |
| SND-005 | 建立可重复的认证、限速、支持 Range 的 WebDAV fixture 和测试。 |
| SND-006 | 下移移动端迷你播放器，并处理 Android 冷启动零尺寸视口。 |
| SND-101 | 建立 Drift/SQLite v1 资料库、跨平台数据库入口、schema 快照、稳定文本 ID、UTC 时间边界和原子整批扫描事务；持久化重开与失败回滚测试通过。 |

## 第一版门槛

开始更大范围的视觉或播放列表工作前，以下项目必须全部完成：

- 一个真实本地 MP3 和 FLAC 可在 Android、Windows、iPhone 和 iPad 被索引、持久化、展示和播放。
- 认证 WebDAV 索引与 Range 播放在 Android、Windows、iPhone 和 iPad 通过。
- 队列切换和保存进度不会造成进度回退。
- Android、iPhone/iPad 后台控制与 Windows 系统媒体控制保持同步。
- 目录权限撤销、服务器不可用、凭据错误和音频损坏均有明确恢复状态。

相关证据：[播放验证](PLAYBACK_VALIDATION.md)；[架构](ARCHITECTURE.md)。
