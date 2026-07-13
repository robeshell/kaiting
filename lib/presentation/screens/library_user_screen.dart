import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../controllers/library_catalog_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/album_art.dart';

enum LibraryUserBrowseMode { favorites, recent, history }

extension LibraryUserBrowseModePresentation on LibraryUserBrowseMode {
  String get label => switch (this) {
    LibraryUserBrowseMode.favorites => '收藏',
    LibraryUserBrowseMode.recent => '最近播放',
    LibraryUserBrowseMode.history => '播放历史',
  };

  IconData get icon => switch (this) {
    LibraryUserBrowseMode.favorites => Icons.favorite_rounded,
    LibraryUserBrowseMode.recent => Icons.history_toggle_off_rounded,
    LibraryUserBrowseMode.history => Icons.history_rounded,
  };
}

enum _UserSourceFilter { all, local, webDav }

class LibraryUserScreen extends StatefulWidget {
  const LibraryUserScreen({
    required this.mode,
    required this.catalog,
    required this.userState,
    required this.playback,
    required this.onModeChanged,
    required this.onBack,
    required this.onOpenAlbum,
    super.key,
  });

  final LibraryUserBrowseMode mode;
  final LibraryCatalogController catalog;
  final LibraryUserStateController userState;
  final SoundPlaybackController playback;
  final ValueChanged<LibraryUserBrowseMode> onModeChanged;
  final VoidCallback onBack;
  final ValueChanged<Album> onOpenAlbum;

  @override
  State<LibraryUserScreen> createState() => _LibraryUserScreenState();
}

