import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

export 'kaiting_icons.dart';

import 'brand_tokens.g.dart';

bool get soundUsesDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

const soundMacOSTitlebarInset = KaiBrandLayout.macOSTitlebarInset;
const soundWindowsTitlebarHeight = KaiBrandLayout.windowsTitlebarInset;
const soundChromeSurfaceTransparency = 0.20;
const soundChromeSurfaceOpacity = 1 - soundChromeSurfaceTransparency;

/// Keeps phone album covers comfortably tappable instead of adding a third
/// narrow column when a wide phone crosses a fractional breakpoint.
int soundAlbumGridColumnCount({
  required double crossAxisExtent,
  required bool compact,
  required double spacing,
  required double maxCardWidth,
}) {
  if (crossAxisExtent <= 0) return 1;
  if (compact) return crossAxisExtent >= 280 ? 2 : 1;
  return ((crossAxisExtent + spacing) / (maxCardWidth + spacing)).ceil().clamp(
    1,
    12,
  );
}

extension SoundThemeContext on BuildContext {
  ThemeData get soundTheme => Theme.of(this);

  ColorScheme get soundColors => Theme.of(this).colorScheme;

  SoundGlassTheme get soundGlass =>
      Theme.of(this).extension<SoundGlassTheme>() ?? SoundGlassTheme.light;

  SoundSkinEffects get soundSkinEffects =>
      Theme.of(this).extension<SoundSkinEffects>() ?? SoundSkinEffects.standard;

  Color get soundPrimaryText => soundGlass.primaryText;

  Color get soundSecondaryText => soundGlass.secondaryText;

  Color get soundMutedText => soundGlass.mutedText;

  Color get soundChromeSurface {
    return soundGlass.strongSurface.withValues(
      alpha: soundChromeSurfaceOpacity,
    );
  }

  Color get soundDivider => soundColors.outlineVariant;

  Color get soundWarning => soundTheme.brightness == Brightness.dark
      ? SoundColors.warningDark
      : SoundColors.warningLight;

  Color soundTint(double alpha) => soundPrimaryText.withValues(alpha: alpha);

