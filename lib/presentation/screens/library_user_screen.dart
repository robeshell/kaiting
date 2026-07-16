import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../library/library_records.dart';
import '../../playback/playback_controller.dart';
import '../controllers/library_catalog_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../models/library_source_filter.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/sound_components.dart';

enum LibraryUserBrowseMode { favorites, recent, playlists }

extension LibraryUserBrowseModePresentation on LibraryUserBrowseMode {
  String get label => switch (this) {
    LibraryUserBrowseMode.favorites => '收藏',
    LibraryUserBrowseMode.recent => '最近播放',
    LibraryUserBrowseMode.playlists => '播放列表',
  };

  IconData get icon => switch (this) {
    LibraryUserBrowseMode.favorites => Icons.favorite_rounded,
    LibraryUserBrowseMode.recent => Icons.history_toggle_off_rounded,
    LibraryUserBrowseMode.playlists => Icons.queue_music_rounded,
  };
}

List<SoundChoiceOption<LibraryUserBrowseMode>> _userBrowseOptions() => [
  for (final mode in LibraryUserBrowseMode.values)
    SoundChoiceOption(
      key: ValueKey('user-library-mode-${mode.name}'),
      value: mode,
      label: mode.label,
      icon: mode.icon,
    ),
];

class LibraryUserScreen extends StatefulWidget {
  const LibraryUserScreen({
    required this.mode,
    required this.catalog,
    required this.userState,
    required this.playback,
    required this.onModeChanged,
    required this.onBack,
    required this.onOpenAlbum,
    required this.selectedPlaylistId,
    required this.onSelectedPlaylistChanged,
    super.key,
  });

  final LibraryUserBrowseMode mode;
  final LibraryCatalogController catalog;
  final LibraryUserStateController userState;
  final SoundPlaybackController playback;
  final ValueChanged<LibraryUserBrowseMode> onModeChanged;
  final VoidCallback onBack;
  final ValueChanged<Album> onOpenAlbum;
  final int? selectedPlaylistId;
  final ValueChanged<int?> onSelectedPlaylistChanged;

  @override
  State<LibraryUserScreen> createState() => _LibraryUserScreenState();
}

