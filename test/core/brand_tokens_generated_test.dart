import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/brand_tokens.g.dart';
import 'package:kaiting/core/sound_theme.dart';

void main() {
  test('runtime theme consumes generated brand tokens', () {
    expect(kaiBrandSpecVersion, '0.6.1');
    expect(SoundRadii.card, KaiBrandRadii.card);
    expect(SoundSkins.standard.canvas, KaiBrandDefaultSkin.canvas);
    expect(
      SoundSkins.deepNight.glass.mutedText,
      KaiBrandDeepNightSkin.glassMutedText,
    );
    expect(SoundColors.defaultAccentPreset.accent, KaiProductAccents.coral);
    expect(SoundColors.webDav, KaiProductTokens.sourceWebDav);
    expect(SoundColors.local, KaiProductTokens.sourceLocal);
  });
}