  ButtonStyle get soundDestructiveButtonStyle {
    final error = soundColors.error;
    return ButtonStyle(
      foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return error.withValues(alpha: 0.38);
        }
        return error;
      }),
      backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
        if (states.contains(WidgetState.disabled)) {
          return error.withValues(alpha: 0.025);
        }
        if (states.contains(WidgetState.pressed)) {
          return error.withValues(alpha: 0.16);
        }
        if (states.contains(WidgetState.hovered) ||
            states.contains(WidgetState.focused)) {
          return error.withValues(alpha: 0.12);
        }
        return error.withValues(alpha: 0.08);
      }),
    );
  }

  double get soundTitlebarInset {
    if (defaultTargetPlatform == TargetPlatform.macOS) {
      return soundMacOSTitlebarInset;
    }
    // Windows uses a custom client-area title bar; reserve matching space.
    // Linux keeps native decorations until a window channel is wired there.
    if (defaultTargetPlatform == TargetPlatform.windows) {
      return soundWindowsTitlebarHeight;
    }
    return 0;
  }

  SoundWindowClass get soundWindowClass {
    final size = MediaQuery.sizeOf(this);
    // Native desktop windows keep desktop information architecture at every
    // supported size. Width only changes density; it must never reveal the
    // phone navigation simply because the window is temporarily short.
    if (soundUsesDesktopPlatform) {
      return size.width < KaiBrandLayout.desktopBreakpoint
          ? SoundWindowClass.medium
          : SoundWindowClass.wide;
    }
    // A foldable cover display is phone-sized, while the opened inner display
    // normally lands around 650–800 logical pixels. Keep those as distinct
    // classes so unfolding can use the extra width without opting into the
    // desktop information architecture.
    if (size.width <= KaiBrandLayout.compactWidth ||
        size.height < KaiBrandLayout.compactHeight) {
      return SoundWindowClass.compact;
    }
    if (size.width < KaiBrandLayout.mobileWideBreakpoint) {
      return SoundWindowClass.medium;
    }
    return SoundWindowClass.wide;
  }

  bool get soundIsCompact => soundWindowClass == SoundWindowClass.compact;

  /// Whether the window should retain touch-first navigation.
  ///
  /// Medium foldable screens deliberately keep the bottom navigation and
  /// mobile now-playing gesture. A regular tablet can still promote itself to
  /// the persistent sidebar once it has enough width.
  bool get soundUsesMobileShell {
    if (soundUsesDesktopPlatform) return false;
    final size = MediaQuery.sizeOf(this);
    return size.width < KaiBrandLayout.mobileShellWidth ||
        size.height < KaiBrandLayout.compactHeight;
  }

  double get soundPageGutter => switch (soundWindowClass) {
    SoundWindowClass.compact => KaiBrandLayout.compactGutter,
    SoundWindowClass.medium => KaiBrandLayout.mediumGutter,
    SoundWindowClass.wide => KaiBrandLayout.wideGutter,
  };

  /// Content inset for library browse (专辑 / 艺人 / 歌曲) and dense track lists.
  ///
  /// Matches [soundPageGutter] so the three library tabs share a comfortable
  /// page edge (compact 16 / medium 24 / wide 32).
  double get soundListGutter => soundPageGutter;

  double get soundPageTitleSize => soundIsCompact
      ? KaiBrandLayout.compactPageTitle
      : KaiBrandLayout.regularPageTitle;

  /// Scroll padding under list content so the last rows clear the overlaid
  /// mini player / mobile dock (`Scaffold.extendBody` is always on).
  /// Desktop: docked mini player is 76pt tall; keep a little air below.
  double get soundContentBottomPadding => soundUsesMobileShell
      ? KaiBrandLayout.mobileBottomPadding
      : KaiBrandLayout.desktopBottomPadding;

  double get soundSidebarWidth => switch (soundWindowClass) {
    SoundWindowClass.compact => 0,
    SoundWindowClass.medium => KaiBrandLayout.mediumSidebarWidth,
    SoundWindowClass.wide => KaiBrandLayout.wideSidebarWidth,
  };
}

enum SoundWindowClass { compact, medium, wide }

class AccentPreset {
  const AccentPreset({
    required this.id,
    required this.name,
    required this.accent,
    required this.accentHover,
    required this.accentPressed,
  });

  final String id;
  final String name;
  final Color accent;
  final Color accentHover;
  final Color accentPressed;

  factory AccentPreset.custom(Color color) {
    final opaque = color.withValues(alpha: 1);
    return AccentPreset(
      id: 'custom',
      name: '自定义',
      accent: opaque,
      accentHover: Color.lerp(opaque, Colors.white, 0.14)!,
      accentPressed: Color.lerp(opaque, Colors.black, 0.13)!,
    );
  }

  static Color readableForeground(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : const Color(0xFF1C1C22);

  Color get onAccent => readableForeground(accent);

  void apply() {
    SoundColors.accent = accent;
    SoundColors.accentHover = accentHover;
    SoundColors.accentPressed = accentPressed;
  }
}

abstract final class SoundColors {
  static const defaultAccentPreset = AccentPreset(
    id: KaiProductAccents.coralId,
    name: KaiProductAccents.coralLabel,
    accent: KaiProductAccents.coral,
    accentHover: KaiProductAccents.coralHover,
    accentPressed: KaiProductAccents.coralPressed,
  );

  static Color accent = defaultAccentPreset.accent;
  static Color accentHover = defaultAccentPreset.accentHover;
  static Color accentPressed = defaultAccentPreset.accentPressed;
  static const darkCanvas = KaiBrandDeepNightSkin.canvas;
  static const darkSurface = KaiBrandDeepNightSkin.surface;
  static const darkElevated = KaiBrandDeepNightSkin.elevated;
  static const darkOverlay = KaiBrandDeepNightSkin.overlay;
  static const lightCanvas = KaiBrandDefaultSkin.canvas;
  static const lightSurface = KaiBrandDefaultSkin.surface;
  static const lightElevated = KaiBrandDefaultSkin.elevated;
  static const lightOverlay = KaiBrandDefaultSkin.overlay;
  static const webDav = KaiProductTokens.sourceWebDav;
  static const local = KaiProductTokens.sourceLocal;
  static const warningLight = KaiBrandStatusColors.warningLight;
  static const warningDark = KaiBrandStatusColors.warningDark;