class _LibraryUserScreenState extends State<LibraryUserScreen> {
  LibrarySourceFilter _sourceFilter = LibrarySourceFilter.all;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.catalog, widget.userState]),
        builder: (context, _) {
          final compact = context.soundIsCompact;
          if (widget.mode == LibraryUserBrowseMode.playlists) {
            return _buildPlaylists();
          }
          final albumByTrackId = {
            for (final album in widget.catalog.albums)
              for (final track in album.tracks) track.id: album,
          };
          final favoriteIds = widget.userState.favoriteTrackIds;
          final rawTracks = switch (widget.mode) {
            LibraryUserBrowseMode.favorites => widget.userState.favoriteTracks,
            LibraryUserBrowseMode.recent => widget.userState.recentTracks,
            LibraryUserBrowseMode.playlists => const <Track>[],
          };
          final tracks = _filterTracks(rawTracks);
          final sourceOptions = LibrarySourceFilter.options([
            for (final track in rawTracks) track.source,
          ]);
          final resultCount = tracks.length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.soundPageGutter,
                  compact ? 10 : 24,
                  context.soundPageGutter,
                  compact ? 10 : 18,
                ),
                sliver: SliverToBoxAdapter(
                  child: _UserLibraryHeader(
                    mode: widget.mode,
                    sourceFilter: _sourceFilter,
                    sourceOptions: sourceOptions,
                    onModeChanged: widget.onModeChanged,
                    onSourceChanged: (value) =>
                        setState(() => _sourceFilter = value),
                    onBack: widget.onBack,
                    onClearHistory:
                        widget.mode == LibraryUserBrowseMode.favorites ||
                            widget.userState.historyItems.isEmpty
                        ? null
                        : _confirmClearHistory,
                  ),
                ),
              ),
              if (widget.userState.isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (widget.userState.errorMessage case final message?)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _UserLibraryMessage(
                    icon: Icons.error_outline_rounded,
                    title: '无法读取我的音乐',
                    message: message,
                  ),
                )
              else if (resultCount == 0)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyMessage(widget.mode),
                )
              else
                _trackSliver(tracks, albumByTrackId, favoriteIds),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPlaylists() {
    final compact = context.soundIsCompact;
    final selectedPlaylist = widget.selectedPlaylistId == null
        ? null
        : widget.userState.playlistById(widget.selectedPlaylistId!);
    if (selectedPlaylist == null) {
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.soundPageGutter,
              compact ? 10 : 24,
              context.soundPageGutter,
              compact ? 10 : 18,
            ),
            sliver: SliverToBoxAdapter(
              child: _PlaylistOverviewHeader(
                onModeChanged: widget.onModeChanged,
                onBack: widget.onBack,
                onCreate: _createPlaylist,
              ),
            ),
          ),
          if (widget.userState.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (widget.userState.errorMessage case final message?)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _UserLibraryMessage(
                icon: Icons.error_outline_rounded,
                title: '无法读取播放列表',
                message: message,
              ),
            )
          else if (widget.userState.playlists.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _UserLibraryMessage(
                icon: Icons.queue_music_rounded,
                title: '还没有播放列表',
                message: '新建一个播放列表，或从任意歌曲的操作菜单中直接添加。',
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.soundPageGutter,
                0,
                context.soundPageGutter,
                context.soundContentBottomPadding,
              ),
              sliver: SliverList.builder(
                itemCount: widget.userState.playlists.length,
                itemBuilder: (context, index) {
                  final playlist = widget.userState.playlists[index];
                  return _PlaylistTile(
                    key: ValueKey('playlist-${playlist.id}'),
                    playlist: playlist,
                    trackCount: widget.userState.playlistTrackCount(
                      playlist.id,
                    ),
                    missingTrackCount: widget.userState
                        .missingPlaylistTrackCount(playlist.id),
                    onTap: () => widget.onSelectedPlaylistChanged(playlist.id),
                    onPlay: () {
                      final tracks = widget.userState.tracksForPlaylist(
                        playlist.id,
                      );
                      if (tracks.isNotEmpty) {
                        unawaited(
                          widget.playback.playTrack(
                            tracks.first,
                            queue: tracks,
                          ),
                        );
                      }
                    },
                    onRename: () => _renamePlaylist(playlist),
                    onDelete: () => _deletePlaylist(playlist),
                  );
                },
              ),
            ),
        ],
      );
    }

    final tracks = widget.userState.tracksForPlaylist(selectedPlaylist.id);
    final albumByTrackId = {
      for (final album in widget.catalog.albums)
        for (final track in album.tracks) track.id: album,
    };
    final missingCount = widget.userState.missingPlaylistTrackCount(
      selectedPlaylist.id,
    );
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            context.soundPageGutter,
            compact ? 10 : 24,
            context.soundPageGutter,
            compact ? 10 : 18,
          ),
          sliver: SliverToBoxAdapter(
            child: _PlaylistDetailHeader(
              playlist: selectedPlaylist,
              availableTrackCount: tracks.length,
              missingTrackCount: missingCount,
              onBack: () => widget.onSelectedPlaylistChanged(null),
              onPlay: tracks.isEmpty
                  ? null
                  : () => unawaited(
                      widget.playback.playTrack(tracks.first, queue: tracks),
                    ),
              onRename: () => _renamePlaylist(selectedPlaylist),
              onDelete: () => _deletePlaylist(selectedPlaylist),
            ),
          ),
        ),
        if (tracks.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _UserLibraryMessage(
              icon: Icons.music_note_rounded,
              title: missingCount == 0 ? '播放列表是空的' : '歌曲来源暂不可用',
              message: missingCount == 0
                  ? '从资料库、搜索或播放页面把歌曲添加到这里。'
                  : '已保留 $missingCount 首歌，重新连接对应来源后会自动恢复。',
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              context.soundPageGutter,
              0,
              context.soundPageGutter,
              context.soundContentBottomPadding,
            ),
            sliver: SliverReorderableList(
              itemCount: tracks.length,
              onReorderItem: (oldIndex, newIndex) => _reorderPlaylist(
                selectedPlaylist.id,
                tracks,
                oldIndex,
                newIndex,
              ),
              itemBuilder: (context, index) {
                final track = tracks[index];
                final album = albumByTrackId[track.id]!;
                return _PlaylistTrackRow(
                  key: ValueKey(
                    'playlist-${selectedPlaylist.id}-track-${track.id}',
                  ),
                  index: index,
                  track: track,
                  album: album,
                  favorite: widget.userState.isFavorite(track.id),
                  onTap: () => widget.playback.playTrack(track, queue: tracks),
                  onPlayNext: () => widget.playback.playNext(track),
                  onToggleFavorite: () =>
                      unawaited(widget.userState.toggleFavorite(track)),
                  onAddToPlaylist: () => showAddToPlaylistSheet(
                    context,
                    userState: widget.userState,
                    track: track,
                  ),
                  onRemove: () => unawaited(
                    widget.userState.setTrackInPlaylist(
                      selectedPlaylist.id,
                      track,
                      included: false,
                    ),
                  ),
                  onOpenAlbum: () => widget.onOpenAlbum(album),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _createPlaylist() async {
    final name = await showPlaylistNameDialog(
      context,
      title: '新建播放列表',
      confirmLabel: '新建',
    );
    if (name == null || !mounted) return;
    final playlistId = await widget.userState.createPlaylist(name);
    if (playlistId != null && mounted) {
      widget.onSelectedPlaylistChanged(playlistId);
    }
  }

  Future<void> _renamePlaylist(LibraryPlaylistRecord playlist) async {
    final name = await showPlaylistNameDialog(
      context,
      title: '重命名播放列表',
      initialValue: playlist.name,
    );
    if (name != null) {
      await widget.userState.renamePlaylist(playlist.id, name);
    }
  }

  Future<void> _deletePlaylist(LibraryPlaylistRecord playlist) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SoundDialog(
        maxWidth: 460,
        title: const Text('删除播放列表？'),
        content: Text('“${playlist.name}”会被删除，资料库中的歌曲不会受到影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const ValueKey('confirm-delete-playlist'),
            onPressed: () => Navigator.of(context).pop(true),
            style: context.soundDestructiveButtonStyle,
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await widget.userState.deletePlaylist(playlist.id);
    if (deleted && mounted && widget.selectedPlaylistId == playlist.id) {
      widget.onSelectedPlaylistChanged(null);
    }
  }

  void _reorderPlaylist(
    int playlistId,
    List<Track> tracks,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex == oldIndex) return;
    final reordered = List<Track>.of(tracks);
    final track = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, track);
    unawaited(widget.userState.reorderPlaylist(playlistId, reordered));
  }

  List<Track> _filterTracks(List<Track> tracks) {
    return [
      for (final track in tracks)
        if (_matchesSource(track)) track,
    ];
  }

  bool _matchesSource(Track track) => _sourceFilter.matches(track.source);

  Widget _trackSliver(
    List<Track> tracks,
    Map<String, Album> albumByTrackId,
    Set<String> favoriteIds,
  ) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        context.soundPageGutter,
        0,
        context.soundPageGutter,
        context.soundContentBottomPadding,
      ),
      sliver: SliverPrototypeExtentList.builder(
        itemCount: tracks.length,
        prototypeItem: _UserTrackRow(
          track: tracks.first,
          album: albumByTrackId[tracks.first.id]!,
          favorite: favoriteIds.contains(tracks.first.id),
          onTap: () {},
          onToggleFavorite: () {},
          onAddToPlaylist: () {},
          onOpenAlbum: () {},
        ),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final album = albumByTrackId[track.id]!;
          return _UserTrackRow(
            key: ValueKey('user-library-track-${widget.mode.name}-${track.id}'),
            track: track,
            album: album,
            favorite: favoriteIds.contains(track.id),
            onTap: () => widget.playback.playTrack(track, queue: tracks),
            onToggleFavorite: () =>
                unawaited(widget.userState.toggleFavorite(track)),
            onAddToPlaylist: () => showAddToPlaylistSheet(
              context,
              userState: widget.userState,
              track: track,
            ),
            onOpenAlbum: () => widget.onOpenAlbum(album),
          );
        },
      ),
    );
  }

  _UserLibraryMessage _emptyMessage(LibraryUserBrowseMode mode) {
    return switch (mode) {
      LibraryUserBrowseMode.favorites => const _UserLibraryMessage(
        icon: Icons.favorite_border_rounded,
        title: '还没有收藏歌曲',
        message: '在专辑、播放页面或迷你播放器中点按爱心，歌曲会出现在这里。',
      ),
      LibraryUserBrowseMode.recent => const _UserLibraryMessage(
        icon: Icons.history_toggle_off_rounded,
        title: '还没有最近播放',
        message: '开始播放资料库中的歌曲后，最近播放会自动更新。',
      ),
      LibraryUserBrowseMode.playlists => const _UserLibraryMessage(
        icon: Icons.queue_music_rounded,
        title: '还没有播放列表',
        message: '新建一个播放列表，或从任意歌曲的操作菜单中直接添加。',
      ),
    };
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => SoundDialog(
        maxWidth: 460,
        title: const Text('清除播放历史？'),
        content: const Text('最近播放和完整播放历史都会被清除，收藏不会受到影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: context.soundDestructiveButtonStyle,
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.userState.clearHistory();
  }
}

class _PlaylistOverviewHeader extends StatelessWidget {
  const _PlaylistOverviewHeader({
    required this.onModeChanged,
    required this.onBack,
    required this.onCreate,
  });

  final ValueChanged<LibraryUserBrowseMode> onModeChanged;
  final VoidCallback onBack;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (compact)
              IconButton(
                onPressed: onBack,
                tooltip: '返回资料库',
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            const Spacer(),
            FilledButton.icon(
              key: const ValueKey('create-playlist'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded),
              label: const Text('新建'),
            ),
          ],
        ),
        if (compact) ...[
          const SizedBox(height: 12),
          SoundChoiceStrip<LibraryUserBrowseMode>(
            options: _userBrowseOptions(),
            selected: LibraryUserBrowseMode.playlists,
            onSelected: onModeChanged,
          ),
        ],
      ],
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  const _PlaylistTile({
    required this.playlist,
    required this.trackCount,
    required this.missingTrackCount,
    required this.onTap,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
    super.key,
  });

  final LibraryPlaylistRecord playlist;
  final int trackCount;
  final int missingTrackCount;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 68,
          padding: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.soundDivider.withValues(
                  alpha: context.soundDivider.a * 0.72,
                ),
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Icon(
                  Icons.queue_music_rounded,
                  size: 18,
                  color: SoundColors.accent.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.soundPrimaryText.withValues(
                          alpha: context.soundPrimaryText.a * 0.92,
                        ),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      missingTrackCount == 0
                          ? '$trackCount 首歌'
                          : '$trackCount 首歌 · $missingTrackCount 首来源暂不可用',
                      style: TextStyle(
                        color: context.soundMutedText.withValues(
                          alpha: context.soundMutedText.a * 0.82,
                        ),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: ValueKey('playlist-actions-${playlist.id}'),
                tooltip: '播放列表操作',
                icon: const Icon(Icons.more_horiz_rounded, size: 20),
                onSelected: (value) {
                  if (value == 'play') onPlay();
                  if (value == 'rename') onRename();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'play',
                    enabled: trackCount > missingTrackCount,
                    child: const Text('播放'),
                  ),
                  const PopupMenuItem(value: 'rename', child: Text('重命名')),
                  const PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistDetailHeader extends StatelessWidget {
  const _PlaylistDetailHeader({
    required this.playlist,
    required this.availableTrackCount,
    required this.missingTrackCount,
    required this.onBack,
    required this.onPlay,
    required this.onRename,
    required this.onDelete,
  });

  final LibraryPlaylistRecord playlist;
  final int availableTrackCount;
  final int missingTrackCount;
  final VoidCallback onBack;
  final VoidCallback? onPlay;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final summary = [
      '$availableTrackCount 首可播放',
      if (missingTrackCount > 0) '$missingTrackCount 首来源暂不可用',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          key: const ValueKey('back-to-playlists'),
          onPressed: onBack,
          tooltip: '返回播放列表',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(height: 14),
        Text(
          playlist.name,
          style: TextStyle(
            fontSize: context.soundPageTitleSize,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 6),
        Text(summary, style: TextStyle(color: context.soundMutedText)),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('play-playlist'),
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('播放'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('rename-playlist'),
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('重命名'),
            ),
            TextButton.icon(
              key: const ValueKey('delete-playlist'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('删除'),
              style: context.soundDestructiveButtonStyle,
            ),
          ],
        ),
      ],
    );
  }
}

