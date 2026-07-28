import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

abstract final class SoundSettingsMetrics {
  static const maxContentWidth = 920.0;
  static const sectionGap = 28.0;
  static const rowMinHeight = 64.0;
  static const compactRowMinHeight = 58.0;
}

extension SoundSettingsContext on BuildContext {
  Color get settingsPrimary => soundPrimaryText;
  Color get settingsSecondary => soundSecondaryText;
  Color get settingsMuted => soundMutedText;
  Color get settingsHairline => soundDivider;
  Color get settingsInlineSurface =>
      soundColors.surfaceContainerLow.withValues(alpha: 0.72);
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
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: context.settingsPrimary,
                  fontSize: context.soundPageTitleSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.25,
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
              style: TextStyle(
                color: context.settingsSecondary,
                fontSize: 12.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 分组卡片：设置项收进圆角卡，不漂浮在画布上。
/// r14 + surfaceContainerLow@72% + hairline 边框；行间自动补 hairline（indent 14）。
class SoundSettingsGroup extends StatelessWidget {
  const SoundSettingsGroup({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.settingsInlineSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.settingsHairline),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              Divider(
                height: 1,
                indent: 14,
                endIndent: 14,
                color: context.settingsHairline,
              ),
          ],
        ],
      ),
    );
  }
}

/// 分组卡内的子块标签（如「皮肤」「主题色」），12.5 secondary。
class SoundSettingsBlockLabel extends StatelessWidget {
  const SoundSettingsBlockLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 2),
      child: Text(
        label,
        style: TextStyle(
          color: context.settingsSecondary,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
