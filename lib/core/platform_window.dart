import 'platform_window_stub.dart'
    if (dart.library.io) 'platform_window_io.dart'
    as implementation;

/// Minimizes the application window.
Future<void> minimizeWindow() => implementation.minimizeWindow();

/// Maximizes the application window.
Future<void> maximizeWindow() => implementation.maximizeWindow();

/// Restores the window from maximized or minimized state.
Future<void> restoreWindow() => implementation.restoreWindow();

/// Closes the application window.
Future<void> closeWindow() => implementation.closeWindow();

/// Returns whether the window is currently maximized.
Future<bool> isWindowMaximized() => implementation.isWindowMaximized();

/// Starts a window-drag operation from the current pointer position.
/// Call this from a title bar drag gesture handler.
Future<void> startWindowDrag() => implementation.startWindowDrag();

/// Whether this build paints custom minimize / maximize / close controls and
/// should treat Flutter chrome as the window drag surface.
///
/// Currently Windows-only: the native method channel lives in the Windows
/// runner. Linux UI must not advertise dead window buttons until a handler
/// exists there.
bool get supportsCustomWindowChrome =>
    implementation.supportsCustomWindowChrome;

/// Emits when the OS maximize / restore state changes (button, snap layout,
/// Win+Up, caption double-click, etc.).
Stream<bool> get windowMaximizedChanges =>
    implementation.windowMaximizedChanges;

/// Height (logical pixels) reserved for the custom-drawn title bar
/// on Windows and macOS.
double get platformTitleBarHeight => implementation.platformTitleBarHeight;
