# 开听

**开听** is a clean, artwork-first music player for local folders and WebDAV libraries.  
**开听** 是一款简洁、以封面为先的音乐播放器，支持本地文件夹与 WebDAV 曲库。

Built with [Flutter](https://flutter.dev). Current version: **1.0.4**.

| | |
|---|---|
| **Download · 下载** | [GitHub Releases](https://github.com/robeshell/kaiting/releases) |
| **Website · 官网** | [robeshell.github.io/kaiting](https://robeshell.github.io/kaiting/) |
| **Changelog · 更新日志** | [CHANGELOG.md](CHANGELOG.md) |
| **Repository · 仓库** | [github.com/robeshell/kaiting](https://github.com/robeshell/kaiting) |

## Platforms · 平台

| Platform | Status |
|----------|--------|
| Android | Supported |
| iOS / iPadOS | Supported |
| macOS | Supported |
| Windows | Supported |
| Web | Preview |
| Linux | Scaffold only |

## Features · 功能

- **Library** — albums, artists, genres, songs; favorites, history, and editable playlists  
  **资料库** — 专辑 / 艺人 / 流派 / 歌曲；收藏、历史、可编辑播放列表
- **Sources** — local folders and authenticated WebDAV with range seeking  
  **来源** — 本地目录与带认证的 WebDAV（支持 Range 寻址）
- **Scanning** — shared release grouping, multi-disc albums, incremental and deletion-aware rescan  
  **扫描** — 发行分组、多碟专辑、增量扫描与感知删除的重扫
- **Search** — pinyin / initials for Chinese titles, artist & album sections, match-scope filters  
  **搜索** — 中文拼音 / 首字母、艺人与专辑分区、匹配范围筛选
- **Playback** — gapless transitions, queue editing, modes (order / loop / shuffle), session restore  
  **播放** — 无缝切歌、队列编辑、播放模式、会话位置恢复（不自动续播）
- **Lyrics** — synchronized lyrics; catalog rehydration after restart  
  **歌词** — 进度同步；重启后从资料库补全队列歌词
- **UI** — classic or vinyl now-playing; accent colors and skins; desktop shortcuts  
  **界面** — 经典 / 黑胶播放页；强调色与皮肤；桌面快捷键
- **Navigation** — tappable artist and album names across library, search, player, and queue  
  **导航** — 资料库 / 搜索 / 播放页 / 队列中艺人与专辑可点进

## Download · 安装

Prebuilt packages are published on [Releases](https://github.com/robeshell/kaiting/releases).

| Asset | Use |
|-------|-----|
| `kaiting-x.y.z-android.apk` | Android sideload |
| `kaiting-x.y.z-android.aab` | Play Console |
| `kaiting-x.y.z-windows.zip` | Portable Windows |
| `kaiting-x.y.z-windows.msix` | Windows modern install |
| `kaiting-x.y.z-windows-setup.exe` | Windows classic installer |

See [CHANGELOG.md](CHANGELOG.md) for what changed in each version.

## Development · 开发

### Requirements · 环境

- Flutter stable (SDK constraint: see `pubspec.yaml`)
- Platform toolchains for targets you build (Xcode, Android SDK, etc.)

### Run · 运行

```sh
flutter pub get
flutter run -d macos   # or chrome / windows / <device-id>
```

In the app: **Settings →** add a local folder or WebDAV source → scan → play from the library.

> **macOS:** Keychain / signing needs a development-signed app. Sign in with an Apple developer account in Xcode first.  
> **macOS：** 钥匙串与签名需要开发证书，请先在 Xcode 登录开发者账号。

### Verify · 验证

```sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
```

Optional debug builds:

```sh
flutter build macos --debug
flutter build apk --debug
flutter build web
flutter build ios --simulator --debug
```

## Release packaging · 发布打包

Do **not** call `flutter build … --release` directly for shipping artifacts.  
正式发版请使用仓库脚本，不要直接 `flutter build … --release`。

`pubspec.yaml` is the single version source: `MAJOR.MINOR.PATCH` is user-facing; `+build` is internal.

```sh
# Preview next version (no file changes)
dart run tool/release.dart --dry-run

# Bump patch once, build selected targets, write dist/
dart run tool/release.dart android
dart run tool/release.dart android macos web
dart run tool/release.dart windows

# Rebuild current version without bumping
dart run tool/release.dart android --no-bump
```

Outputs land in `dist/` (e.g. `kaiting-1.0.4-android.apk`). On build failure with bump, `pubspec.yaml` is rolled back.

### Windows installers

| File | Kind |
|------|------|
| `kaiting-x.y.z-windows.zip` | Portable |
| `kaiting-x.y.z-windows.msix` | MSIX |
| `kaiting-x.y.z-windows-setup.exe` | Inno Setup |

Setup.exe needs [Inno Setup 6](https://jrsoftware.org/isinfo.php):

```powershell
winget install --id JRSoftware.InnoSetup -e --accept-package-agreements
```

Details: [`packaging/windows/README.md`](packaging/windows/README.md).

## Website · 网站

GitHub Pages: [robeshell.github.io/kaiting](https://robeshell.github.io/kaiting/)  
Flutter Web app path: `/kaiting/app/`.

```sh
flutter build web --release --base-href /kaiting/app/
bash tool/build_pages.sh
```

## Documentation · 文档

| Doc | Description |
|-----|-------------|
| [CHANGELOG.md](CHANGELOG.md) | Version history · 更新日志 |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Architecture · 架构 |
| [docs/DESIGN_FOUNDATION.md](docs/DESIGN_FOUNDATION.md) | Design foundation · 设计基础 |

设计规范已迁至独立仓库 [`kai-brand-design`](../../kai-brand-design)（品牌层 + 产品层 `products/kaiting/`）；本仓库只保留实现侧文档。
| [docs/KANBAN.md](docs/KANBAN.md) | Development kanban · 开发看板 |
| [docs/PLAYBACK_VALIDATION.md](docs/PLAYBACK_VALIDATION.md) | Playback validation · 播放验证 |
| [docs/AUDIO_FORMAT_MATRIX.md](docs/AUDIO_FORMAT_MATRIX.md) | Format matrix · 音频格式 |
| [docs/WEBDAV_FIXTURE.md](docs/WEBDAV_FIXTURE.md) | WebDAV test fixture · 测试夹具 |

More design notes live under [`docs/`](docs/).

## License · 许可

No license file is published in this repository yet. All rights reserved unless stated otherwise.  
仓库尚未放置开源许可证文件；在另行声明前保留所有权利。
