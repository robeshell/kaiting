# 开听

本地与 WebDAV 音乐播放器。封面与歌词优先，界面克制。

Flutter · 当前版本 **1.0.8** · 包名 `com.kaiting.player`

| | |
|---|---|
| 下载 | [GitHub Releases](https://github.com/robeshell/kaiting/releases) |
| 官网 | [robeshell.github.io/kaiting](https://robeshell.github.io/kaiting/) |
| 仓库 | [github.com/robeshell/kaiting](https://github.com/robeshell/kaiting) |
| 更新日志 | [CHANGELOG.md](CHANGELOG.md) |
| 文档索引 | [docs/README.md](docs/README.md) |
| 设计 | [DESIGN.md](DESIGN.md) · [`kai-brand-design`](https://github.com/robeshell/kai-brand-design) |
| 架构 / 路线图 | [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) · [docs/ROADMAP.md](docs/ROADMAP.md) |

## 平台

| 平台 | 状态 |
|------|------|
| Android | 支持 |
| iOS / iPadOS | 支持 |
| macOS | 支持 |
| Windows | 支持（系统媒体控制尚未接） |
| Web | 预览（自动连播，不承诺无缝） |
| Linux | 脚手架 |

## 功能

- **资料库** — 专辑 / 艺人 / 流派 / 歌曲；收藏、历史、播放列表
- **来源** — 本地目录；带认证的 WebDAV（Range 寻址）
- **扫描** — 发行分组、多碟专辑、增量与感知删除的重扫
- **搜索** — 中文拼音 / 首字母；艺人与专辑分区
- **播放** — 无缝切歌（非 Web）、队列编辑、播放模式、会话恢复（不自动续播）
- **离线** — 专辑 / 单曲固定下载；临时缓存与离线用量可在设置中管理
- **歌词** — 进度同步；重启后从资料库补全
- **工具** — 睡眠定时；桌面全局快捷键
- **界面** — 经典 / 黑胶正在播放；强调色与皮肤
- **更新** — 设置 → 关于 → 检查更新；启动后静默检查（有新版本才提示）

## 开发

```sh
flutter pub get
flutter run -d macos   # 或 chrome / windows / <device-id>
```

应用内：**设置 →** 添加本地或 WebDAV 来源 → 扫描 → 从资料库播放。

macOS 钥匙串与签名需要开发证书，请先在 Xcode 登录开发者账号。

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

## 发布

不要直接 `flutter build … --release` 出货。版本以 `pubspec.yaml` 为准，用仓库脚本：

```sh
dart run tool/release.dart --dry-run
dart run tool/release.dart android
dart run tool/release.dart android macos web
dart run tool/release.dart windows
dart run tool/release.dart android --no-bump
```

产物在 `dist/`。Windows 安装包说明见 [`packaging/windows/README.md`](packaging/windows/README.md)。

官网 Pages：

```sh
flutter build web --release --base-href /kaiting/app/
bash tool/build_pages.sh
```

## 许可

仓库尚未放置开源许可证文件；在另行声明前保留所有权利。