class _PlaylistTrackRow extends StatelessWidget {
  const _PlaylistTrackRow({
    required this.index,
    required this.track,
    required this.album,
    required this.favorite,
    required this.onTap,
    required this.onPlayNext,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onRemove,
    required this.onOpenAlbum,
    super.key,
  });

  final int index;
  final Track track;
  final Album album;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onPlayNext;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onRemove;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return SoundTrackActivation(
      onActivate: onTap,
      semanticLabel: track.title,
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: context.soundDivider.withValues(
                  alpha: context.soundDivider.a * 0.72,
                ),
              ),
            ),
          ),
          child: compact
              ? SizedBox(
                  key: ValueKey('playlist-track-row-${track.id}'),
                  height: 64,
                  child: Row(
                    children: [
                      SizedBox.square(
                        dimension: 44,
                        child: AlbumArt(album: album, borderRadius: 8),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: _PlaylistTrackLabels(track: track, album: album),
                      ),
                      _playlistActions(),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            size: 20,
                            color: context.soundMutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 5),
                  leading: SizedBox.square(
                    dimension: 48,
                    child: AlbumArt(album: album, borderRadius: 6),
                  ),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.soundPrimaryText.withValues(
                        alpha: context.soundPrimaryText.a * 0.92,
                      ),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    '${track.artist} · ${album.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.soundMutedText.withValues(
                        alpha: context.soundMutedText.a * 0.82,
                      ),
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _playlistActions(),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            Icons.drag_handle_rounded,
                            color: context.soundMutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _playlistActions() {
    return PopupMenuButton<String>(
      key: ValueKey('playlist-track-actions-${track.id}'),
      tooltip: '歌曲操作',
      icon: const Icon(Icons.more_horiz_rounded, size: 21),
      onSelected: (value) {
        if (value == 'play-next') onPlayNext();
        if (value == 'favorite') onToggleFavorite();
        if (value == 'add') onAddToPlaylist();
        if (value == 'album') onOpenAlbum();
        if (value == 'remove') onRemove();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'play-next', child: Text('下一首播放')),
        PopupMenuItem(
          value: 'favorite',
          child: Text(favorite ? '取消收藏' : '收藏歌曲'),
        ),
        const PopupMenuItem(value: 'add', child: Text('添加到其他播放列表')),
        const PopupMenuItem(value: 'album', child: Text('打开专辑')),
        const PopupMenuItem(value: 'remove', child: Text('从此列表移除')),
      ],
    );
  }
}