  static const List<AccentPreset> accentPresets = [
    defaultAccentPreset,
    AccentPreset(
      id: KaiProductAccents.roseId,
      name: KaiProductAccents.roseLabel,
      accent: KaiProductAccents.rose,
      accentHover: KaiProductAccents.roseHover,
      accentPressed: KaiProductAccents.rosePressed,
    ),
    AccentPreset(
      id: KaiProductAccents.indigoId,
      name: KaiProductAccents.indigoLabel,
      accent: KaiProductAccents.indigo,
      accentHover: KaiProductAccents.indigoHover,
      accentPressed: KaiProductAccents.indigoPressed,
    ),
    AccentPreset(
      id: KaiProductAccents.tealId,
      name: KaiProductAccents.tealLabel,
      accent: KaiProductAccents.teal,
      accentHover: KaiProductAccents.tealHover,
      accentPressed: KaiProductAccents.tealPressed,
    ),
    AccentPreset(
      id: KaiProductAccents.amberId,
      name: KaiProductAccents.amberLabel,
      accent: KaiProductAccents.amber,
      accentHover: KaiProductAccents.amberHover,
      accentPressed: KaiProductAccents.amberPressed,
    ),
    AccentPreset(
      id: KaiProductAccents.violetId,
      name: KaiProductAccents.violetLabel,
      accent: KaiProductAccents.violet,
      accentHover: KaiProductAccents.violetHover,
      accentPressed: KaiProductAccents.violetPressed,
    ),
  ];
}

@immutable
class SoundGlassTheme extends ThemeExtension<SoundGlassTheme> {
  const SoundGlassTheme({
    required this.canvasHighlight,
    required this.surface,
    required this.strongSurface,
    required this.border,
    required this.innerHighlight,
    required this.shadow,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedText,
    required this.blur,
    required this.strongBlur,
  });

  static const light = SoundGlassTheme(
    canvasHighlight: KaiBrandDefaultSkin.glassCanvasHighlight,
    surface: KaiBrandDefaultSkin.glassSurface,
    strongSurface: KaiBrandDefaultSkin.glassStrongSurface,
    border: KaiBrandDefaultSkin.glassBorder,
    innerHighlight: KaiBrandDefaultSkin.glassInnerHighlight,
    shadow: KaiBrandDefaultSkin.glassShadow,
    primaryText: KaiBrandDefaultSkin.glassPrimaryText,
    secondaryText: KaiBrandDefaultSkin.glassSecondaryText,
    mutedText: KaiBrandDefaultSkin.glassMutedText,
    blur: KaiBrandDefaultSkin.glassBlur,
    strongBlur: KaiBrandDefaultSkin.glassStrongBlur,
  );

  static const dark = SoundGlassTheme(
    canvasHighlight: KaiBrandDeepNightSkin.glassCanvasHighlight,
    surface: KaiBrandDeepNightSkin.glassSurface,
    strongSurface: KaiBrandDeepNightSkin.glassStrongSurface,
    border: KaiBrandDeepNightSkin.glassBorder,
    innerHighlight: KaiBrandDeepNightSkin.glassInnerHighlight,
    shadow: KaiBrandDeepNightSkin.glassShadow,
    primaryText: KaiBrandDeepNightSkin.glassPrimaryText,
    secondaryText: KaiBrandDeepNightSkin.glassSecondaryText,
    mutedText: KaiBrandDeepNightSkin.glassMutedText,
    blur: KaiBrandDeepNightSkin.glassBlur,
    strongBlur: KaiBrandDeepNightSkin.glassStrongBlur,
  );

