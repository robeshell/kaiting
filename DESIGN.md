---
version: "0.1.1"
name: kaiting
description: "Kaiting (开听) — a quiet desktop-class music player. Covers and lyrics are the protagonists; immersive pages may tint from artwork, chrome always follows skin tokens. Brand-layer rules live in kai-brand-design; this file is the product overlay."
colors:
  accent: "#FF5A4D"
  accentHover: "#FF7567"
  accentPressed: "#E3483E"
  sourceWebDav: "#5E8BFF"
  sourceLocal: "#55B889"
  # 中性色/玻璃/文字三档全部继承品牌层皮肤 token，本文件不重复定义
typography:
  nowPlayingTitle: { size: 27, weight: 800, tracking: -0.55 }
  heroArtist: { size: 15, weight: 600, color: secondary }
  lyricsLine: { size: "20-22", weight: "current 800 / others 700", tracking: 0 }
  # 其余层级继承品牌层（w800 封顶、负字距三档、0.5 字号网格）
rounded:
  cover: 14
  miniPlayer: { compact: 14, desktop: 18 }
  # 其余继承品牌层 control 10 / menu 12 / card 14 / sheet 18 / dialog 20
components:
  prefix: "Sound*"
  nowPlayingWide: { paneRatio: "1:1", paneGap: 48, gutter: 44, foldable: "<780: 24/24" }
  nowPlayingArt: { classic: 340, vinyl: 440, foldableVinyl: 360, align: "水平居中" }
  vinyl: { discCenter: "(0.5, 0.58)", armPivot: "(0.5, 0.02)", labelRadius: "x0.66", outerRadius: "x0.94" }
  miniPlayer: { surface: "GlassSurface strong", retryColor: error }
  queueSheet: { maxWidth: 760, radiusTop: 18, handle: "38x4" }
  errorBanner: { surface: "GlassSurface strong", radius: 12 }
---

# Kaiting (开听) Design

## Overview

安静的桌面级音乐播放器。界面退后，封面与歌词是主角；沉浸页（正在播放、专辑/艺人详情）允许从封面取色做氛围背景与 hero 控件（内容层扩展，已登记），**chrome 始终走皮肤 token**。

**Key Characteristics:**