class _PlaylistTrackLabels extends StatelessWidget {
  const _PlaylistTrackLabels({required this.track, required this.album});

  final Track track;
  final Album album;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          track.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: context.soundPrimaryText.withValues(
              alpha: context.soundPrimaryText.a * 0.92,
            ),
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${track.artist} · ${album.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            color: context.soundMutedText.withValues(
              alpha: context.soundMutedText.a * 0.82,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserLibraryHeader extends StatelessWidget {
  const _UserLibraryHeader({
    required this.mode,
    required this.sourceFilter,
    required this.sourceOptions,
    required this.onModeChanged,
    required this.onSourceChanged,
    required this.onBack,
    required this.onClearHistory,
  });

  final LibraryUserBrowseMode mode;
  final LibrarySourceFilter sourceFilter;
  final List<LibrarySourceFilter> sourceOptions;
  final ValueChanged<LibraryUserBrowseMode> onModeChanged;
  final ValueChanged<LibrarySourceFilter> onSourceChanged;
  final VoidCallback onBack;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (compact || onClearHistory != null)
          Row(
            children: [
              if (compact)
                IconButton(
                  onPressed: onBack,
                  tooltip: '返回资料库',
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              const Spacer(),
              if (onClearHistory != null)
                TextButton.icon(
                  onPressed: onClearHistory,
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('清除历史'),
                  style: context.soundDestructiveButtonStyle,
                ),
            ],
          ),
        if (compact) ...[
          const SizedBox(height: 12),
          SoundChoiceStrip<LibraryUserBrowseMode>(
            options: _userBrowseOptions(),
            selected: mode,
            onSelected: onModeChanged,
          ),
        ],
        if ((compact || onClearHistory != null) && sourceOptions.isNotEmpty)
          const SizedBox(height: 12),
        SoundChoiceStrip<LibrarySourceFilter>(
          options: [
            for (final filter in sourceOptions)
              SoundChoiceOption(value: filter, label: filter.label),
          ],
          selected: sourceFilter,
          onSelected: onSourceChanged,
          wrap: true,
        ),
      ],
    );
  }
}

class _UserTrackRow extends StatelessWidget {
  const _UserTrackRow({
    required this.track,
    required this.album,
    required this.favorite,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
    required this.onOpenAlbum,
    super.key,
  });

