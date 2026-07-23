import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/core/app_failure.dart';
import 'package:kaiting/presentation/controllers/app_diagnostics_controller.dart';

void main() {
  test('classifies actionable source and playback failures', () {
    expect(
      AppFailure.fromMessage('HTTP 401 Unauthorized').kind,
      AppFailureKind.authentication,
    );
    expect(
      AppFailure.fromMessage('Connection timed out').kind,
      AppFailureKind.timeout,
    );
    expect(
      AppFailure.fromMessage('HTTP 404 Not Found').kind,
      AppFailureKind.notFound,
    );
    expect(
      AppFailure.fromMessage('HTTP 503').kind,
      AppFailureKind.serverUnavailable,
    );
    expect(
      AppFailure.fromMessage('Unsupported format decoder').kind,
      AppFailureKind.damagedMedia,
    );
  });

  test('diagnostics deduplicate identical consecutive failures and export', () {
    final diagnostics = AppDiagnosticsController(maximumEvents: 2);
    addTearDown(diagnostics.dispose);
    final failure = AppFailure.fromMessage('HTTP 503');

    diagnostics.record(
      area: DiagnosticArea.source,
      failure: failure,
      context: 'Public WebDAV',
    );
    diagnostics.record(
      area: DiagnosticArea.source,
      failure: failure,
      context: 'Public WebDAV',
    );

    expect(diagnostics.events, hasLength(1));
    expect(diagnostics.activeEvent, isNotNull);
    expect(diagnostics.exportText(), contains('Public WebDAV'));
    expect(diagnostics.exportText(), isNot(contains('password')));

    diagnostics.dismissActive();
    expect(diagnostics.activeEvent, isNull);
    diagnostics.clear();
    expect(diagnostics.events, isEmpty);
  });

  test('diagnostics redact credentials from cards and exported text', () {
    final diagnostics = AppDiagnosticsController();
    addTearDown(diagnostics.dispose);

    diagnostics.record(
      area: DiagnosticArea.source,
      failure: AppFailure.fromMessage(
        'Authorization: Basic abc123 password=hunter2 '
        'https://jay:secret@example.com/music',
      ),
    );

    final event = diagnostics.events.single;
    expect(event.failure.rawMessage, isNot(contains('abc123')));
    expect(event.failure.rawMessage, isNot(contains('hunter2')));
    expect(event.failure.rawMessage, isNot(contains('secret')));
    expect(diagnostics.exportText(), contains('[REDACTED]'));
  });
}
