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
import '../widgets/source_badge.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.catalog,
    required this.search,
    required this.playback,
    this.userState,
    required this.onOpenAlbum,
    super.key,
  });

  final LibraryCatalogController catalog;
  final LibrarySearchController search;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final ValueChanged<Album> onOpenAlbum;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.search.query);
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.search != widget.search &&
        _queryController.text != widget.search.query) {
      _queryController.text = widget.search.query;
    }
  }

  @override
  void dispose() {
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
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 34, 32, 12),
                sliver: SliverToBoxAdapter(child: _buildHeader()),
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
                  padding: const EdgeInsets.fromLTRB(32, 10, 32, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        Text(
                          '${widget.search.hits.length} 首歌曲',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
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
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 140),
                  sliver: SliverList.builder(
                    itemCount: widget.search.hits.length,
                    itemBuilder: (context, index) => _SearchResultRow(
                      hit: widget.search.hits[index],
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '搜索',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 22),
        TextField(
          key: const ValueKey('library-search-field'),
          controller: _queryController,
          autofocus: false,
          textInputAction: TextInputAction.search,
          onChanged: widget.search.setQuery,
          decoration: InputDecoration(
            hintText: '歌曲、专辑、艺人或流派',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: widget.search.query.isEmpty
                ? null
                : IconButton(
                    onPressed: _clearQuery,
                    tooltip: '清除搜索',
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final field in LibrarySearchField.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(field.label),
                          selected: widget.search.field == field,
                          onSelected: (_) => widget.search.setField(field),
                          selectedColor: SoundColors.accent.withValues(
                            alpha: 0.24,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            PopupMenuButton<LibrarySearchSort>(
              tooltip: '排序方式',
              initialValue: widget.search.sort,
              onSelected: widget.search.setSort,
              itemBuilder: (context) => [
                for (final sort in LibrarySearchSort.values)
                  PopupMenuItem(value: sort, child: Text(sort.label)),
              ],
              child: Chip(
                avatar: const Icon(Icons.sort_rounded, size: 17),
                label: Text(widget.search.sort.label),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.hit,
    required this.favorite,
    required this.onPlay,
    required this.onOpenAlbum,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
  });

  final LibrarySearchHit hit;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback onOpenAlbum;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    final genre = hit.track.genre ?? hit.album.genre;
    return ListTile(
      key: ValueKey('search-result-${hit.track.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onTap: onPlay,
      leading: SizedBox.square(
        dimension: 50,
        child: AlbumArt(album: hit.album, borderRadius: 7),
      ),
      title: Text(
        hit.track.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        [
          hit.track.artist,
          hit.album.title,
          if (hit.album.artist != hit.track.artist) hit.album.artist,
          if (genre?.trim().isNotEmpty == true) genre!,
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.white54),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SourceBadge(hit.track.source),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 30, 32, 150),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const CircularProgressIndicator()
            else
              Icon(icon, size: 48, color: Colors.white38),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
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
    );
  }
}