  final Track track;
  final Album album;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return SoundTrackListRow(
      key: ValueKey('user-track-row-${track.id}'),
      leading: AlbumArt(
        album: album,
        borderRadius: context.soundIsCompact ? 8 : 6,
      ),
      title: track.title,
      subtitle: '${track.artist} · ${album.title}',
      onActivate: onTap,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: ValueKey('favorite-track-${track.id}'),
            onPressed: onToggleFavorite,
            tooltip: favorite ? '取消收藏 ${track.title}' : '收藏 ${track.title}',
            color: favorite ? SoundColors.accent : null,
            icon: Icon(
              favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            ),
          ),
          IconButton(
            key: ValueKey('add-user-${track.id}-to-playlist'),
            onPressed: onAddToPlaylist,
            tooltip: '将 ${track.title} 添加到播放列表',
            icon: const Icon(Icons.playlist_add_rounded),
          ),
          IconButton(
            onPressed: onOpenAlbum,
            tooltip: '打开专辑 ${album.title}',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      compactTrailing: PopupMenuButton<String>(
        key: ValueKey('user-track-actions-${track.id}'),
        tooltip: '更多操作 ${track.title}',
        icon: const Icon(Icons.more_horiz_rounded, size: 21),
        onSelected: (value) {
          if (value == 'favorite') onToggleFavorite();
          if (value == 'playlist') onAddToPlaylist();
          if (value == 'album') onOpenAlbum();
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'favorite',
            child: Text(favorite ? '取消收藏' : '收藏'),
          ),
          const PopupMenuItem(value: 'playlist', child: Text('添加到播放列表')),
          const PopupMenuItem(value: 'album', child: Text('打开专辑')),
        ],
      ),
    );
  }
}

class _UserLibraryMessage extends StatelessWidget {
  const _UserLibraryMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return SoundEmptyState(icon: icon, title: title, message: message);
  }
}
