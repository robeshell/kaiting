import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/app_update/app_update_models.dart';
import 'package:kaiting/app_update/app_update_ui.dart';
import 'package:kaiting/core/sound_theme.dart';
import 'package:kaiting/presentation/widgets/sound_components.dart';

void main() {
  testWidgets('update feedback uses the shared dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: SoundTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () {
              showAppUpdateFlow(
                context,
                result: const AppUpdateUpToDate(currentVersion: '1.0.12'),
              );
            },
            child: const Text('检查'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('检查'));
    await tester.pumpAndSettle();

    expect(find.byType(SoundDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('已是最新版本（1.0.12）'), findsOneWidget);

    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
  });
}