  final Color canvasHighlight;
  final Color surface;
  final Color strongSurface;
  final Color border;
  final Color innerHighlight;
  final Color shadow;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedText;
  final double blur;
  final double strongBlur;

  @override
  SoundGlassTheme copyWith({
    Color? canvasHighlight,
    Color? surface,
    Color? strongSurface,
    Color? border,
    Color? innerHighlight,
    Color? shadow,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedText,
    double? blur,
    double? strongBlur,
  }) {
    return SoundGlassTheme(
      canvasHighlight: canvasHighlight ?? this.canvasHighlight,
      surface: surface ?? this.surface,
      strongSurface: strongSurface ?? this.strongSurface,
      border: border ?? this.border,
      innerHighlight: innerHighlight ?? this.innerHighlight,
      shadow: shadow ?? this.shadow,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedText: mutedText ?? this.mutedText,
      blur: blur ?? this.blur,
      strongBlur: strongBlur ?? this.strongBlur,
    );
  }

  @override
  SoundGlassTheme lerp(covariant SoundGlassTheme? other, double t) {
    if (other == null) return this;
    return SoundGlassTheme(
      canvasHighlight: Color.lerp(canvasHighlight, other.canvasHighlight, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      strongSurface: Color.lerp(strongSurface, other.strongSurface, t)!,
      border: Color.lerp(border, other.border, t)!,
      innerHighlight: Color.lerp(innerHighlight, other.innerHighlight, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedText: Color.lerp(mutedText, other.mutedText, t)!,
      blur: blur + (other.blur - blur) * t,
      strongBlur: strongBlur + (other.strongBlur - strongBlur) * t,
    );
  }
}

/// Material and motion characteristics that belong to a skin without changing
/// page structure. Components consume these semantic values instead of
/// branching on a skin identifier.
@immutable
class SoundSkinEffects extends ThemeExtension<SoundSkinEffects> {
  const SoundSkinEffects({
    required this.motionDuration,
    required this.paletteTransitionDuration,
    required this.motionStrength,
    required this.primaryGlowOpacity,
    required this.secondaryGlowOpacity,
    required this.lightVeilOpacity,
    required this.darkVeilOpacity,
    required this.shadowScale,
  });

  static const standard = SoundSkinEffects(
    motionDuration: Duration(
      seconds: KaiBrandDefaultSkin.effectMotionDurationS,
    ),
    paletteTransitionDuration: Duration(
      milliseconds: KaiBrandDefaultSkin.effectPaletteTransitionMs,
    ),
    motionStrength: KaiBrandDefaultSkin.effectMotionStrength,
    primaryGlowOpacity: KaiBrandDefaultSkin.effectPrimaryGlowOpacity,
    secondaryGlowOpacity: KaiBrandDefaultSkin.effectSecondaryGlowOpacity,
    lightVeilOpacity: KaiBrandDefaultSkin.effectLightVeilOpacity,
    darkVeilOpacity: KaiBrandDefaultSkin.effectDarkVeilOpacity,
    shadowScale: KaiBrandDefaultSkin.effectShadowScale,
  );

  final Duration motionDuration;
  final Duration paletteTransitionDuration;
  final double motionStrength;
  final double primaryGlowOpacity;
  final double secondaryGlowOpacity;
  final double lightVeilOpacity;
  final double darkVeilOpacity;
  final double shadowScale;

  @override
  SoundSkinEffects copyWith({
    Duration? motionDuration,
    Duration? paletteTransitionDuration,
    double? motionStrength,
    double? primaryGlowOpacity,
    double? secondaryGlowOpacity,
    double? lightVeilOpacity,
    double? darkVeilOpacity,
    double? shadowScale,
  }) {
    return SoundSkinEffects(
      motionDuration: motionDuration ?? this.motionDuration,
      paletteTransitionDuration:
          paletteTransitionDuration ?? this.paletteTransitionDuration,
      motionStrength: motionStrength ?? this.motionStrength,
      primaryGlowOpacity: primaryGlowOpacity ?? this.primaryGlowOpacity,
      secondaryGlowOpacity: secondaryGlowOpacity ?? this.secondaryGlowOpacity,
      lightVeilOpacity: lightVeilOpacity ?? this.lightVeilOpacity,
      darkVeilOpacity: darkVeilOpacity ?? this.darkVeilOpacity,
      shadowScale: shadowScale ?? this.shadowScale,
    );
  }

  @override
  SoundSkinEffects lerp(covariant SoundSkinEffects? other, double t) {
    if (other == null) return this;
    int lerpDuration(Duration from, Duration to) =>
        (from.inMicroseconds + (to.inMicroseconds - from.inMicroseconds) * t)
            .round();
    return SoundSkinEffects(
      motionDuration: Duration(
        microseconds: lerpDuration(motionDuration, other.motionDuration),
      ),
      paletteTransitionDuration: Duration(
        microseconds: lerpDuration(
          paletteTransitionDuration,
          other.paletteTransitionDuration,
        ),
      ),
      motionStrength:
          motionStrength + (other.motionStrength - motionStrength) * t,
      primaryGlowOpacity:
          primaryGlowOpacity +
          (other.primaryGlowOpacity - primaryGlowOpacity) * t,
      secondaryGlowOpacity:
          secondaryGlowOpacity +
          (other.secondaryGlowOpacity - secondaryGlowOpacity) * t,
      lightVeilOpacity:
          lightVeilOpacity + (other.lightVeilOpacity - lightVeilOpacity) * t,
      darkVeilOpacity:
          darkVeilOpacity + (other.darkVeilOpacity - darkVeilOpacity) * t,
      shadowScale: shadowScale + (other.shadowScale - shadowScale) * t,
    );
  }
}

abstract final class SoundRadii {
  static const control = KaiBrandRadii.control;
  static const card = KaiBrandRadii.card;
  static const menu = KaiBrandRadii.menu;
  static const sheet = KaiBrandRadii.sheet;
  static const dialog = KaiBrandRadii.dialog;
  static const pill = KaiBrandRadii.pill;
}

@immutable
class SoundSkinPreset {
  const SoundSkinPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.brightness,
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.overlay,
    required this.glass,
    required this.effects,
  });

