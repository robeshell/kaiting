// Stub implementations for platforms without native window controls
// (web, and any platform where dart:io is unavailable).

import 'dart:async';

Future<void> minimizeWindow() async {}
Future<void> maximizeWindow() async {}
Future<void> restoreWindow() async {}
Future<void> closeWindow() async {}
Future<bool> isWindowMaximized() async => false;
Future<void> startWindowDrag() async {}

bool get supportsCustomWindowChrome => false;

Stream<bool> get windowMaximizedChanges => const Stream<bool>.empty();

double get platformTitleBarHeight => 0;
