import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../playback/playback_controller.dart';
import '../controllers/library_catalog_controller.dart';
import '../controllers/library_search_controller.dart';
import '../controllers/library_user_state_controller.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/album_art.dart';
import '../widgets/sound_components.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.catalog,
    required this.search,
    required this.playback,
    this.userState,
    required this.onOpenAlbum,
    this.focusNode,
    super.key,
  });

  final LibraryCatalogController catalog;
  final LibrarySearchController search;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final ValueChanged<Album> onOpenAlbum;
  final FocusNode? focusNode;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.search.query);
    widget.search.addListener(_syncQueryFromSearch);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search) {
      oldWidget.search.removeListener(_syncQueryFromSearch);
      widget.search.addListener(_syncQueryFromSearch);
      _syncQueryFromSearch();
    }
  }

  void _syncQueryFromSearch() {
    if (_queryController.text == widget.search.query) return;
    _queryController.value = TextEditingValue(
      text: widget.search.query,
      selection: TextSelection.collapsed(offset: widget.search.query.length),
    );
  }

  @override
  void dispose() {
    widget.search.removeListener(_syncQueryFromSearch);
    _queryController.dispose();
    super.dispose();
  }

  void _clearQuery() {
    _queryController.clear();
    widget.search.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          widget.catalog,
          widget.search,
          ?widget.userState,
        ]),
        builder: (context, _) {
          final compact = context.soundIsCompact;
          final gutter = context.soundPageGutter;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  gutter,
                  compact ? 12 : 20,
                  gutter,
                  compact ? 8 : 12,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildHeader(context, compact: compact),
                ),
              ),
              if (widget.catalog.status == LibraryCatalogStatus.loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.library_music_outlined,
                    title: '正在读取资料库',
                    message: '资料库就绪后即可搜索。',
                    loading: true,
                  ),
                )
              else if (widget.catalog.status == LibraryCatalogStatus.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.error_outline_rounded,
                    title: '无法读取资料库',
                    message: widget.catalog.errorMessage ?? '请稍后重试。',
                  ),
                )
              else if (widget.search.query.trim().isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.search_rounded,
                    title: '搜索你的音乐',
                    message: '可搜索歌曲、专辑、歌曲艺人、专辑艺人和流派。',
                  ),
                )
              else if (widget.search.status == LibrarySearchStatus.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.error_outline_rounded,
                    title: '搜索失败',
                    message: widget.search.errorMessage ?? '请重新输入关键词。',
                  ),
                )
              else if (widget.search.hits.isEmpty &&
                  widget.search.status == LibrarySearchStatus.searching)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.search_rounded,
                    title: '正在搜索',
                    message: '正在从资料库中查找匹配歌曲。',
                    loading: true,
                  ),
                )
              else if (widget.search.hits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: Icons.search_off_rounded,
                    title: '没有找到结果',
                    message: '没有与“${widget.search.query.trim()}”匹配的歌曲。',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    compact ? 4 : 10,
                    gutter,
                    compact ? 5 : 8,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          '${widget.search.hits.length} 首歌曲',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: context.soundMutedText.withValues(
                              alpha: context.soundMutedText.a * 0.76,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (widget.search.status ==
                            LibrarySearchStatus.searching)
                          const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    0,
                    gutter,
                    context.soundContentBottomPadding,
                  ),
                  sliver: SliverList.builder(
                    itemCount: widget.search.hits.length,
                    itemBuilder: (context, index) => _SearchResultRow(
                      hit: widget.search.hits[index],
                      compact: compact,
                      favorite:
                          widget.userState?.isFavorite(
                            widget.search.hits[index].track.id,
                          ) ??
                          false,
                      onPlay: () {
                        final hit = widget.search.hits[index];
                        widget.playback.playTrack(
                          hit.track,
                          queue: hit.album.tracks,
                        );
                      },
                      onOpenAlbum: () =>
                          widget.onOpenAlbum(widget.search.hits[index].album),
                      onToggleFavorite: widget.userState == null
                          ? null
                          : () => unawaited(
                              widget.userState!.toggleFavorite(
                                widget.search.hits[index].track,
                              ),
                            ),
                      onAddToPlaylist: widget.userState == null
                          ? null
                          : () => showAddToPlaylistSheet(
                              context,
                              userState: widget.userState!,
                              track: widget.search.hits[index].track,
                            ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, {required bool compact}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: compact ? double.infinity : 760,
          ),
          child: SizedBox(
            height: 44,
            child: TextField(
              key: const ValueKey('library-search-field'),
              controller: _queryController,
              focusNode: widget.focusNode,
              autofocus: false,
              cursorColor: SoundColors.accent,
              style: const TextStyle(fontSize: 14),
              textInputAction: TextInputAction.search,
              onChanged: widget.search.setQuery,
              decoration: InputDecoration(
                hintText: compact ? '搜索歌曲、专辑或艺人' : '歌曲、专辑、艺人或流派',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 42),
                suffixIcon: widget.search.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearQuery,
                        tooltip: '清除搜索',
                        icon: const Icon(Icons.close_rounded, size: 18),
                      ),
                suffixIconConstraints: const BoxConstraints(minWidth: 42),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                filled: true,
                fillColor: context.soundTint(0.025),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.pill),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.pill),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.pill),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _SearchControls(
          field: widget.search.field,
          sort: widget.search.sort,
          onFieldChanged: widget.search.setField,
          onSortChanged: widget.search.setSort,
        ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.hit,
    required this.compact,
    required this.favorite,
    required this.onPlay,
    required this.onOpenAlbum,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
  });

  final LibrarySearchHit hit;
  final bool compact;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback onOpenAlbum;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    return SoundTrackListRow(
      key: ValueKey('search-result-${hit.track.id}'),
      leading: AlbumArt(album: hit.album, borderRadius: compact ? 8 : 6),
      title: hit.track.title,
      subtitle: '${hit.track.artist} · ${hit.album.title}',
      onActivate: onPlay,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggleFavorite != null)
            IconButton(
              key: ValueKey('favorite-search-${hit.track.id}'),
              onPressed: onToggleFavorite,
              tooltip: favorite
                  ? '取消收藏 ${hit.track.title}'
                  : '收藏 ${hit.track.title}',
              color: favorite ? SoundColors.accent : null,
              icon: Icon(
                favorite
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
              ),
            ),
          if (onAddToPlaylist != null)
            IconButton(
              key: ValueKey('add-search-${hit.track.id}-to-playlist'),
              onPressed: onAddToPlaylist,
              tooltip: '将 ${hit.track.title} 添加到播放列表',
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          IconButton(
            onPressed: onOpenAlbum,
            tooltip: '打开专辑 ${hit.album.title}',
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
      compactTrailing: PopupMenuButton<_SearchResultAction>(
        key: ValueKey('search-result-menu-${hit.track.id}'),
        tooltip: '更多操作 ${hit.track.title}',
        icon: const Icon(Icons.more_horiz_rounded, size: 21),
        onSelected: (action) {
          switch (action) {
            case _SearchResultAction.openAlbum:
              onOpenAlbum();
            case _SearchResultAction.favorite:
              onToggleFavorite?.call();
            case _SearchResultAction.addToPlaylist:
              onAddToPlaylist?.call();
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: _SearchResultAction.openAlbum,
            child: Text('打开专辑'),
          ),
          if (onToggleFavorite != null)
            PopupMenuItem(
              value: _SearchResultAction.favorite,
              child: Text(favorite ? '取消收藏' : '收藏'),
            ),
          if (onAddToPlaylist != null)
            const PopupMenuItem(
              value: _SearchResultAction.addToPlaylist,
              child: Text('添加到播放列表'),
            ),
        ],
      ),
    );
  }
}

