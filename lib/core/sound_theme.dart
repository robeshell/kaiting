import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get soundUsesDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

const soundMacOSTitlebarInset = 38.0;
const soundWindowsTitlebarHeight = 44.0;
const soundChromeSurfaceTransparency = 0.20;
const soundChromeSurfaceOpacity = 1 - soundChromeSurfaceTransparency;

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

  Color get soundChromeSurface =>
      soundGlass.strongSurface.withValues(alpha: soundChromeSurfaceOpacity);

  Color get soundDivider => soundColors.outlineVariant;

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
      return size.width < 1100
          ? SoundWindowClass.medium
          : SoundWindowClass.wide;
    }
    // A foldable cover display is phone-sized, while the opened inner display
    // normally lands around 650–800 logical pixels. Keep those as distinct
    // classes so unfolding can use the extra width without opting into the
    // desktop information architecture.
    if (size.width <= 600 || size.height < 600) {
      return SoundWindowClass.compact;
    }
    if (size.width < 1000) return SoundWindowClass.medium;
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
    return size.width < 820 || size.height < 600;
  }

  double get soundPageGutter => switch (soundWindowClass) {
    SoundWindowClass.compact => 16,
    SoundWindowClass.medium => 24,
    SoundWindowClass.wide => 32,
  };

  double get soundPageTitleSize => soundIsCompact ? 26 : 28;

  /// Scroll padding under list content so the last rows clear the overlaid
  /// mini player / mobile dock (`Scaffold.extendBody` is always on).
  /// Desktop: docked mini player is 76pt tall; keep a little air below.
  double get soundContentBottomPadding => soundUsesMobileShell ? 140 : 96;

  double get soundSidebarWidth => switch (soundWindowClass) {
    SoundWindowClass.compact => 0,
    SoundWindowClass.medium => 216,
    SoundWindowClass.wide => 236,
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
    id: 'coral',
    name: '珊瑚',
    accent: Color(0xFFFF5A4D),
    accentHover: Color(0xFFFF7567),
    accentPressed: Color(0xFFE3483E),
  );

  static Color accent = defaultAccentPreset.accent;
  static Color accentHover = defaultAccentPreset.accentHover;
  static Color accentPressed = defaultAccentPreset.accentPressed;
  static const darkCanvas = Color(0xFF0D0D0F);
  static const darkSurface = Color(0xFF17171A);
  static const darkElevated = Color(0xFF202024);
  static const darkOverlay = Color(0xFF29292E);
  static const lightCanvas = Color(0xFFF7F7F8);
  static const lightSurface = Color(0xFFFAFAFB);
  static const lightElevated = Color(0xFFFFFFFF);
  static const lightOverlay = Color(0xFFF1F2F4);
  static const webDav = Color(0xFF5E8BFF);
  static const local = Color(0xFF55B889);

  static const List<AccentPreset> accentPresets = [
    defaultAccentPreset,
    AccentPreset(
      id: 'rose',
      name: '玫瑰',
      accent: Color(0xFFD95770),
      accentHover: Color(0xFFE66C82),
      accentPressed: Color(0xFFBF465D),
    ),
    AccentPreset(
      id: 'indigo',
      name: '靛蓝',
      accent: Color(0xFF6673C7),
      accentHover: Color(0xFF7884D2),
      accentPressed: Color(0xFF5360AE),
    ),
    AccentPreset(
      id: 'teal',
      name: '青绿',
      accent: Color(0xFF3F9E98),
      accentHover: Color(0xFF51ADA7),
      accentPressed: Color(0xFF338781),
    ),
    AccentPreset(
      id: 'amber',
      name: '暖金',
      accent: Color(0xFFC7842F),
      accentHover: Color(0xFFD4953F),
      accentPressed: Color(0xFFAB6E24),
    ),
    AccentPreset(
      id: 'violet',
      name: '紫罗兰',
      accent: Color(0xFF8067BC),
      accentHover: Color(0xFF9279C8),
      accentPressed: Color(0xFF6D54A5),
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
    canvasHighlight: Color(0xFFFBFBFC),
    surface: Color(0xB8FFFFFF),
    strongSurface: Color(0xDEFFFFFF),
    border: Color(0x12000000),
    innerHighlight: Color(0x8CFFFFFF),
    shadow: Color(0x16000000),
    primaryText: Color(0xFF1C1C22),
    secondaryText: Color(0xFF5A5A62),
    mutedText: Color(0xFF77747D),
    blur: 20,
    strongBlur: 28,
  );

  static const dark = SoundGlassTheme(
    canvasHighlight: Color(0xFF17171A),
    surface: Color(0xB817171A),
    strongSurface: Color(0xE6202024),
    border: Color(0x1CFFFFFF),
    innerHighlight: Color(0x1FFFFFFF),
    shadow: Color(0x6B000000),
    primaryText: Color(0xFFF7F3F4),
    secondaryText: Color(0x99FFFFFF),
    mutedText: Color(0xB3FFFFFF),
    blur: 20,
    strongBlur: 28,
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
    motionDuration: Duration(seconds: 14),
    paletteTransitionDuration: Duration(milliseconds: 420),
    motionStrength: 1,
    primaryGlowOpacity: 0.90,
    secondaryGlowOpacity: 0.72,
    lightVeilOpacity: 0.04,
    darkVeilOpacity: 0.12,
    shadowScale: 1,
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
  static const control = 10.0;
  static const card = 14.0;
  static const menu = 12.0;
  static const sheet = 18.0;
  static const dialog = 20.0;
  static const pill = 999.0;
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
    canvas: Color(0xFFF1F4F8),
    surface: Color(0xFFFAFCFF),
    elevated: Color(0xFFFFFFFF),
    overlay: Color(0xFFE5EBF2),
    glass: SoundGlassTheme(
      canvasHighlight: Color(0xFFF8FBFF),
      surface: Color(0xFFFFFFFF),
      strongSurface: Color(0xFFFFFFFF),
      border: Color(0x1F526174),
      innerHighlight: Color(0xFFFFFFFF),
      shadow: Color(0x00000000),
      primaryText: Color(0xFF18202A),
      secondaryText: Color(0xFF536171),
      mutedText: Color(0xFF718092),
      blur: 0,
      strongBlur: 0,
    ),
    effects: SoundSkinEffects(
      motionDuration: Duration(seconds: 26),
      paletteTransitionDuration: Duration(milliseconds: 240),
      motionStrength: 0.22,
      primaryGlowOpacity: 0.38,
      secondaryGlowOpacity: 0.24,
      lightVeilOpacity: 0.015,
      darkVeilOpacity: 0.08,
      shadowScale: 0,
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
      motionDuration: Duration(seconds: 18),
      paletteTransitionDuration: Duration(milliseconds: 520),
      motionStrength: 0.68,
      primaryGlowOpacity: 0.76,
      secondaryGlowOpacity: 0.54,
      lightVeilOpacity: 0.04,
      darkVeilOpacity: 0.22,
      shadowScale: 1.12,
    ),
  );

  static const defaultPreset = standard;
  static const presets = [standard, pure, deepNight];
}

abstract final class SoundTheme {
  static const _animationDuration = Duration(milliseconds: 160);
  static const _fontFallback = <String>[
    'PingFang SC',
    'Microsoft YaHei',
    'Noto Sans CJK SC',
    'Roboto',
    'sans-serif',
  ];

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

    final baseTextTheme = ThemeData(
      brightness: brightness,
      fontFamily: '.SF Pro Text',
      fontFamilyFallback: _fontFallback,
    ).textTheme.apply(bodyColor: foreground, displayColor: foreground);
    final textTheme = baseTextTheme.copyWith(
      headlineLarge: baseTextTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.55,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
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
        textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      iconSize: const WidgetStatePropertyAll(17),
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      overlayColor: focusOverlay,
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
      fontFamily: '.SF Pro Text',
      fontFamilyFallback: _fontFallback,
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
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
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
        textStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
        labelStyle: TextStyle(color: secondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: TextStyle(
          color: SoundColors.accent,
          fontWeight: FontWeight.w700,
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
          side: const WidgetStatePropertyAll(BorderSide.none),
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
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: SoundColors.accent,
          fontWeight: FontWeight.w700,
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
