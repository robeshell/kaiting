import 'package:flutter/material.dart';

import '../../core/brand_tokens.g.dart';
import '../../core/sound_theme.dart';

abstract final class SoundSettingsMetrics {
  static const maxContentWidth = KaiBrandLayout.standardContentWidth;
  static const sectionGap = KaiBrandDesktopMetrics.sectionGap;

  static double rowMinHeight(BuildContext context) =>
      context.soundComponentProfile.listRowSingle;
}

extension SoundSettingsContext on BuildContext {
  Color get settingsPrimary => soundPrimaryText;
  Color get settingsSecondary => soundSecondaryText;
  Color get settingsMuted => soundMutedText;
  Color get settingsHairline => soundDivider;

  /// 卡内行间分隔线：极淡，只暗示行的边界。
  Color get settingsRowDivider => soundTheme.brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);
  Color get settingsInlineSurface =>
      soundColors.surfaceContainerLow.withValues(alpha: 0.72);
  /// 设置画布：比主画布再浅灰一点，纯白分组卡自然分层（无边框无阴影）。
  Color get settingsCanvas => soundTheme.brightness == Brightness.dark
      ? soundColors.surfaceContainerLowest
      : const Color(0xFFF4F5F7);

  /// 行首徽章的中性底色：不用彩色，靠形状和图标区分功能。
  Color get settingsRowIconTint {
    final dark = soundTheme.brightness == Brightness.dark;
    return soundPrimaryText.withValues(alpha: dark ? 0.10 : 0.055);
  }

  TextStyle get settingsInlineActionTextStyle =>
      (Theme.of(this).textTheme.labelSmall ?? const TextStyle()).copyWith(
        fontWeight: FontWeight.w600,
      );

  ButtonStyle settingsInlineActionButtonStyle({
    double minHeight = 32,
    EdgeInsetsGeometry padding = const EdgeInsets.symmetric(horizontal: 8),
  }) {
    return TextButton.styleFrom(
      minimumSize: Size(0, minHeight),
      padding: padding,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: settingsInlineActionTextStyle,
    );
  }
}

class SoundSettingsContent extends StatelessWidget {
  const SoundSettingsContent({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.maxWidth = SoundSettingsMetrics.maxContentWidth,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class SoundSettingsScrollView extends StatelessWidget {
  const SoundSettingsScrollView({
    required this.children,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        SoundSettingsContent(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class SoundSettingsPageHeader extends StatelessWidget {
  const SoundSettingsPageHeader({
    required this.title,
    this.subtitle,
    this.onBack,
    this.backButtonKey,
    this.actions = const [],
    super.key,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Key? backButtonKey;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (onBack != null) ...[
              IconButton(
                key: backButtonKey,
                onPressed: onBack,
                tooltip: '返回设置',
                icon: const Icon(KaitingIcons.back),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: context.settingsPrimary,
                ),
              ),
            ),
            if (actions.isNotEmpty) ...actions,
          ],
        ),
        if (subtitle case final value?) ...[
          SizedBox(height: onBack == null ? 6 : 4),
          Padding(
            padding: EdgeInsets.only(left: onBack == null ? 0 : 56),
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.settingsSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Settings detail pages keep only a compact way back to the overview.
///
/// The destination is already communicated by the selected overview row and
/// the content below, so repeating a large title and explanatory subtitle here
/// wastes the first screenful—especially on phones.
class SoundSettingsBackButton extends StatelessWidget {
  const SoundSettingsBackButton({
    required this.onPressed,
    this.buttonKey,
    super.key,
  });

  final VoidCallback onPressed;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        key: buttonKey,
        onPressed: onPressed,
        tooltip: '返回设置',
        icon: const Icon(KaitingIcons.back),
      ),
    );
  }
}

/// 分组卡片：纯白圆角卡放在浅灰画布上，无边框无阴影，靠色差分层。
/// 行间自动补 hairline（indent 与行内容对齐）。[showDividers] 为 false 时
/// 整卡无内部分隔线（外观这类整块内容的分组用）。
class SoundSettingsGroup extends StatelessWidget {
  const SoundSettingsGroup({
    required this.children,
    this.showDividers = true,
    super.key,
  });

  final List<Widget> children;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.soundColors.surfaceContainer,
        borderRadius: BorderRadius.circular(SoundRadii.card),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (showDividers && index != children.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: context.settingsRowDivider,
              ),
          ],
        ],
      ),
    );
  }
}

/// 分组卡内的子块标签（如「皮肤」「主题色」）。
class SoundSettingsBlockLabel extends StatelessWidget {
  const SoundSettingsBlockLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.settingsSecondary,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Section 标题：分组卡上方的小标题，可带右侧动作（如数量统计）。
class SoundSettingsSectionLabel extends StatelessWidget {
  const SoundSettingsSectionLabel(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      title,
      style: TextStyle(
        color: context.settingsSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: trailing == null
          ? label
          : Row(
              children: [
                Expanded(child: label),
                DefaultTextStyle(
                  style: TextStyle(
                    color: context.settingsMuted,
                    fontSize: 12,
                  ),
                  child: trailing!,
                ),
              ],
            ),
    );
  }
}

/// 行首图标徽章：圆角方形中性底衬 + 图标，让设置行有识别度。
/// 底色用主文字色的低透明度（见 [SoundSettingsContext.settingsRowIconTint]），
/// 不用彩色——靠形状和图标区分功能。[enabled] 为 false 时图标降为 muted。
class SoundSettingsRowIcon extends StatelessWidget {
  const SoundSettingsRowIcon({
    required this.icon,
    this.size = 32,
    this.iconSize = 18,
    this.enabled = true,
    super.key,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final iconColor = enabled
        ? context.settingsSecondary
        : context.settingsMuted;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.settingsRowIconTint,
          borderRadius: BorderRadius.circular(SoundRadii.control + 2),
        ),
        child: Center(child: Icon(icon, size: iconSize, color: iconColor)),
      ),
    );
  }
}

/// 设置行：标题 + 副标题，可选行首徽章、右侧当前值和展开箭头。
class SoundSettingsRow extends StatelessWidget {
  const SoundSettingsRow({
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.onTap,
    this.expanded = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: enabled,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: SoundSettingsMetrics.rowMinHeight(context),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                if (icon != null) ...[
                  SoundSettingsRowIcon(icon: icon!, enabled: enabled),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: context.soundListTitleStyle.copyWith(
                          color: context.settingsPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.settingsSecondary,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: 18),
                  Text(
                    value!,
                    style: TextStyle(
                      color: context.settingsSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (enabled) ...[
                  const SizedBox(width: 10),
                  Icon(
                    expanded ? KaitingIcons.arrowUp : KaitingIcons.chevronRight,
                    size: 19,
                    color: context.settingsSecondary,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
