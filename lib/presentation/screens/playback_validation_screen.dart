import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../../playback/playback_engine.dart';
import '../widgets/progress_scrubber.dart';

class PlaybackValidationScreen extends StatefulWidget {
  const PlaybackValidationScreen({
    required this.playback,
    required this.onBack,
    super.key,
  });

  final SoundPlaybackController playback;
  final VoidCallback onBack;

  @override
  State<PlaybackValidationScreen> createState() =>
      _PlaybackValidationScreenState();
}

class _PlaybackValidationScreenState extends State<PlaybackValidationScreen> {
  String? _selectedResource;
  bool _picking = false;

  Future<void> _pickLocalAudio() async {
    setState(() => _picking = true);
    try {
      final file = await openFile(
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'Audio',
            extensions: ['mp3', 'flac', 'm4a', 'aac', 'wav', 'ogg', 'opus'],
          ),
        ],
      );
      if (!mounted || file == null) return;
      final path = file.path;
      if (path.isEmpty) {
        _showMessage('当前平台没有返回可播放的本地路径。');
        return;
      }
      final track = Track(
        id: 'validation-local:$path',
        title: _titleWithoutExtension(file.name),
        artist: '本地文件',
        albumTitle: '播放验证',
        duration: Duration.zero,
        source: SourceKind.local,
        mediaUri: path,
      );
      setState(() => _selectedResource = path);
      await widget.playback.playTrack(track, queue: [track]);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _openWebDav() async {
    final request = await showDialog<_RemotePlaybackRequest>(
      context: context,
      builder: (context) => const _WebDavPlaybackDialog(),
    );
    if (request == null || !mounted) return;
    final headers = <String, String>{'Accept': '*/*', 'Range': 'bytes=0-'};
    if (request.username.isNotEmpty) {
      final token = base64Encode(
        utf8.encode('${request.username}:${request.password}'),
      );
      headers['Authorization'] = 'Basic $token';
    }
    final uri = Uri.tryParse(request.url);
    final filename = uri?.pathSegments.lastOrNull;
    final track = Track(
      id: 'validation-webdav:${request.url}',
      title: filename == null || filename.isEmpty
          ? 'WebDAV 验证音频'
          : _titleWithoutExtension(Uri.decodeComponent(filename)),
      artist: 'WebDAV',
      albumTitle: '远程播放验证',
      duration: Duration.zero,
      source: SourceKind.webDav,
      mediaUri: request.url,
      httpHeaders: headers,
    );
    setState(() => _selectedResource = request.url);
    await widget.playback.playTrack(track, queue: [track]);
  }

  String _titleWithoutExtension(String filename) {
    final dot = filename.lastIndexOf('.');
    return dot > 0 ? filename.substring(0, dot) : filename;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.playback,
      builder: (context, _) {
        final snapshot = widget.playback.snapshot;
        final duration = snapshot.duration;
        return ListView(
          padding: const EdgeInsets.fromLTRB(32, 24, 32, 140),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: widget.onBack,
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
                const SizedBox(width: 8),
                const Text(
                  '播放验证',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.only(left: 56),
              child: Text(
                '先验证真实文件、WebDAV、缓冲与 seek；此页面不会成为正式产品入口。',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _picking ? null : _pickLocalAudio,
                  icon: _picking
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.audio_file_rounded),
                  label: const Text('选择本地音频'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoundColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _openWebDav,
                  icon: const Icon(Icons.cloud_outlined),
                  label: const Text('输入 WebDAV 文件 URL'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _StatusCard(
              snapshot: snapshot,
              resource: _selectedResource,
              onToggle: widget.playback.toggle,
              onPrevious: widget.playback.previous,
              onNext: widget.playback.next,
              onSeek: widget.playback.seek,
              duration: duration,
            ),
            const SizedBox(height: 22),
            const _InvariantCard(),
          ],
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.snapshot,
    required this.resource,
    required this.onToggle,
    required this.onPrevious,
    required this.onNext,
    required this.onSeek,
    required this.duration,
  });

  final PlaybackSnapshot snapshot;
  final String? resource;
  final VoidCallback onToggle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<Duration> onSeek;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final phaseColor = switch (snapshot.phase) {
      PlaybackPhase.playing => SoundColors.local,
      PlaybackPhase.buffering || PlaybackPhase.loading => Colors.amberAccent,
      PlaybackPhase.error => SoundColors.accent,
      _ => Colors.white54,
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.11)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: phaseColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                _phaseLabel(snapshot.phase),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${formatDuration(snapshot.position)} / ${formatDuration(duration)}',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            snapshot.track?.title ?? '尚未选择音频',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            resource ?? '选择文件后，所有进度都必须来自原生播放引擎。',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ProgressScrubber(
            position: snapshot.position,
            duration: duration,
            onSeek: onSeek,
            activeColor: SoundColors.accent,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: onToggle,
                icon: Icon(
                  snapshot.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: onNext,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ],
          ),
          if (snapshot.errorMessage case final message?) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _phaseLabel(PlaybackPhase phase) => switch (phase) {
    PlaybackPhase.idle => '空闲',
    PlaybackPhase.loading => '正在载入',
    PlaybackPhase.ready => '已就绪',
    PlaybackPhase.playing => '正在播放',
    PlaybackPhase.paused => '已暂停',
    PlaybackPhase.buffering => '正在缓冲',
    PlaybackPhase.completed => '播放完成',
    PlaybackPhase.error => '播放错误',
  };
}

class _InvariantCard extends StatelessWidget {
  const _InvariantCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '本阶段必须守住',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        SizedBox(height: 12),
        _Invariant('界面不运行播放计时器，只消费引擎 position stream。'),
        _Invariant('拖动期间只显示预览，松手只发送一次 seek。'),
        _Invariant('新歌曲使用新 session ID，旧回调直接丢弃。'),
        _Invariant('缓冲、暂停、完成和错误是不同状态。'),
      ],
    );
  }
}

class _Invariant extends StatelessWidget {
  const _Invariant(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: SoundColors.local,
            size: 17,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebDavPlaybackDialog extends StatefulWidget {
  const _WebDavPlaybackDialog();

  @override
  State<_WebDavPlaybackDialog> createState() => _WebDavPlaybackDialogState();
}

class _WebDavPlaybackDialogState extends State<_WebDavPlaybackDialog> {
  final _url = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _url.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('WebDAV 播放验证'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _url,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: '音频文件完整 URL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _username,
              decoration: const InputDecoration(labelText: '用户名（可选）'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: '密码（仅本次使用）'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final uri = Uri.tryParse(_url.text.trim());
            if (uri == null || !uri.hasScheme || !uri.hasAuthority) return;
            Navigator.pop(
              context,
              _RemotePlaybackRequest(
                url: uri.toString(),
                username: _username.text,
                password: _password.text,
              ),
            );
          },
          child: const Text('开始验证'),
        ),
      ],
    );
  }
}

class _RemotePlaybackRequest {
  const _RemotePlaybackRequest({
    required this.url,
    required this.username,
    required this.password,
  });

  final String url;
  final String username;
  final String password;
}