- **事实源**：[`kai-brand-design`](https://github.com/robeshell/kai-brand-design) 品牌层 + `products/kaiting/`。改设计先改规范仓库，再回本仓库落地。
- **组件前缀 `Sound*`**：主题层 `lib/core/sound_theme.dart`，组件 kit `lib/presentation/widgets/sound_components.dart`，设置 kit `widgets/settings_components.dart`。
- **无状态徽章**：播放相位由传输按钮图标 + busy spinner 表达（映射表见 kai-brand-design `products/kaiting/tokens.md`），不渲染相位徽章。

## Colors

### Accent（产品轴：coral 珊瑚）

- **accent** `#FF5A4D` / hover `#FF7567` / pressed `#E3483E`；6 预设（玫瑰/靛蓝/青绿/暖金/紫罗兰）+ 自定义（hover=lerp白 14%、pressed=lerp黑 13%）。
- 只用于选中/进度/主操作：当前队列项、进度条、主传输按钮、选中导航。**展示文字（曲名、hero 标题、歌词）不染 accent。**

### Product Tokens

- **sourceWebDav** `#5E8BFF` / **sourceLocal** `#55B889` — 来源身份色（图标、筛选 chip、来源设置就绪态；兼任就绪语义已登记 divergence D2）。
- 状态色：错误 `context.soundColors.error`；警告 `context.soundWarning`（认证失败等）。禁止 `Colors.orangeAccent/redAccent`。

### Text & Palette

- 文字三档 `context.soundPrimaryText / soundSecondaryText / soundMutedText`；禁用 secondary@0.38；hairline 直接用 `soundDivider` 不衰减。
- 封面取色 palette 只影响氛围背景与 hero 控件（内容层），不改变 chrome token。

## Typography

### Hierarchy（产品增量；壳层继承品牌层）

| Token | Size | Weight | Tracking | Use |
|---|---|---|---|---|
| nowPlayingTitle | 27 | 800 | −0.55 | 正在播放曲名 |
| heroArtist | 15 | 600 | 0 | hero 艺人名（secondary；历史 28 w800 accent 已收敛） |
| lyricsLine | 20–22 | 当前行 800 / 其余 700 | 0 | 歌词行 |
| compactLyricsHeader | 18 | 800 | −0.25 | 移动歌词面板头 |

### Principles

- w800 封顶，禁 w900；负字距只取 −0.8/−0.55/−0.25 三档；0.5 字号网格。
- 歌词行强调靠字重对比，不靠颜色或字号跳变；时间标签 11.5 + tabular figures。

## Layout

- 正在播放桌面双栏 1:1：栏距 48、页边距 44（折叠 <780 收 24/24），封面 classic ≤340 / 黑胶 ≤440（折叠 360），**封面/黑胶在播放列内水平居中**，列内其余元素 start 对齐。
- 移动单栏滚动：列限宽 黑胶 440 / classic 430 居中；黑胶尺寸 min(屏宽−32, 屏高×0.52) clamp 260–420。
- 侧栏选中 = accent@0.10 胶囊 r10（品牌导航锚点）；底栏 56 玻璃。

## Elevation & Depth

- 浮面（迷你播放器、队列、音量弹层、错误横幅）= GlassSurface strong + hairline + token 阴影 ×shadowScale + 模糊；封面 ≥96px 才投影（blur 10 ×shadowScale，偏移 y3）。
- 重复行/卡片不模糊；纯净皮肤自动免模糊免影。

## Shapes

- 封面 r14（card 档，不允许另设）；迷你播放器 r14（移动）/ r18（桌面 dock）；音量弹层、错误横幅 r12（menu 档）。
- 黑胶是内容层拟物造型，不参与圆角阶梯（产品规范登记）。

## Components

- **`vinyl-record`** — 黑胶方块内部比例：盘心 (0.5, 0.58)、唱臂支点 (0.5, 0.02)、标签（封面）半径 ×0.66 圆形无圆角、盘外沿 ×0.94；播放旋转，reduced motion 静止。
- **`mini-player`** — strong 玻璃 dock；进度可交互（点击/拖动 seek）accent；错误重试边框/图标 error 色；音量弹层 strongSurface + r12 + token 阴影。
- **`queue-sheet`** — 品牌 sheet（r18 顶角、把手、760）；当前曲目 = accent 频谱图标 + accent 标题，序号 muted；行尾 drag handle muted。
- **`error-banner`** — strong 玻璃 + r12，错误图标 + 失败曲目名 + 重试钮；不用透明边框/纯色块。
- **`source-row`** — 来源设置行入分组卡；状态色语义化（就绪=来源色、认证失败=warning、错误=error）。
- 通用组件（SoundListRow / SoundChoiceStrip / SoundSwitch / SoundDialog / SoundMenuButton / SoundEmptyState / showSoundSnackBar / SoundSettingsGroup）锚点全部继承品牌层，不再重复。

## Do's and Don'ts

### Do

- 新组件先查 kit，没有再按品牌层组件规范造，并回提规范仓库。
- 相位/错误用 `PlaybackVisualState` 映射与 error 色；提示用 `showSoundSnackBar`；空态用 `SoundEmptyState`（含行动钮）。

### Don't

- 不硬编码颜色/圆角/alpha（包括"临时"衰减）；不给展示文字染 accent；不渲染播放状态徽章。
- 不用 `Switch.adaptive`；不给黑胶/封面临时换圆角档。
- 艺人名/元信息不做展示层级——壳层三档解决。

## Responsive Behavior

- 壳切换继承品牌窗口分级；正在播放 <780 折叠态双栏改顶部对齐、黑胶降 360。
- 移动端选择器（播放模式、睡眠定时）落 CompactSettingsSheet；桌面行内展开直接放进分组卡。

## Iteration Guide

1. 样式改动先判归属：通用 → kai-brand-design 品牌层；开听特有 → `products/kaiting/`；然后再改代码。
2. 黑胶参数、双栏 metrics 是产品 token——改型先改 `products/kaiting/patterns/now-playing.md`。
3. 发现 kit 缺口 → 回提品牌层（第二产品可能需要），不在本地造私有组件。

## Known Gaps

- 资料库网格卡片 hover 反馈与信息区未规范（审计候选，未立项）。
- 桌面双栏 ≥1600 超宽窗比例待评估（封面列上限可能偏小）。
- 图标尺寸档未成文（品牌层 Known Gaps 同源）。

## Agent Prompt Guide

- 改 UI 前读本文件 + kai-brand-design `DESIGN.md`；数值以 kai-brand-design `tokens/*.json` 与 `products/kaiting/` 为准。
- 快速定位：主题 token `lib/core/sound_theme.dart`；组件 kit `lib/presentation/widgets/sound_components.dart`；正在播放 `screens/now_playing_screen.dart` + `widgets/vinyl_record_art.dart`、`mini_player.dart`、`playback_queue_sheet.dart`。
- 验收：`flutter analyze` 零告警；`flutter test` 全绿（存量失败见仓库文档，不得新增）。