class _LibraryUserScreenState extends State<LibraryUserScreen> {
  _UserSourceFilter _sourceFilter = _UserSourceFilter.all;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.catalog, widget.userState]),
        builder: (context, _) {
          final albumByTrackId = {
            for (final album in widget.catalog.albums)
              for (final track in album.tracks) track.id: album,
          };
          final favoriteIds = widget.userState.favoriteTrackIds;
          final tracks = _filterTracks(switch (widget.mode) {
            LibraryUserBrowseMode.favorites => widget.userState.favoriteTracks,
            LibraryUserBrowseMode.recent => widget.userState.recentTracks,
            LibraryUserBrowseMode.history => const <Track>[],
          });
          final history = _filterHistory(widget.userState.historyItems);
          final resultCount = widget.mode == LibraryUserBrowseMode.history
              ? history.length
              : tracks.length;

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 24, 32, 18),
                sliver: SliverToBoxAdapter(
                  child: _UserLibraryHeader(
                    mode: widget.mode,
                    resultCount: resultCount,
                    sourceFilter: _sourceFilter,
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
              else if (widget.mode == LibraryUserBrowseMode.history)
                _historySliver(history, albumByTrackId, favoriteIds)
              else
                _trackSliver(tracks, albumByTrackId, favoriteIds),
            ],
          );
        },
      ),
    );
  }

  List<Track> _filterTracks(List<Track> tracks) {
    return [
      for (final track in tracks)
        if (_matchesSource(track)) track,
    ];
  }

  List<LibraryHistoryItem> _filterHistory(List<LibraryHistoryItem> history) {
    return [
      for (final item in history)
        if (_matchesSource(item.track)) item,
    ];
  }

  bool _matchesSource(Track track) => switch (_sourceFilter) {
    _UserSourceFilter.all => true,
    _UserSourceFilter.local => track.source == SourceKind.local,
    _UserSourceFilter.webDav => track.source == SourceKind.webDav,
  };

  Widget _trackSliver(
    List<Track> tracks,
    Map<String, Album> albumByTrackId,
    Set<String> favoriteIds,
  ) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
      sliver: SliverPrototypeExtentList.builder(
        itemCount: tracks.length,
        prototypeItem: _UserTrackRow(
          track: tracks.first,
          album: albumByTrackId[tracks.first.id]!,
          favorite: favoriteIds.contains(tracks.first.id),
          onTap: () {},
          onToggleFavorite: () {},
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
            onOpenAlbum: () => widget.onOpenAlbum(album),
          );
        },
      ),
    );
  }

  Widget _historySliver(
    List<LibraryHistoryItem> history,
    Map<String, Album> albumByTrackId,
    Set<String> favoriteIds,
  ) {
    final recentQueue = _filterTracks(widget.userState.recentTracks);
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
      sliver: SliverPrototypeExtentList.builder(
        itemCount: history.length,
        prototypeItem: _UserTrackRow(
          track: history.first.track,
          album: albumByTrackId[history.first.track.id]!,
          favorite: favoriteIds.contains(history.first.track.id),
          historyTime: history.first.record.playedAt,
          onTap: () {},
          onToggleFavorite: () {},
          onOpenAlbum: () {},
        ),
        itemBuilder: (context, index) {
          final item = history[index];
          final track = item.track;
          final album = albumByTrackId[track.id]!;
          return _UserTrackRow(
            key: ValueKey('play-history-${item.record.id}'),
            track: track,
            album: album,
            favorite: favoriteIds.contains(track.id),
            historyTime: item.record.playedAt,
            onTap: () => widget.playback.playTrack(
              track,
              queue: recentQueue.isEmpty ? [track] : recentQueue,
            ),
            onToggleFavorite: () =>
                unawaited(widget.userState.toggleFavorite(track)),
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
      LibraryUserBrowseMode.history => const _UserLibraryMessage(
        icon: Icons.history_rounded,
        title: '播放历史是空的',
        message: '每次开始播放一首歌曲都会在这里留下记录。',
      ),
    };
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除播放历史？'),
        content: const Text('最近播放和完整播放历史都会被清除，收藏不会受到影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.userState.clearHistory();
  }
}

class _UserLibraryHeader extends StatelessWidget {
  const _UserLibraryHeader({
    required this.mode,
    required this.resultCount,
    required this.sourceFilter,
    required this.onModeChanged,
    required this.onSourceChanged,
    required this.onBack,
    required this.onClearHistory,
  });

  final LibraryUserBrowseMode mode;
  final int resultCount;
  final _UserSourceFilter sourceFilter;
  final ValueChanged<LibraryUserBrowseMode> onModeChanged;
  final ValueChanged<_UserSourceFilter> onSourceChanged;
  final VoidCallback onBack;
  final VoidCallback? onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: '返回资料库',
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$resultCount ${mode == LibraryUserBrowseMode.favorites ? '首收藏' : '条记录'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            if (onClearHistory != null)
              TextButton.icon(
                onPressed: onClearHistory,
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('清除历史'),
              ),
          ],
        ),
        const SizedBox(height: 18),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final candidate in LibraryUserBrowseMode.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    key: ValueKey('user-library-mode-${candidate.name}'),
                    avatar: Icon(candidate.icon, size: 17),
                    label: Text(candidate.label),
                    selected: candidate == mode,
                    onSelected: (_) => onModeChanged(candidate),
                    selectedColor: SoundColors.accent.withValues(alpha: 0.24),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final filter in _UserSourceFilter.values)
              FilterChip(
                label: Text(switch (filter) {
                  _UserSourceFilter.all => '全部来源',
                  _UserSourceFilter.local => '本地',
                  _UserSourceFilter.webDav => 'WebDAV',
                }),
                selected: sourceFilter == filter,
                onSelected: (_) => onSourceChanged(filter),
              ),
          ],
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
    required this.onOpenAlbum,
    this.historyTime,
    super.key,
  });

  final Track track;
  final Album album;
  final bool favorite;
  final DateTime? historyTime;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 5),
      shape: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
      ),
      onTap: onTap,
      leading: SizedBox.square(
        dimension: 48,
        child: AlbumArt(album: album, borderRadius: 6),
      ),
      title: Text(
        track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          track.artist,
          album.title,
          track.source.label,
          if (historyTime != null) _formatHistoryTime(historyTime!),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
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
            onPressed: onOpenAlbum,
            tooltip: '打开专辑 ${album.title}',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 150),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.white38),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatHistoryTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
