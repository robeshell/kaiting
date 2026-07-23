import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/sound_theme.dart';

/// Shared translucent surface used by the application shell and overlays.
///
/// Backdrop blur is intentionally optional: floating surfaces use it, while
/// repeated rows and cards can share the same visual language without paying
/// the cost of dozens of independent blur filters.
class SoundGlassSurface extends StatelessWidget {
  const SoundGlassSurface({
    required this.child,
    this.padding,
    this.borderRadius = const BorderRadius.all(
      Radius.circular(SoundRadii.sheet),
    ),
    this.strong = false,
    this.blur = true,
    this.showShadow = true,
    this.shadowOffset = const Offset(0, 10),
    this.shadowBlur,
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius borderRadius;
  final bool strong;
  final bool blur;
  final bool showShadow;
  final Offset shadowOffset;
  final double? shadowBlur;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final glass = context.soundGlass;
    final effects = context.soundSkinEffects;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? (strong ? glass.strongSurface : glass.surface),
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? glass.border),
      ),
      child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
    );
    final clipped = ClipRRect(
      borderRadius: borderRadius,
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: strong ? glass.strongBlur : glass.blur,
                sigmaY: strong ? glass.strongBlur : glass.blur,
              ),
              child: surface,
            )
          : surface,
    );
    if (!showShadow) return clipped;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: glass.shadow,
            blurRadius:
                (shadowBlur ?? (strong ? 34 : 24)) * effects.shadowScale,
            offset: shadowOffset,
          ),
        ],
      ),
      child: clipped,
    );
  }
}

bool get usesDesktopTrackActivation =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux);

/// Gives browseable song rows platform-appropriate activation behavior.
///
/// Desktop users select a row with one click and play it with a double-click
/// or Enter. Touch platforms keep the expected single-tap-to-play behavior.
class SoundTrackActivation extends StatefulWidget {
  const SoundTrackActivation({
    required this.onActivate,
    required this.child,
    this.semanticLabel,
    this.showFocusOutline = false,
    this.focusColor,
    this.borderRadius = BorderRadius.zero,
    super.key,
  });

  final VoidCallback onActivate;
  final Widget child;
  final String? semanticLabel;
  final bool showFocusOutline;
  final Color? focusColor;
  final BorderRadius borderRadius;

  @override
  State<SoundTrackActivation> createState() => _SoundTrackActivationState();
}

