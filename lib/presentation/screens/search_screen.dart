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
import '../widgets/artist_avatar.dart';
import '../widgets/sound_components.dart';
import '../widgets/sound_metadata_line.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    required this.catalog,
    required this.search,
    required this.playback,
    this.userState,
    required this.onOpenAlbum,
    this.onOpenArtist,
    this.focusNode,
    super.key,
  });

  final LibraryCatalogController catalog;
  final LibrarySearchController search;
  final SoundPlaybackController playback;
  final LibraryUserStateController? userState;
  final ValueChanged<Album> onOpenAlbum;
  final ValueChanged<LibraryCollection>? onOpenArtist;
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

  void _playSearchResults({int startIndex = 0}) {
    final hits = widget.search.hits;
    if (hits.isEmpty) return;
    final queue = [for (final hit in hits) hit.track];
    final index = startIndex.clamp(0, queue.length - 1);
    unawaited(widget.playback.playTrack(queue[index], queue: queue));
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
            key: const PageStorageKey<String>('library-search-results'),
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
                    icon: KaitingIcons.library,
                    title: '正在读取资料库',
                    message: '资料库就绪后即可搜索。',
                    loading: true,
                  ),
                )
              else if (widget.catalog.status == LibraryCatalogStatus.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: KaitingIcons.error,
                    title: '无法读取资料库',
                    message: widget.catalog.errorMessage ?? '请稍后重试。',
                  ),
                )
              else if (widget.search.query.trim().isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptySearchBody(
                    recentQueries: widget.search.recentQueries,
                    onSelectRecent: (query) {
                      _queryController.text = query;
                      _queryController.selection = TextSelection.collapsed(
                        offset: query.length,
                      );
                      widget.search.applyRecentQuery(query);
                    },
                  ),
                )
              else if (widget.search.status == LibrarySearchStatus.error)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: KaitingIcons.error,
                    title: '搜索失败',
                    message: widget.search.errorMessage ?? '请重新输入关键词。',
                  ),
                )
              else if (widget.search.hits.isEmpty &&
                  widget.search.artistHits.isEmpty &&
                  widget.search.albumHits.isEmpty &&
                  widget.search.status == LibrarySearchStatus.searching)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: KaitingIcons.search,
                    title: '正在搜索',
                    message: '正在从资料库中查找匹配内容。',
                    loading: true,
                  ),
                )
              else if (widget.search.hits.isEmpty &&
                  widget.search.artistHits.isEmpty &&
                  widget.search.albumHits.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _SearchMessage(
                    icon: KaitingIcons.searchEmpty,
                    title: '没有找到结果',
                    message: '没有与“${widget.search.query.trim()}”匹配的艺人、专辑或歌曲。',
                  ),
                )
              else ...[
                if (widget.search.artistHits.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      compact ? 4 : 8,
                      gutter,
                      4,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: _EntitySection(
                        title: '艺人',
                        child: _ArtistHitList(
                          hits: widget.search.artistHits,
                          onOpen: (hit) =>
                              widget.onOpenArtist?.call(hit.collection),
                        ),
                      ),
                    ),
                  ),
                if (widget.search.albumHits.isNotEmpty)
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 4),
                    sliver: SliverToBoxAdapter(
                      child: _EntitySection(
                        title: '专辑',
                        child: _AlbumHitList(
                          hits: widget.search.albumHits,
                          onOpen: (hit) => widget.onOpenAlbum(hit.album),
                        ),
                      ),
                    ),
                  ),
                if (widget.search.hits.isNotEmpty) ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      compact ? 8 : 12,
                      gutter,
                      compact ? 5 : 8,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: Row(
                        children: [
                          Text(
                            widget.search.truncated
                                ? '歌曲（前 ${widget.search.hits.length} 首）'
                                : '${widget.search.hits.length} 首歌曲',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
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
                            )
                          else
                            TextButton.icon(
                              key: const ValueKey('search-play-results'),
                              onPressed: () => _playSearchResults(),
                              icon: const Icon(KaitingIcons.playNext, size: 18),
                              label: Text(
                                compact ? '播放结果' : '用结果播放',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                foregroundColor: SoundColors.accent,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.search.truncated)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          '仅显示前 ${LibrarySearchController.resultLimit} 首，'
                          '请缩小关键词再试。',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: context.soundMutedText),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      context.soundListGutter,
                      0,
                      context.soundListGutter,
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
                        onPlayResultsQueue: () =>
                            _playSearchResults(startIndex: index),
                        onOpenAlbum: () =>
                            widget.onOpenAlbum(widget.search.hits[index].album),
                        onOpenArtist: widget.onOpenArtist == null
                            ? null
                            : () {
                                final hit = widget.search.hits[index];
                                final collection = findArtistCollection(
                                  widget.catalog.albums,
                                  hit.track.artist,
                                  collections: widget.catalog.artistCollections,
                                );
                                if (collection != null) {
                                  widget.onOpenArtist!(collection);
                                }
                              },
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
                ] else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      gutter,
                      0,
                      gutter,
                      context.soundContentBottomPadding,
                    ),
                    sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
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
              style: context.soundListTitleStyle.copyWith(
                fontWeight: FontWeight.w400,
              ),
              textInputAction: TextInputAction.search,
              onChanged: widget.search.setQuery,
              decoration: InputDecoration(
                hintText: compact ? '搜索歌名、艺人、专辑' : '搜索歌名、艺人、专辑、流派',
                prefixIcon: const Icon(KaitingIcons.search, size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 42),
                suffixIcon: widget.search.query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _clearQuery,
                        tooltip: '清除搜索',
                        icon: const Icon(KaitingIcons.close, size: 18),
                      ),
                suffixIconConstraints: const BoxConstraints(minWidth: 42),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 11),
                filled: true,
                fillColor: context.soundTint(0.025),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.control),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.control),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(SoundRadii.control),
                  borderSide: BorderSide(color: SoundColors.accent, width: 2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptySearchBody extends StatelessWidget {
  const _EmptySearchBody({
    required this.recentQueries,
    required this.onSelectRecent,
  });

  final List<String> recentQueries;
  final ValueChanged<String> onSelectRecent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _SearchMessage(
            icon: KaitingIcons.search,
            title: '搜索你的音乐',
            message: '',
          ),
          if (recentQueries.isNotEmpty) ...[
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '最近搜索',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.soundSecondaryText,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SoundChoiceStrip<String?>(
              wrap: true,
              selected: null,
              onSelected: (query) => onSelectRecent(query!),
              options: [
                for (final query in recentQueries)
                  SoundChoiceOption(
                    key: ValueKey('search-recent-$query'),
                    value: query,
                    label: query,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EntitySection extends StatelessWidget {
  const _EntitySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: context.soundSecondaryText,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ArtistHitList extends StatelessWidget {
  const _ArtistHitList({required this.hits, required this.onOpen});

  final List<LibrarySearchArtistHit> hits;
  final ValueChanged<LibrarySearchArtistHit> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final hit in hits)
          SoundListRow(
            key: ValueKey('search-artist-${hit.collection.id}'),
            padding: EdgeInsets.zero,
            leading: ArtistAvatar(
              collection: hit.collection,
              size: 40,
              showShadow: false,
            ),
            title: Text(hit.name),
            subtitle: Text(_artistHitSubtitle(hit.collection)),
            trailing: Icon(
              KaitingIcons.chevronRight,
              size: 19,
              color: context.soundSecondaryText,
            ),
            onTap: () => onOpen(hit),
          ),
      ],
    );
  }
}

String _artistHitSubtitle(LibraryCollection collection) {
  final featured = collection.featuredTracks.length;
  if (featured > 0 && collection.primaryTracks.isEmpty) {
    return '$featured 首参与';
  }
  if (featured > 0) {
    return '${collection.ownedAlbums.length} 张专辑 · '
        '${collection.primaryTracks.length} 首 · $featured 参与';
  }
  return '${collection.albums.length} 张专辑 · ${collection.tracks.length} 首';
}

class _AlbumHitList extends StatelessWidget {
  const _AlbumHitList({required this.hits, required this.onOpen});

  final List<LibrarySearchAlbumHit> hits;
  final ValueChanged<LibrarySearchAlbumHit> onOpen;

  @override
  Widget build(BuildContext context) {
    final compact = context.soundIsCompact;
    return SizedBox(
      height: compact ? 158 : 168,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: hits.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final hit = hits[index];
          return _AlbumHitCard(
            key: ValueKey('search-album-${hit.album.id}'),
            hit: hit,
            onOpen: () => onOpen(hit),
          );
        },
      ),
    );
  }
}

class _AlbumHitCard extends StatelessWidget {
  const _AlbumHitCard({required this.hit, required this.onOpen, super.key});

  final LibrarySearchAlbumHit hit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(SoundRadii.card),
      child: SizedBox(
        width: 112,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AlbumArt(album: hit.album, size: 108),
            const SizedBox(height: 6),
            Text(
              hit.album.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              hit.album.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                height: 1.15,
                color: context.soundMutedText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultRow extends StatelessWidget {
  const _SearchResultRow({
    required this.hit,
    required this.compact,
    required this.favorite,
    required this.onPlay,
    required this.onPlayResultsQueue,
    required this.onOpenAlbum,
    required this.onOpenArtist,
    required this.onToggleFavorite,
    required this.onAddToPlaylist,
  });

  final LibrarySearchHit hit;
  final bool compact;
  final bool favorite;
  final VoidCallback onPlay;
  final VoidCallback onPlayResultsQueue;
  final VoidCallback onOpenAlbum;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddToPlaylist;

  @override
  Widget build(BuildContext context) {
    return SoundTrackListRow(
      key: ValueKey('search-result-${hit.track.id}'),
      leading: AlbumArt(album: hit.album, borderRadius: compact ? 8 : 6),
      title: hit.track.title,
      subtitleWidget: SoundMetadataLine(
        artist: hit.track.artist,
        album: hit.album.title,
        onOpenArtist: onOpenArtist,
        onOpenAlbum: onOpenAlbum,
      ),
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
                favorite ? KaitingIcons.favoriteFilled : KaitingIcons.favorite,
              ),
            ),
          if (onAddToPlaylist != null)
            IconButton(
              key: ValueKey('add-search-${hit.track.id}-to-playlist'),
              onPressed: onAddToPlaylist,
              tooltip: '将 ${hit.track.title} 添加到播放列表',
              icon: const Icon(KaitingIcons.playlistAdd),
            ),
          IconButton(
            onPressed: onOpenAlbum,
            tooltip: '打开专辑 ${hit.album.title}',
            icon: const Icon(KaitingIcons.chevronRight),
          ),
        ],
      ),
      compactTrailing: SoundMenuButton<_SearchResultAction>(
        key: ValueKey('search-result-menu-${hit.track.id}'),
        tooltip: '更多操作 ${hit.track.title}',
        menuTitle: hit.track.title,
        icon: const Icon(KaitingIcons.moreHorizontal, size: 21),
        onSelected: (action) {
          switch (action) {
            case _SearchResultAction.openAlbum:
              onOpenAlbum();
            case _SearchResultAction.openArtist:
              onOpenArtist?.call();
            case _SearchResultAction.playResults:
              onPlayResultsQueue();
            case _SearchResultAction.favorite:
              onToggleFavorite?.call();
            case _SearchResultAction.addToPlaylist:
              onAddToPlaylist?.call();
          }
        },
        actions: [
          const SoundMenuAction(
            value: _SearchResultAction.openAlbum,
            label: '打开专辑',
            icon: KaitingIcons.album,
          ),
          if (onOpenArtist != null)
            const SoundMenuAction(
              value: _SearchResultAction.openArtist,
              label: '打开艺人',
              icon: KaitingIcons.person,
            ),
          const SoundMenuAction(
            value: _SearchResultAction.playResults,
            label: '从这里播放搜索结果',
            icon: KaitingIcons.playNext,
          ),
          if (onToggleFavorite != null)
            SoundMenuAction(
              value: _SearchResultAction.favorite,
              label: favorite ? '取消收藏' : '收藏',
              icon: favorite
                  ? KaitingIcons.favoriteFilled
                  : KaitingIcons.favorite,
              selected: favorite,
            ),
          if (onAddToPlaylist != null)
            const SoundMenuAction(
              value: _SearchResultAction.addToPlaylist,
              label: '添加到播放列表',
              icon: KaitingIcons.playlistAdd,
            ),
        ],
      ),
    );
  }
}

enum _SearchResultAction {
  openAlbum,
  openArtist,
  playResults,
  favorite,
  addToPlaylist,
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
