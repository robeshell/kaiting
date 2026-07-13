import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../controllers/library_catalog_controller.dart';
import '../widgets/album_art.dart';
import '../widgets/source_badge.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.catalog,
    required this.onOpenAlbum,
    required this.onManageSources,
    super.key,
  });

  final LibraryCatalogController catalog;
  final ValueChanged<Album> onOpenAlbum;
  final VoidCallback onManageSources;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: catalog,
      builder: (context, _) {
        final albums = catalog.albums;
        final albumByTrackId = {
          for (final album in albums)
            for (final track in album.tracks) track.id: album,
        };
        final tracks = catalog.tracks;
        return CustomScrollView(
          slivers: [
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(32, 34, 32, 20),
              sliver: SliverToBoxAdapter(child: _LibraryHeader()),
            ),
            if (catalog.status == LibraryCatalogStatus.loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.loading(),
              )
            else if (catalog.status == LibraryCatalogStatus.error)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.error(
                  message: catalog.errorMessage ?? '无法读取资料库。',
                  onAction: catalog.refresh,
                ),
              )
            else if (albums.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _CatalogMessage.empty(onAction: onManageSources),
              )
            else ...[
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(32, 20, 32, 0),
                sliver: SliverToBoxAdapter(child: _SectionHeader(title: '专辑')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
                sliver: SliverGrid.builder(
                  itemCount: albums.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 210,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 24,
                    mainAxisSpacing: 24,
                  ),
                  itemBuilder: (context, index) {
                    final album = albums[index];
                    return _AlbumCard(
                      album: album,
                      onTap: () => onOpenAlbum(album),
                    );
                  },
                ),
              ),
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(32, 26, 32, 12),
                sliver: SliverToBoxAdapter(child: _SectionHeader(title: '歌曲')),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
                sliver: SliverPrototypeExtentList.builder(
                  itemCount: tracks.length,
                  prototypeItem: _LibraryTrackRow(
                    track: tracks.first,
                    album: albumByTrackId[tracks.first.id]!,
                    onTap: () {},
                  ),
                  itemBuilder: (context, index) {
                    final track = tracks[index];
                    final album = albumByTrackId[track.id]!;
                    return _LibraryTrackRow(
                      track: track,
                      album: album,
                      onTap: () => onOpenAlbum(album),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LibraryTrackRow extends StatelessWidget {
  const _LibraryTrackRow({
    required this.track,
    required this.album,
    required this.onTap,
  });

  final Track track;
  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 5),
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
          '${track.artist} · ${track.albumTitle}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: Colors.white54),
        ),
        trailing: SourceBadge(track.source),
      ),
    );
  }
}

class _LibraryHeader extends StatelessWidget {
  const _LibraryHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '资料库',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: 5),
        Text('已索引的本地音乐', style: TextStyle(color: Colors.white54, fontSize: 13)),
      ],
    );
  }
}

class _CatalogMessage extends StatelessWidget {
  const _CatalogMessage._({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  const _CatalogMessage.loading()
    : this._(
        icon: Icons.library_music_outlined,
        title: '正在读取资料库',
        message: '正在加载已索引的专辑和歌曲。',
        loading: true,
      );

  const _CatalogMessage.empty({required VoidCallback onAction})
    : this._(
        icon: Icons.create_new_folder_outlined,
        title: '资料库还是空的',
        message: '添加一个本地音乐文件夹，扫描完成后歌曲会显示在这里。',
        actionLabel: '管理音乐来源',
        onAction: onAction,
      );

  const _CatalogMessage.error({
    required String message,
    required VoidCallback onAction,
  }) : this._(
         icon: Icons.error_outline_rounded,
         title: '无法读取资料库',
         message: message,
         actionLabel: '重试',
         onAction: onAction,
       );

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 40, 32, 150),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
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
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(actionLabel!),
                  style: FilledButton.styleFrom(
                    backgroundColor: SoundColors.accent,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  const _AlbumCard({required this.album, required this.onTap});

  final Album album;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AlbumArt(album: album),
          const SizedBox(height: 10),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Text(
                  album.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
              ),
              SourceBadge(album.source),
            ],
          ),
        ],
      ),
    );
  }
}
