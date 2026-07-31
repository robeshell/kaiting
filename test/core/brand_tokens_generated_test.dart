import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/brand_tokens.g.dart';
import 'package:kaiting/core/sound_theme.dart';

void main() {
  test('runtime theme consumes generated brand tokens', () {
    expect(kaiBrandSpecVersion, '0.7.0');
    expect(SoundRadii.card, KaiBrandRadii.card);
    // Light chrome deliberately uses the neutral-white elevated token instead
    // of the cool-tinted canvas (see SoundColors.lightCanvas comment).
    expect(SoundSkins.standard.canvas, KaiBrandDefaultSkin.elevated);
    expect(
      SoundSkins.deepNight.glass.mutedText,
      KaiBrandDeepNightSkin.glassMutedText,
    );
    expect(SoundColors.defaultAccentPreset.accent, KaiProductAccents.coral);
    expect(SoundColors.webDav, KaiProductTokens.sourceWebDav);
    expect(SoundColors.local, KaiProductTokens.sourceLocal);
  });
}