class _SoundTrackActivationState extends State<SoundTrackActivation> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.semanticLabel);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      widget.onActivate();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final desktop = usesDesktopTrackActivation;
    final theme = Theme.of(context);
    final semanticLabel = widget.semanticLabel == null
        ? null
        : desktop
        ? '${widget.semanticLabel}，双击播放'
        : '${widget.semanticLabel}，轻点播放';
    return Semantics(
      button: true,
      selected: desktop && _focused,
      label: semanticLabel,
      onTap: widget.onActivate,
      child: Focus(
        focusNode: _focusNode,
        canRequestFocus: desktop,
        onFocusChange: (focused) {
          if (_focused != focused) setState(() => _focused = focused);
        },
        onKeyEvent: _handleKeyEvent,
        child: Material(
          color: Colors.transparent,
          borderRadius: widget.borderRadius,
          child: InkWell(
            excludeFromSemantics: true,
            onTap: desktop ? _focusNode.requestFocus : widget.onActivate,
            onDoubleTap: desktop
                ? () {
                    _focusNode.requestFocus();
                    widget.onActivate();
                  }
                : null,
            borderRadius: widget.borderRadius,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(borderRadius: widget.borderRadius),
              foregroundDecoration: BoxDecoration(
                color: desktop && _focused
                    ? widget.focusColor ?? context.soundTint(0.045)
                    : Colors.transparent,
                borderRadius: widget.borderRadius,
                border: desktop && _focused && widget.showFocusOutline
                    ? Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.46,
                        ),
                      )
                    : null,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// The compact media-row rhythm shared by phone and narrow-tablet screens.
///
/// Business actions stay with each feature; this primitive only keeps artwork,
/// labels and the trailing action aligned consistently across the app.
class SoundCompactMediaRow extends StatelessWidget {
  const SoundCompactMediaRow({
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.titleColor,
    this.subtitleColor,
    this.height = 64,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final Color? titleColor;
  final Color? subtitleColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final mutedStyle = TextStyle(
      color: subtitleColor ?? context.soundMutedText,
      fontSize: 12,
    );
    final subtitleChild =
        subtitleWidget ??
        (subtitle != null && subtitle!.isNotEmpty
            ? Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mutedStyle,
              )
            : null);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox.square(dimension: 44, child: Center(child: leading)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitleChild != null) ...[
                  const SizedBox(height: 3),
                  subtitleChild,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

@immutable
class SoundChoiceOption<T> {
  const SoundChoiceOption({
    required this.value,
    required this.label,
    this.icon,
    this.key,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
  final bool enabled;
}

/// A borderless option strip shared by search and user-library filters.
///
/// The selected state is communicated by a quiet accent tint and accent text;
/// unselected choices keep a barely visible neutral fill. This avoids mixing
/// platform chip outlines with 开听's pill-button language.
class SoundChoiceStrip<T> extends StatelessWidget {
  const SoundChoiceStrip({
    required this.options,
    required this.selected,
    required this.onSelected,
    this.wrap = false,
    this.spacing = 8,
    super.key,
  });

  final List<SoundChoiceOption<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final bool wrap;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final option in options)
        _SoundChoiceButton<T>(
          key: option.key,
          option: option,
          selected: option.value == selected,
          onTap: option.enabled ? () => onSelected(option.value) : null,
        ),
    ];
    if (wrap) {
      return Wrap(spacing: spacing, runSpacing: spacing, children: children);
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) SizedBox(width: spacing),
          ],
        ],
      ),
    );
  }
}

class _SoundChoiceButton<T> extends StatelessWidget {
  const _SoundChoiceButton({
    required this.option,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final SoundChoiceOption<T> option;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = !option.enabled
        ? context.soundMutedText.withValues(alpha: 0.45)
        : selected
        ? SoundColors.accent
        : context.soundSecondaryText.withValues(
            alpha: context.soundSecondaryText.a * 0.82,
          );
    return Semantics(
      button: true,
      selected: selected,
      enabled: option.enabled,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SoundRadii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              color: selected
                  ? SoundColors.accent.withValues(alpha: 0.09)
                  : context.soundTint(0.025),
              borderRadius: BorderRadius.circular(SoundRadii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (option.icon case final icon?) ...[
                  Icon(icon, size: 15, color: foreground),
                  const SizedBox(width: 6),
                ],
                Text(
                  option.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Visual child for popup-backed sort and filter actions.
class SoundToolbarButton extends StatelessWidget {
  const SoundToolbarButton({
    required this.icon,
    required this.tooltip,
    this.label,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        height: 32,
        padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 10),
        decoration: BoxDecoration(
          color: context.soundTint(0.025),
          borderRadius: BorderRadius.circular(SoundRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: context.soundSecondaryText),
            if (label case final value?) ...[
              const SizedBox(width: 6),
              Text(
                value,
                style: TextStyle(
                  color: context.soundSecondaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shared flat song row for library, search, favorites and recent playback.
class SoundTrackListRow extends StatelessWidget {
  const SoundTrackListRow({
    required this.leading,
    required this.title,
    required this.onActivate,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    this.compactTrailing,
    this.desktopHeight = 68,
    this.compactHeight = 64,
    super.key,
  }) : assert(
         subtitle != null || subtitleWidget != null,
         'Provide subtitle or subtitleWidget',
       );

  final Widget leading;
  final String title;

  /// Plain subtitle when [subtitleWidget] is null.
  final String? subtitle;

  /// Preferred when artist/album should be independently tappable.
  final Widget? subtitleWidget;
  final VoidCallback onActivate;
  final Widget? trailing;
  final Widget? compactTrailing;
  final double desktopHeight;
  final double compactHeight;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    final divider = context.soundDivider.withValues(
      alpha: context.soundDivider.a * 0.72,
    );
    final mutedStyle = TextStyle(
      color: context.soundMutedText.withValues(
        alpha: context.soundMutedText.a * 0.82,
      ),
      fontSize: 11.5,
    );
    return SoundTrackActivation(
      onActivate: onActivate,
      semanticLabel: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider)),
          ),
          child: SizedBox(
            height: compact ? compactHeight : desktopHeight,
            child: Row(
              children: [
                SizedBox.square(dimension: compact ? 44 : 48, child: leading),
                SizedBox(width: compact ? 11 : 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.soundPrimaryText.withValues(
                            alpha: context.soundPrimaryText.a * 0.92,
                          ),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      subtitleWidget ??
                          Text(
                            subtitle ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: mutedStyle,
                          ),
                    ],
                  ),
                ),
                if ((compact ? compactTrailing : trailing)
                    case final action?) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared low-emphasis empty, loading and error state.
class SoundEmptyState extends StatelessWidget {
  const SoundEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          context.soundPageGutter,
          30,
          context.soundPageGutter,
          context.soundContentBottomPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  icon,
                  size: 30,
                  color: context.soundMutedText.withValues(
                    alpha: context.soundMutedText.a * 0.68,
                  ),
                ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.soundPrimaryText.withValues(
                    alpha: context.soundPrimaryText.a * 0.88,
                  ),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.soundMutedText.withValues(
                    alpha: context.soundMutedText.a * 0.76,
                  ),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SoundDialog extends StatelessWidget {
  const SoundDialog({
    required this.title,
    required this.content,
    this.actions = const [],
    this.maxWidth = 520,
    this.titlePadding = const EdgeInsets.fromLTRB(24, 22, 20, 16),
    this.contentPadding = const EdgeInsets.fromLTRB(24, 0, 24, 20),
    this.actionsPadding = const EdgeInsets.fromLTRB(20, 14, 20, 20),
    super.key,
  });

  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double maxWidth;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsetsGeometry actionsPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogTheme = DialogTheme.of(context);
    final viewport = MediaQuery.sizeOf(context);
    const horizontalInset = 20.0;
    const verticalInset = 24.0;

    // Keep the route child responsible for its own bounds. Wrapping an
    // AlertDialog with a BackdropFilter makes the wrapper inherit the route's
    // loose full-height constraints, which can stretch otherwise short dialog
    // content (tables are especially visible). The surface now shrink-wraps
    // short content and gives only the content area the remaining height.
    return Dialog(
      backgroundColor: Colors.transparent,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: horizontalInset,
        vertical: verticalInset,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: viewport.height > verticalInset * 2
              ? viewport.height - verticalInset * 2
              : 0,
        ),
        child: SizedBox(
          key: const ValueKey('sound-dialog'),
          width: maxWidth,
          child: SoundGlassSurface(
            strong: true,
            borderRadius: BorderRadius.circular(SoundRadii.dialog),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: titlePadding,
                    child: DefaultTextStyle(
                      style:
                          dialogTheme.titleTextStyle ??
                          theme.textTheme.headlineSmall!,
                      child: title,
                    ),
                  ),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      key: const ValueKey('sound-dialog-content-scroll'),
                      padding: contentPadding,
                      child: DefaultTextStyle(
                        style:
                            dialogTheme.contentTextStyle ??
                            theme.textTheme.bodyMedium!,
                        child: KeyedSubtree(
                          key: const ValueKey('sound-dialog-content'),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                  if (actions.isNotEmpty)
                    Padding(
                      padding: actionsPadding,
                      child: OverflowBar(
                        alignment: MainAxisAlignment.end,
                        overflowAlignment: OverflowBarAlignment.end,
                        spacing: 10,
                        overflowSpacing: 10,
                        children: actions,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<T?> showSoundBottomSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool showHandle = true,
  double maxWidth = 760,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return showModalBottomSheet<T>(
    context: context,
    useSafeArea: true,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
    elevation: 0,
    constraints: BoxConstraints(maxWidth: maxWidth),
    builder: (sheetContext) =>
        SoundBottomSheet(showHandle: showHandle, child: builder(sheetContext)),
  );
}

class SoundBottomSheet extends StatelessWidget {
  const SoundBottomSheet({
    required this.child,
    this.showHandle = true,
    super.key,
  });

  final Widget child;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SoundGlassSurface(
      strong: true,
      shadowOffset: const Offset(0, -8),
      shadowBlur: 28,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(SoundRadii.sheet),
      ),
      child: Material(
        color: Colors.transparent,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(SoundRadii.sheet),
          ),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.only(top: showHandle ? 14 : 0),
                child: child,
              ),
              if (showHandle)
                Positioned(
                  top: 7,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.38,
                        ),
                        borderRadius: BorderRadius.circular(SoundRadii.pill),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One action or selection presented by [SoundMenuButton].
///
/// The data model is shared by compact bottom sheets and wide anchored menus,
/// so platform changes never fall back to Material's default popup rows.
class SoundMenuAction<T> {
  const SoundMenuAction({
    required this.value,
    required this.label,
    required this.icon,
    this.subtitle,
    this.selected = false,
    this.enabled = true,
    this.destructive = false,
    this.dividerBefore = false,
  });

  final T value;
  final String label;
  final IconData icon;
  final String? subtitle;
  final bool selected;
  final bool enabled;
  final bool destructive;
  final bool dividerBefore;
}

/// 开听's adaptive menu trigger for every supported window class.
///
/// Compact windows open a bottom action sheet. Wider windows use a custom
/// anchored overlay with the exact same rows, states and semantics.
class SoundMenuButton<T> extends StatelessWidget {
  const SoundMenuButton({
    required this.actions,
    required this.onSelected,
    required this.tooltip,
    this.menuTitle,
    this.child,
    this.icon = const Icon(Icons.more_horiz_rounded, size: 21),
    this.padding = EdgeInsets.zero,
    this.enabled = true,
    super.key,
  });

  final List<SoundMenuAction<T>> actions;
  final ValueChanged<T> onSelected;
  final String tooltip;
  final String? menuTitle;
  final Widget? child;
  final Widget icon;
  final EdgeInsetsGeometry padding;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final renderBox = context.findRenderObject() as RenderBox?;
    final origin = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
    final anchor = origin & (renderBox?.size ?? Size.zero);
    final selected = await showSoundMenu<T>(
      context,
      anchor: anchor,
      title: menuTitle,
      actions: actions,
    );
    if (selected != null) onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = enabled && actions.any((action) => action.enabled)
        ? () => _open(context)
        : null;
    if (child case final customChild?) {
      return Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: tooltip,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(SoundRadii.control),
              hoverColor: context.soundTint(0.04),
              focusColor: context.soundTint(0.05),
              splashColor: Colors.transparent,
              child: customChild,
            ),
          ),
        ),
      );
    }
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: padding,
      icon: icon,
    );
  }
}

Future<T?> showSoundMenu<T>(
  BuildContext context, {
  required List<SoundMenuAction<T>> actions,
  Rect? anchor,
  String? title,
}) {
  final compact = MediaQuery.sizeOf(context).width < 680;
  if (compact || anchor == null) {
    return showSoundBottomSheet<T>(
      context,
      builder: (sheetContext) =>
          _SoundMenuList<T>(actions: actions, title: title, compact: true),
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 140),
    pageBuilder: (routeContext, animation, secondaryAnimation) =>
        _SoundAnchoredMenu<T>(anchor: anchor, actions: actions, title: title),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        ),
  );
}

class _SoundAnchoredMenu<T> extends StatelessWidget {
  const _SoundAnchoredMenu({
    required this.anchor,
    required this.actions,
    this.title,
  });

  final Rect anchor;
  final List<SoundMenuAction<T>> actions;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final viewport = MediaQuery.sizeOf(context);
    final estimatedHeight =
        actions.length * 48.0 + (title == null ? 12 : 56) + 12;
    const menuWidth = 252.0;
    const edge = 12.0;
    final left = (anchor.right - menuWidth)
        .clamp(edge, math.max(edge, viewport.width - menuWidth - edge))
        .toDouble();
    final opensAbove = anchor.bottom + estimatedHeight > viewport.height - edge;
    final top = opensAbove
        ? math.max(edge, anchor.top - estimatedHeight - 6)
        : anchor.bottom + 6;
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            left: left,
            top: top,
            width: menuWidth,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(120, viewport.height - edge * 2),
              ),
              child: SoundGlassSurface(
                strong: true,
                shadowOffset: const Offset(0, 8),
                shadowBlur: 24,
                borderRadius: BorderRadius.circular(SoundRadii.menu),
                child: _SoundMenuList<T>(
                  actions: actions,
                  title: title,
                  compact: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundMenuList<T> extends StatelessWidget {
  const _SoundMenuList({
    required this.actions,
    required this.compact,
    this.title,
  });

  final List<SoundMenuAction<T>> actions;
  final bool compact;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      shrinkWrap: true,
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 6),
      children: [
        for (final action in actions) ...[
          if (action.dividerBefore)
            Divider(height: 9, indent: 16, endIndent: 16),
          _SoundMenuActionRow<T>(action: action, compact: compact),
        ],
      ],
    );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final value?) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 16,
              compact ? 10 : 12,
              compact ? 20 : 16,
              9,
            ),
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.soundSecondaryText,
                fontSize: compact ? 12.5 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Divider(height: 1, color: context.soundDivider),
        ],
        Flexible(child: list),
      ],
    );
    if (!compact) return content;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: content,
      ),
    );
  }
}

class _SoundMenuActionRow<T> extends StatelessWidget {
  const _SoundMenuActionRow({required this.action, required this.compact});

  final SoundMenuAction<T> action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final error = context.soundColors.error;
    final foreground = !action.enabled
        ? context.soundMutedText.withValues(alpha: 0.48)
        : action.destructive
        ? error
        : action.selected
        ? SoundColors.accent
        : context.soundPrimaryText;
    return Semantics(
      button: true,
      enabled: action.enabled,
      selected: action.selected,
      child: Material(
        color: action.selected ? context.soundTint(0.055) : Colors.transparent,
        child: InkWell(
          onTap: action.enabled
              ? () => Navigator.of(context).pop(action.value)
              : null,
          hoverColor: context.soundTint(0.04),
          focusColor: context.soundTint(0.055),
          splashColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 52 : 46),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 24,
                    child: Icon(action.icon, size: 19, color: foreground),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.label,
                          style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (action.subtitle case final value?) ...[
                          const SizedBox(height: 2),
                          Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.soundSecondaryText,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (action.selected) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: SoundColors.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat, token-driven list row used inside overlays and structured lists.
class SoundListRow extends StatelessWidget {
  const SoundListRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.selected = false,
    this.enabled = true,
    this.minHeight = 54,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final bool enabled;
  final double minHeight;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final interactive = enabled && onTap != null;
    return Semantics(
      button: onTap != null,
      enabled: enabled,
      selected: selected,
      child: Material(
        color: selected ? context.soundTint(0.05) : Colors.transparent,
        child: InkWell(
          onTap: interactive ? onTap : null,
          hoverColor: context.soundTint(0.035),
          focusColor: context.soundTint(0.05),
          splashColor: Colors.transparent,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: padding,
              child: Row(
                children: [
                  if (leading case final value?) ...[
                    SizedBox(width: 32, child: Center(child: value)),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DefaultTextStyle(
                          style: TextStyle(
                            color: enabled
                                ? context.soundPrimaryText
                                : context.soundMutedText.withValues(alpha: 0.5),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: title,
                        ),
                        if (subtitle case final value?) ...[
                          const SizedBox(height: 2),
                          DefaultTextStyle(
                            style: TextStyle(
                              color: context.soundSecondaryText,
                              fontSize: 11.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            child: value,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing case final value?) ...[
                    const SizedBox(width: 10),
                    value,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SoundCheckRow extends StatelessWidget {
  const SoundCheckRow({
    required this.value,
    required this.title,
    required this.onChanged,
    this.subtitle,
    this.enabled = true,
    super.key,
  });

  final bool value;
  final Widget title;
  final Widget? subtitle;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: value,
      enabled: enabled,
      child: SoundListRow(
        enabled: enabled,
        selected: value,
        onTap: enabled ? () => onChanged(!value) : null,
        leading: Icon(
          value
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          size: 20,
          color: value ? SoundColors.accent : context.soundMutedText,
        ),
        title: title,
        subtitle: subtitle,
      ),
    );
  }
}

class SoundNavigationItem {
  const SoundNavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

class SoundNavigationBar extends StatelessWidget {
  const SoundNavigationBar({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    this.embedded = false,
    super.key,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<SoundNavigationItem> destinations;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(10, embedded ? 3 : 7, 10, embedded ? 4 : 6),
      child: SizedBox(
        height: embedded ? 46 : 56,
        child: Row(
          children: [
            for (var index = 0; index < destinations.length; index++)
              Expanded(
                child: _SoundNavigationButton(
                  item: destinations[index],
                  selected: index == selectedIndex,
                  onTap: () => onDestinationSelected(index),
                ),
              ),
          ],
        ),
      ),
    );
    if (embedded) return content;
    return SoundGlassSurface(
      strong: true,
      color: context.soundChromeSurface,
      shadowOffset: const Offset(0, -6),
      shadowBlur: 18,
      borderRadius: BorderRadius.zero,
      borderColor: theme.colorScheme.outlineVariant,
      child: content,
    );
  }
}

class _SoundNavigationButton extends StatelessWidget {
  const _SoundNavigationButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final SoundNavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = selected
        ? SoundColors.accent
        : theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SoundRadii.control),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: foreground,
                fontSize: 10.5,
                height: 1,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 21,
                    color: foreground,
                  ),
                  const SizedBox(height: 3),
                  Text(item.label, maxLines: 1, overflow: TextOverflow.fade),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
