import 'dart:io';

/// On Windows, just_audio_windows does not pass custom request headers to
/// WinRT MediaPlayer. On macOS, AVPlayer rejects self-signed certificates
/// even with ATS exceptions. In both cases the loopback proxy provides a
/// local HTTP endpoint so the native player never sees the remote TLS cert.
bool get useProxyForPlaybackRequestHeaders =>
    Platform.isWindows || Platform.isMacOS;