  final String id;
  final String name;
  final String description;
  final Brightness brightness;
  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color overlay;
  final SoundGlassTheme glass;
  final SoundSkinEffects effects;
}

abstract final class SoundSkins {
  /// The original 开听 appearance. Keep these tokens stable so adding new
  /// skins never changes the visual baseline existing users already know.
  static const standard = SoundSkinPreset(
    id: 'default',
    name: '默认',
    description: '开听 的中性浅色玻璃界面',
    brightness: Brightness.light,
    canvas: SoundColors.lightCanvas,
    surface: SoundColors.lightSurface,
    elevated: SoundColors.lightElevated,
    overlay: SoundColors.lightOverlay,
    glass: SoundGlassTheme.light,
    effects: SoundSkinEffects.standard,
  );

  static const pure = SoundSkinPreset(
    id: 'pure',
    name: '纯净',
    description: '冷静通透的实色表面与清晰层次',
    brightness: Brightness.light,
    canvas: KaiBrandPureSkin.canvas,
    surface: KaiBrandPureSkin.surface,
    elevated: KaiBrandPureSkin.elevated,
    overlay: KaiBrandPureSkin.overlay,
    glass: SoundGlassTheme(
      canvasHighlight: KaiBrandPureSkin.glassCanvasHighlight,
      surface: KaiBrandPureSkin.glassSurface,
      strongSurface: KaiBrandPureSkin.glassStrongSurface,
      border: KaiBrandPureSkin.glassBorder,
      innerHighlight: KaiBrandPureSkin.glassInnerHighlight,
      shadow: KaiBrandPureSkin.glassShadow,
      primaryText: KaiBrandPureSkin.glassPrimaryText,
      secondaryText: KaiBrandPureSkin.glassSecondaryText,
      mutedText: KaiBrandPureSkin.glassMutedText,
      blur: KaiBrandPureSkin.glassBlur,
      strongBlur: KaiBrandPureSkin.glassStrongBlur,
    ),
    effects: SoundSkinEffects(
      motionDuration: Duration(seconds: KaiBrandPureSkin.effectMotionDurationS),
      paletteTransitionDuration: Duration(
        milliseconds: KaiBrandPureSkin.effectPaletteTransitionMs,
      ),
      motionStrength: KaiBrandPureSkin.effectMotionStrength,
      primaryGlowOpacity: KaiBrandPureSkin.effectPrimaryGlowOpacity,
      secondaryGlowOpacity: KaiBrandPureSkin.effectSecondaryGlowOpacity,
      lightVeilOpacity: KaiBrandPureSkin.effectLightVeilOpacity,
      darkVeilOpacity: KaiBrandPureSkin.effectDarkVeilOpacity,
      shadowScale: KaiBrandPureSkin.effectShadowScale,
    ),
  );

