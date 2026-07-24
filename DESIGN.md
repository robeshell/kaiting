# DESIGN.md — 开听（kaiting）

> AI 代理入口：本文件给出开听的视觉要点。**事实源**：[`kai-brand-design`](https://github.com/robeshell/kai-brand-design) 品牌层（通用 token/组件/模式）+ `products/kaiting/`（本产品规范）。改设计先改规范仓库，再回本仓库落地。

## 视觉主题

安静的桌面级音乐播放器：界面退后，封面与歌词是主角。沉浸页（正在播放、专辑详情）允许封面取色氛围，chrome 始终走皮肤 token。

## L0（产品轴）

- **强调色**：coral 珊瑚 `#FF5A4D`（hover `#FF7567` / pressed `#E3483E`），6 预设 + 自定义（hover=lerp白14%、pressed=lerp黑13%）。
- **组件前缀**：`Sound*`；主题层 `lib/core/sound_theme.dart`，组件 kit `lib/presentation/widgets/sound_components.dart`，设置 kit `widgets/settings_components.dart`。
- **内容层扩展点**：正在播放样式（classic 方封面 / vinyl 黑胶）；封面取色 palette（详情页氛围与 hero 控件）。
- **产品级 token**：来源色 WebDAV `#5E8BFF` / 本地 `#55B889`；播放相位→传输按钮映射（无状态徽章）。

## 关键落地（与品牌层锚点一致）

- 圆角 control 10 / menu 12 / card 14（封面同）/ sheet 18 / dialog 20 / pill 999；对话框 520；弹层 760（选项列表 560）；菜单 r12 宽 252。
- 文字三档 `context.soundPrimaryText / soundSecondaryText / soundMutedText`；禁用 secondary@0.38；hairline 直接用 `soundDivider` 不衰减。
- 排版 w800 封顶（禁 w900）；页标题 26/28（−0.55）；行标题 13.5 w600；副题 11.5；底栏标签 10.5。
- 侧栏选中 = accent 10% 胶囊 r10；开关用 `SoundSwitch`（禁 `Switch.adaptive`）；提示用 `showSoundSnackBar`；空态 `SoundEmptyState`；设置分组 `SoundSettingsGroup`。
- 状态色：错误 `context.soundColors.error`；警告 `context.soundWarning`。

## 正在播放（沉浸页，详见 kai-brand-design `products/kaiting/patterns/now-playing.md`）

- 桌面双栏 1:1（栏距 48，页边距 44，折叠 <780 收 24）；封面 classic ≤340 / 黑胶 ≤440，列内水平居中。
- 移动单栏：黑胶 min(屏宽−32, 屏高×0.52) clamp 260–420；曲名 27 w800（−0.55）。
- 黑胶内部比例：盘心 (0.5, 0.58)、支点 (0.5, 0.02)、标签半径 ×0.66、外沿 ×0.94。
- 迷你播放器：GlassSurface strong，r14（移动）/18（桌面）；错误重试用 error 色；队列走品牌 sheet（r18、把手、760）。

## Do's and Don'ts

- ❌ 不硬编码颜色/圆角/alpha；不用 accent 写展示文字（曲名、hero 标题、歌词）；不渲染播放状态徽章。
- ❌ 艺人名/元信息不做展示层级：hero 艺人名定档 15 w600 secondary（历史 28 w800 accent 已收敛）。
- ✅ 新组件先看 kit 有没有（SoundListRow/SoundChoiceStrip/SoundMenuButton/SoundDialog…），没有再按品牌层组件规范造，并回提规范。
