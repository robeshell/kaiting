import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/library_models.dart';
import '../controllers/library_user_state_controller.dart';

Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required LibraryUserStateController userState,
  required Track track,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) =>
        _AddToPlaylistSheet(userState: userState, track: track),
  );
}

Future<String?> showPlaylistNameDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String confirmLabel = '保存',
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _PlaylistNameDialog(
      title: title,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
    ),
  );
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const ValueKey('playlist-name-field'),
          controller: _controller,
          autofocus: true,
          maxLength: 100,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: '名称',
            hintText: '例如：通勤音乐',
          ),
          validator: (value) =>
              value == null || value.trim().isEmpty ? '请输入播放列表名称' : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('confirm-playlist-name'),
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() == true) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

class _AddToPlaylistSheet extends StatelessWidget {
  const _AddToPlaylistSheet({required this.userState, required this.track});

  final LibraryUserStateController userState;
  final Track track;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: AnimatedBuilder(
        animation: userState,
        builder: (context, _) {
          return ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '添加到播放列表',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: userState.playlists.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(28),
                          child: Center(
                            child: Text(
                              '还没有播放列表。新建一个后，这首歌会自动加入。',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white54),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: userState.playlists.length,
                          itemBuilder: (context, index) {
                            final playlist = userState.playlists[index];
                            final included = userState.playlistContainsTrack(
                              playlist.id,
                              track.id,
                            );
                            return CheckboxListTile(
                              key: ValueKey(
                                'playlist-membership-${playlist.id}-${track.id}',
                              ),
                              value: included,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(playlist.name),
                              subtitle: Text(
                                '${userState.playlistTrackCount(playlist.id)} 首歌',
                              ),
                              onChanged: (value) => unawaited(
                                userState.setTrackInPlaylist(
                                  playlist.id,
                                  track,
                                  included: value ?? false,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('create-playlist-from-track'),
                      onPressed: () => _createAndAdd(context),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('新建播放列表'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _createAndAdd(BuildContext context) async {
    final name = await showPlaylistNameDialog(
      context,
      title: '新建播放列表',
      confirmLabel: '新建',
    );
    if (name == null || !context.mounted) return;
    final playlistId = await userState.createPlaylist(name);
    if (playlistId == null) return;
    await userState.setTrackInPlaylist(playlistId, track, included: true);
  }
}