  static const deepNight = SoundSkinPreset(
    id: 'deep-night',
    name: '深夜',
    description: '专注于封面和歌词的低亮深色界面',
    brightness: Brightness.dark,
    canvas: SoundColors.darkCanvas,
    surface: SoundColors.darkSurface,
    elevated: SoundColors.darkElevated,
    overlay: SoundColors.darkOverlay,
    glass: SoundGlassTheme.dark,
    effects: SoundSkinEffects(
      motionDuration: Duration(
        seconds: KaiBrandDeepNightSkin.effectMotionDurationS,
      ),
      paletteTransitionDuration: Duration(
        milliseconds: KaiBrandDeepNightSkin.effectPaletteTransitionMs,
      ),
      motionStrength: KaiBrandDeepNightSkin.effectMotionStrength,
      primaryGlowOpacity: KaiBrandDeepNightSkin.effectPrimaryGlowOpacity,
      secondaryGlowOpacity: KaiBrandDeepNightSkin.effectSecondaryGlowOpacity,
      lightVeilOpacity: KaiBrandDeepNightSkin.effectLightVeilOpacity,
      darkVeilOpacity: KaiBrandDeepNightSkin.effectDarkVeilOpacity,
      shadowScale: KaiBrandDeepNightSkin.effectShadowScale,
    ),
  );

  static const defaultPreset = standard;
  static const presets = [standard, pure, deepNight];
}

abstract final class SoundTheme {
  static const _animationDuration = Duration(milliseconds: 160);

  static ThemeData get dark => forSkin(SoundSkins.deepNight);

  static ThemeData get light => forSkin(SoundSkins.standard);

  static ThemeData forSkin(SoundSkinPreset skin) =>
      _build(skin.brightness, skin: skin);

  static ThemeData _build(
    Brightness brightness, {
    required SoundSkinPreset skin,
  }) {
    final dark = brightness == Brightness.dark;
    final canvas = skin.canvas;
    final surface = skin.surface;
    final elevated = skin.elevated;
    final overlay = skin.overlay;
    final glass = skin.glass;
    final effects = skin.effects;
    final foreground = glass.primaryText;
    final secondary = glass.secondaryText;
    final border = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.black.withValues(alpha: 0.08);
    final hairline = dark
        ? Colors.white.withValues(alpha: 0.065)
        : Colors.black.withValues(alpha: 0.055);
    final disabledBorder = dark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final subtle = dark
        ? Colors.white.withValues(alpha: 0.055)
        : Colors.black.withValues(alpha: 0.045);
    final disabledSubtle = dark
        ? Colors.white.withValues(alpha: 0.028)
        : Colors.black.withValues(alpha: 0.024);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: SoundColors.accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: SoundColors.accent,
          onPrimary: AccentPreset.readableForeground(SoundColors.accent),
          surface: surface,
          onSurface: foreground,
          onSurfaceVariant: secondary,
          outline: border,
          outlineVariant: hairline,
          surfaceContainerLowest: canvas,
          surfaceContainerLow: surface,
          surfaceContainer: elevated,
          surfaceContainerHigh: overlay,
          surfaceContainerHighest: overlay,
          scrim: Colors.black,
        );

