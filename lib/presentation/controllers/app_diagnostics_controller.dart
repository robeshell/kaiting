import 'package:flutter/foundation.dart';

import '../../core/app_failure.dart';

enum DiagnosticArea { playback, source, library, download, application }

class DiagnosticEvent {
  const DiagnosticEvent({
    required this.id,
    required this.occurredAt,
    required this.area,
    required this.failure,
    this.context,
  });

  final int id;
  final DateTime occurredAt;
  final DiagnosticArea area;
  final AppFailure failure;
  final String? context;
}

class AppDiagnosticsController extends ChangeNotifier {
  AppDiagnosticsController({this.maximumEvents = 100});

  final int maximumEvents;
  final List<DiagnosticEvent> _events = [];
  DiagnosticEvent? _activeEvent;
  int _nextId = 1;

  List<DiagnosticEvent> get events => List.unmodifiable(_events);
  DiagnosticEvent? get activeEvent => _activeEvent;
  int get problemCount => _events.length;

  DiagnosticEvent record({
    required DiagnosticArea area,
    required AppFailure failure,
    String? context,
    bool present = true,
  }) {
    final safeFailure = AppFailure(
      kind: failure.kind,
      title: failure.title,
      message: failure.message,
      action: failure.action,
      rawMessage: _redactDiagnosticText(failure.rawMessage),
    );
    final safeContext = context == null ? null : _redactDiagnosticText(context);
    final previous = _events.lastOrNull;
    if (previous != null &&
        previous.area == area &&
        previous.failure.kind == safeFailure.kind &&
        previous.failure.rawMessage == safeFailure.rawMessage &&
        previous.context == safeContext) {
      if (present) _activeEvent = previous;
      notifyListeners();
      return previous;
    }
    final event = DiagnosticEvent(
      id: _nextId++,
      occurredAt: DateTime.now().toUtc(),
      area: area,
      failure: safeFailure,
      context: safeContext,
    );
    _events.add(event);
    if (_events.length > maximumEvents) _events.removeAt(0);
    if (present) _activeEvent = event;
    notifyListeners();
    return event;
  }

  void dismissActive() {
    if (_activeEvent == null) return;
    _activeEvent = null;
    notifyListeners();
  }

  void clear() {
    if (_events.isEmpty && _activeEvent == null) return;
    _events.clear();
    _activeEvent = null;
    notifyListeners();
  }

  String exportText() {
    if (_events.isEmpty) return '开听 诊断记录\n没有已记录的问题。';
    final buffer = StringBuffer('开听 诊断记录\n');
    for (final event in _events.reversed) {
      buffer
        ..writeln(
          '${event.occurredAt.toIso8601String()} '
          '[${event.area.name}/${event.failure.kind.name}] '
          '${event.failure.title}',
        )
        ..writeln('  ${event.failure.rawMessage}');
      if (event.context case final context?) buffer.writeln('  $context');
    }
    return buffer.toString().trimRight();
  }
}

String _redactDiagnosticText(String value) {
  var result = value.replaceAllMapped(
    RegExp(
      r'(authorization\s*:\s*)(basic|bearer)\s+[^\s,;]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)} [REDACTED]',
  );
  result = result.replaceAllMapped(
    RegExp(
      r'(password|passwd|pwd)(\s*[:=]\s*)[^\s&,;}]+',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)}[REDACTED]',
  );
  return result.replaceAllMapped(
    RegExp(
      r'([a-z][a-z0-9+.-]*://)([^/\s:@]+):([^@\s/]+)@',
      caseSensitive: false,
    ),
    (match) => '${match.group(1)}${match.group(2)}:[REDACTED]@',
  );
}
