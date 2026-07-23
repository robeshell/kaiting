import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/sound_theme.dart';

void main() {
  tearDown(SoundColors.defaultAccentPreset.apply);

  testWidgets('app theme rebuild picks up the newly applied accent', (
    tester,
  ) async {
    final amber = SoundColors.accentPresets.firstWhere(
      (preset) => preset.id == 'amber',
    );

    await tester.pumpWidget(_AccentThemeHarness(nextPreset: amber));
    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-probe'))),
      ).colorScheme.primary,
      SoundColors.defaultAccentPreset.accent,
    );

    await tester.tap(find.byKey(const ValueKey('change-accent')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(SoundColors.accent, amber.accent);

    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('theme-probe'))),
      ).colorScheme.primary,
      amber.accent,
    );
  });

  testWidgets('skin switching rebuilds the application surfaces', (
    tester,
  ) async {
    await tester.pumpWidget(const _SkinThemeHarness());

    expect(
      Theme.of(
        tester.element(find.byKey(const ValueKey('skin-theme-probe'))),
      ).scaffoldBackgroundColor,
      SoundSkins.standard.canvas,
    );

    await tester.tap(find.byKey(const ValueKey('change-skin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    final theme = Theme.of(
      tester.element(find.byKey(const ValueKey('skin-theme-probe'))),
    );
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, SoundSkins.deepNight.canvas);
  });
}

class _AccentThemeHarness extends StatefulWidget {
  const _AccentThemeHarness({required this.nextPreset});

  final AccentPreset nextPreset;

  @override
  State<_AccentThemeHarness> createState() => _AccentThemeHarnessState();
}

class _AccentThemeHarnessState extends State<_AccentThemeHarness> {
  @override
  void initState() {
    super.initState();
    SoundColors.defaultAccentPreset.apply();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: SoundTheme.light,
      home: Scaffold(
        key: const ValueKey('theme-probe'),
        body: TextButton(
          key: const ValueKey('change-accent'),
          onPressed: () {
            widget.nextPreset.apply();
            setState(() {});
          },
          child: const Text('更换主题色'),
        ),
      ),
    );
  }
}

class _SkinThemeHarness extends StatefulWidget {
  const _SkinThemeHarness();

  @override
  State<_SkinThemeHarness> createState() => _SkinThemeHarnessState();
}

class _SkinThemeHarnessState extends State<_SkinThemeHarness> {
  SoundSkinPreset skin = SoundSkins.standard;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: SoundTheme.forSkin(skin),
      home: Scaffold(
        key: const ValueKey('skin-theme-probe'),
        body: TextButton(
          key: const ValueKey('change-skin'),
          onPressed: () => setState(() => skin = SoundSkins.deepNight),
          child: const Text('更换皮肤'),
        ),
      ),
    );
  }
}
