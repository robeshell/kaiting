import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/core/sound_theme.dart';

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
