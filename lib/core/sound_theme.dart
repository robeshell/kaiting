import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

bool get soundUsesDesktopPlatform =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows ||
    defaultTargetPlatform == TargetPlatform.linux;

const soundMacOSTitlebarInset = 38.0;
const soundChromeSurfaceTransparency = 0.20;
const soundChromeSurfaceOpacity = 1 - soundChromeSurfaceTransparency;

extension SoundThemeContext on BuildContext {
  ThemeData get soundTheme => Theme.of(this);

  ColorScheme get soundColors => Theme.of(this).colorScheme;

  SoundGlassTheme get soundGlass =>
      Theme.of(this).extension<SoundGlassTheme>() ?? SoundGlassTheme.light;

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

  double get soundTitlebarInset => defaultTargetPlatform == TargetPlatform.macOS
      ? soundMacOSTitlebarInset
      : 0;

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
    if (size.width < 820 || size.height < 600) {
      return SoundWindowClass.compact;
    }
    if (size.width < 1100) return SoundWindowClass.medium;
    return SoundWindowClass.wide;
  }

  bool get soundIsCompact => soundWindowClass == SoundWindowClass.compact;

  double get soundPageGutter => switch (soundWindowClass) {
    SoundWindowClass.compact => 16,
    SoundWindowClass.medium => 24,
    SoundWindowClass.wide => 32,
  };

  double get soundPageTitleSize => soundIsCompact ? 26 : 28;

  double get soundContentBottomPadding => soundIsCompact ? 140 : 32;

  double get soundSidebarWidth => switch (soundWindowClass) {
    SoundWindowClass.compact => 0,
    SoundWindowClass.medium => 216,
    SoundWindowClass.wide => 236,
  };
}

enum SoundWindowClass { compact, medium, wide }

abstract final class SoundColors {
  static const accent = Color(0xFFFF5A4D);
  static const accentHover = Color(0xFFFF7567);
  static const accentPressed = Color(0xFFE3483E);
  static const darkCanvas = Color(0xFF0D0D0F);
  static const darkSurface = Color(0xFF17171A);
  static const darkElevated = Color(0xFF202024);
  static const darkOverlay = Color(0xFF29292E);
  static const lightCanvas = Color(0xFFFAF5EE);
  static const lightSurface = Color(0xFFFCFAF6);
  static const lightElevated = Color(0xFFFFFDFC);
  static const lightOverlay = Color(0xFFF6EFE7);
  static const webDav = Color(0xFF5E8BFF);
  static const local = Color(0xFF55B889);
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
    canvasHighlight: Color(0xFFFFFAF4),
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

abstract final class SoundRadii {
  static const control = 10.0;
  static const card = 14.0;
  static const menu = 12.0;
  static const sheet = 18.0;
  static const dialog = 20.0;
  static const pill = 999.0;
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

  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final canvas = dark ? SoundColors.darkCanvas : SoundColors.lightCanvas;
    final surface = dark ? SoundColors.darkSurface : SoundColors.lightSurface;
    final elevated = dark
        ? SoundColors.darkElevated
        : SoundColors.lightElevated;
    final overlay = dark ? SoundColors.darkOverlay : SoundColors.lightOverlay;
    final glass = dark ? SoundGlassTheme.dark : SoundGlassTheme.light;
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
          onPrimary: Colors.white,
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

    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(SoundRadii.control),
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
          ? const BorderSide(color: SoundColors.accent, width: 2)
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
      focusColor: SoundColors.accent.withValues(alpha: 0.20),
      hoverColor: foreground.withValues(alpha: 0.055),
      highlightColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      dividerColor: hairline,
      disabledColor: secondary.withValues(alpha: 0.38),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: <ThemeExtension<dynamic>>[glass],
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
            borderSide: const BorderSide(color: SoundColors.accent, width: 2),
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
          borderSide: const BorderSide(color: SoundColors.accent, width: 2),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        labelStyle: TextStyle(color: secondary, fontWeight: FontWeight.w600),
        floatingLabelStyle: const TextStyle(
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
        selectedTileColor: SoundColors.accent.withValues(alpha: 0.10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
        shape: controlShape,
      ),
      checkboxTheme: CheckboxThemeData(
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: BorderSide(color: border, width: 1.4),
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.selected)) return SoundColors.accent;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
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
              ? Colors.white
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
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: SoundColors.accent,
        linearTrackColor: Colors.transparent,
      ),
    );
  }
}