enum _SearchResultAction { openAlbum, favorite, addToPlaylist }

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.field,
    required this.sort,
    required this.onFieldChanged,
    required this.onSortChanged,
  });

  final LibrarySearchField field;
  final LibrarySearchSort sort;
  final ValueChanged<LibrarySearchField> onFieldChanged;
  final ValueChanged<LibrarySearchSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final fields = context.soundIsCompact
        ? const [
            LibrarySearchField.all,
            LibrarySearchField.title,
            LibrarySearchField.album,
            LibrarySearchField.trackArtist,
          ]
        : LibrarySearchField.values;
    return Row(
      children: [
        Expanded(
          child: SoundChoiceStrip<LibrarySearchField>(
            options: [
              for (final option in fields)
                SoundChoiceOption(
                  key: ValueKey('search-field-${option.name}'),
                  value: option,
                  label:
                      context.soundIsCompact &&
                          option == LibrarySearchField.trackArtist
                      ? '艺人'
                      : option.label,
                ),
            ],
            selected: field,
            onSelected: onFieldChanged,
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<LibrarySearchSort>(
          key: const ValueKey('compact-search-sort'),
          tooltip: '排序方式',
          initialValue: sort,
          onSelected: onSortChanged,
          itemBuilder: (context) => [
            for (final item in LibrarySearchSort.values)
              PopupMenuItem(value: item, child: Text(item.label)),
          ],
          child: SoundToolbarButton(
            icon: Icons.sort_rounded,
            label: context.soundIsCompact ? null : sort.label,
            tooltip: '排序：${sort.label}',
          ),
        ),
      ],
    );
  }
}

class _SearchMessage extends StatelessWidget {
  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SoundEmptyState(
      icon: icon,
      title: title,
      message: message,
      loading: loading,
    );
  }
}
