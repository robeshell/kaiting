# 测试布局

测试目录镜像 `lib/` 模块边界，方便按领域定位；`flutter test` 仍会递归跑全部用例。

| 目录 | 对应代码 | 内容 |
| --- | --- | --- |
| `app/` | `lib/app/` | 主题偏好等启动/壳层 |
| `core/` | `lib/core/` | 失败模型、主题 token |
| `library/` | `lib/library/` | 资料库、扫描、SQLite |
| `sources/local/` | `lib/sources/local/` | 本地源与协议注册 |
| `sources/webdav/` | `lib/sources/webdav/` | WebDAV 连接、扫描、缓存 |
| `playback/` | `lib/playback/` | 播放控制、会话、系统媒体 |
| `offline/` | `lib/offline/` + 离线 UI | 下载队列与设置页 |
| `presentation/` | `lib/presentation/` | 组件、屏幕、壳层集成 |

```sh
# 全量
flutter test

# 按模块
flutter test test/library
flutter test test/playback
flutter test test/sources/webdav
```

性能微基准不在这里，见 [`../benchmark/`](../benchmark/)。