    // Use the platform default typeface (SF/PingFang on Apple, Roboto/Noto on
    // Android, Segoe/YaHei on Windows). Do not pin ".SF Pro Text" — missing that
    // family on non-Apple hosts made metrics and CJK fallback look off.
    final baseTextTheme = ThemeData(
      brightness: brightness,
    ).textTheme.apply(bodyColor: foreground, displayColor: foreground);
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(color: secondary),
    );

    final focusOverlay = WidgetStateProperty.resolveWith<Color?>((states) {
      if (states.contains(WidgetState.focused)) {
        return SoundColors.accent.withValues(alpha: 0.16);
      }
      if (states.contains(WidgetState.pressed)) {
        return foreground.withValues(alpha: 0.10);
      }
      if (states.contains(WidgetState.hovered)) {
        return foreground.withValues(alpha: 0.065);
      }
      return Colors.transparent;
    });
    final focusSide = WidgetStateProperty.resolveWith<BorderSide?>((states) {
      return states.contains(WidgetState.focused)
          ? BorderSide(color: SoundColors.accent, width: 2)
          : null;
    });
    final standardButtonStyle = ButtonStyle(
      animationDuration: _animationDuration,
      minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      ),
      shape: const WidgetStatePropertyAll(StadiumBorder()),
      textStyle: WidgetStatePropertyAll(
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w500),
      ),
      iconSize: const WidgetStatePropertyAll(17),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: focusOverlay,
      side: focusSide,
    );
    final pillBackground = WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return foreground.withValues(alpha: 0.022);
      }
      if (states.contains(WidgetState.pressed)) {
        return foreground.withValues(alpha: 0.11);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return foreground.withValues(alpha: 0.075);
      }
      return foreground.withValues(alpha: 0.045);
    });
    final quietPillBackground = WidgetStateProperty.resolveWith<Color>((
      states,
    ) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) {
        return foreground.withValues(alpha: 0.085);
      }
      if (states.contains(WidgetState.hovered) ||
          states.contains(WidgetState.focused)) {
        return foreground.withValues(alpha: 0.055);
      }
      return foreground.withValues(alpha: 0.025);
    });
    final pillForeground = WidgetStateProperty.resolveWith<Color>((states) {
      if (states.contains(WidgetState.disabled)) {
        return secondary.withValues(alpha: 0.38);
      }
      return SoundColors.accent;
    });
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(SoundRadii.control),
      borderSide: BorderSide(color: border),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      cardColor: surface,
      textTheme: textTheme,
      focusColor: foreground.withValues(alpha: 0.065),
      hoverColor: foreground.withValues(alpha: 0.055),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      dividerColor: hairline,
      disabledColor: secondary.withValues(alpha: 0.38),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[glass, effects],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: canvas,
        foregroundColor: foreground,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: elevated,
        barrierColor: Colors.black.withValues(alpha: dark ? 0.62 : 0.38),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoundRadii.dialog),
          side: BorderSide(color: border),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: secondary),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        modalElevation: 0,
        backgroundColor: elevated,
        modalBackgroundColor: elevated,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
        dragHandleColor: secondary.withValues(alpha: 0.45),
        dragHandleSize: const Size(38, 4),
        showDragHandle: false,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SoundRadii.sheet),
          ),
        ),
        constraints: const BoxConstraints(maxWidth: 760),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: overlay,
        actionTextColor: SoundColors.accent,
        disabledActionTextColor: secondary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: foreground),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoundRadii.menu),
          side: BorderSide(color: border),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: SoundColors.accent.withValues(alpha: 0.14),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoundRadii.control),
        ),
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected)
                ? SoundColors.accent
                : secondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return TextStyle(
            fontSize: 10.5,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? foreground
                : secondary,
          );
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
        position: PopupMenuPosition.under,
        menuPadding: const EdgeInsets.all(6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoundRadii.menu),
          side: BorderSide(color: border),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: WidgetStatePropertyAll(
            Colors.black.withValues(alpha: dark ? 0.42 : 0.16),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoundRadii.menu),
              side: BorderSide(color: border),
            ),
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: subtle,
          border: inputBorder,
          enabledBorder: inputBorder,
          focusedBorder: inputBorder.copyWith(
            borderSide: BorderSide(color: SoundColors.accent, width: 2),
          ),
        ),
        menuStyle: MenuStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStatePropertyAll(elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SoundRadii.menu),
              side: BorderSide(color: border),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: subtle,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: disabledBorder),
        ),
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: SoundColors.accent, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: secondary, fontWeight: FontWeight.w500),
        floatingLabelStyle: TextStyle(
          color: SoundColors.accent,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: TextStyle(color: secondary.withValues(alpha: 0.7)),
        prefixIconColor: secondary,
        suffixIconColor: secondary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: standardButtonStyle.copyWith(
          backgroundColor: pillBackground,
          foregroundColor: pillForeground,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: standardButtonStyle.copyWith(
          backgroundColor: pillBackground,
          foregroundColor: pillForeground,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: standardButtonStyle.copyWith(
          backgroundColor: quietPillBackground,
          foregroundColor: pillForeground,
          side: WidgetStateProperty.resolveWith<BorderSide>((states) {
            return states.contains(WidgetState.focused)
                ? BorderSide(color: SoundColors.accent, width: 2)
                : BorderSide.none;
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: standardButtonStyle.copyWith(
          backgroundColor: quietPillBackground,
          foregroundColor: pillForeground,
          minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          animationDuration: _animationDuration,
          minimumSize: const WidgetStatePropertyAll(Size.square(40)),
          iconSize: const WidgetStatePropertyAll(20),
          foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.disabled)) {
              return secondary.withValues(alpha: 0.38);
            }
            if (states.contains(WidgetState.selected)) {
              return SoundColors.accent;
            }
            return foreground;
          }),
          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.pressed)) {
              return foreground.withValues(alpha: 0.10);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return foreground.withValues(alpha: 0.065);
            }
            return Colors.transparent;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(CircleBorder()),
          side: focusSide,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: foreground.withValues(alpha: 0.045),
        foregroundColor: SoundColors.accent,
        shape: const CircleBorder(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: secondary,
        textColor: foreground,
        selectedColor: SoundColors.accent,
        selectedTileColor: SoundColors.accent.withValues(alpha: 0.035),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        minTileHeight: 54,
        minVerticalPadding: 6,
        minLeadingWidth: 32,
        horizontalTitleGap: 10,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: foreground,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: secondary,
          fontSize: 11.5,
        ),
        shape: const RoundedRectangleBorder(),
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: border, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return SoundColors.accent;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        overlayColor: focusOverlay,
      ),
      radioTheme: RadioThemeData(
        visualDensity: VisualDensity.compact,
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? SoundColors.accent
              : secondary;
        }),
        overlayColor: focusOverlay,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : secondary;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          return states.contains(WidgetState.selected)
              ? SoundColors.accent
              : border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor: focusOverlay,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: SoundColors.accent,
        inactiveTrackColor: border,
        thumbColor: SoundColors.accent,
        overlayColor: SoundColors.accent.withValues(alpha: 0.12),
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        showValueIndicator: ShowValueIndicator.never,
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        pressElevation: 0,
        backgroundColor: foreground.withValues(alpha: 0.025),
        selectedColor: SoundColors.accent.withValues(alpha: 0.09),
        disabledColor: disabledSubtle,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SoundRadii.pill),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: secondary,
          fontWeight: FontWeight.w500,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: SoundColors.accent,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(size: 16, color: secondary),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        labelPadding: const EdgeInsets.symmetric(horizontal: 7),
        showCheckmark: false,
      ),
      dividerTheme: DividerThemeData(color: hairline, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        showDuration: const Duration(seconds: 3),
        decoration: BoxDecoration(
          color: overlay,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: foreground),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(5),
        radius: const Radius.circular(SoundRadii.pill),
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          return secondary.withValues(
            alpha: states.contains(WidgetState.hovered) ? 0.55 : 0.30,
          );
        }),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: SoundColors.accent,
        linearTrackColor: Colors.transparent,
      ),
    );
  }
}
