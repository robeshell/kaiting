import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/presentation/widgets/karaoke_lyric_text.dart';

void main() {
  testWidgets('karaoke fill paints without error for wrapped centered text', (
    tester,
  ) async {
    final tick = ChangeNotifier();
    var progress = 0.4;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 120,
              child: KaraokeLyricText(
                '这是一句会换行的中文歌词测试文字',
                style: const TextStyle(fontSize: 20, height: 1.4),
                textAlign: TextAlign.center,
                progressListenable: tick,
                progressOf: () => progress,
                fillColor: Colors.black,
                baseColor: Colors.black38,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(KaraokeLyricText), findsOneWidget);
    expect(tester.takeException(), isNull);

    progress = 0.85;
    tick.notifyListeners();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
