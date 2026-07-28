import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../playback/playback_controller.dart';

/// Playback shortcuts shared by every route in the application navigator.
///
/// This must sit outside the Navigator so pushed pages such as now-playing
/// remain inside the shortcut scope.
class PlaybackKeyboardShortcuts extends StatelessWidget {
  const PlaybackKeyboardShortcuts({
    required this.playback,
    required this.child,
    super.key,
  });

  final SoundPlaybackController playback;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const _NonEditingActivator(
          SingleActivator(LogicalKeyboardKey.space),
        ): () =>
            unawaited(playback.toggle()),
        const SingleActivator(LogicalKeyboardKey.mediaPlayPause): () =>
            unawaited(playback.toggle()),
        const SingleActivator(LogicalKeyboardKey.mediaTrackNext): () =>
            unawaited(playback.next()),
        const SingleActivator(LogicalKeyboardKey.mediaTrackPrevious): () =>
            unawaited(playback.previous()),
        const _NonEditingActivator(
          SingleActivator(LogicalKeyboardKey.arrowRight, control: true),
        ): () =>
            unawaited(playback.next()),
        const _NonEditingActivator(
          SingleActivator(LogicalKeyboardKey.arrowLeft, control: true),
        ): () =>
            unawaited(playback.previous()),
        const _NonEditingActivator(
          SingleActivator(LogicalKeyboardKey.arrowRight, meta: true),
        ): () =>
            unawaited(playback.next()),
        const _NonEditingActivator(
          SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true),
        ): () =>
            unawaited(playback.previous()),
      },
      child: child,
    );
  }
}

class _NonEditingActivator extends ShortcutActivator {
  const _NonEditingActivator(this.activator);

  final SingleActivator activator;

  @override
  Iterable<LogicalKeyboardKey> get triggers => activator.triggers;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) =>
      activator.accepts(event, state) && !_isTextEditingFocusActive();

  @override
  String debugDescribeKeys() => activator.debugDescribeKeys();
}

bool _isTextEditingFocusActive() {
  final focusContext = FocusManager.instance.primaryFocus?.context;
  if (focusContext == null) return false;
  return focusContext.widget is EditableText ||
      focusContext.findAncestorWidgetOfExactType<EditableText>() != null;
}
