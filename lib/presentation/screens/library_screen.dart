import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../widgets/album_art.dart';
import '../widgets/source_badge.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({required this.onOpenAlbum, super.key});

  final ValueChanged<Album> onOpenAlbum;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 34, 32, 20),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
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
                      Text(
                        '你的本地音乐与 NAS 收藏',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _CircleButton(icon: Icons.search_rounded, onTap: () {}),
                const SizedBox(width: 10),
                _CircleButton(icon: Icons.tune_rounded, onTap: () {}),
              ],
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          sliver: SliverToBoxAdapter(child: _LibraryTabs()),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
          sliver: SliverToBoxAdapter(
            child: _SectionHeader(title: '最近添加', onAction: () {}),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          sliver: SliverGrid.builder(
            itemCount: demoAlbums.length,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisExtent: 280,
              crossAxisSpacing: 24,
              mainAxisSpacing: 24,
            ),
            itemBuilder: (context, index) {
              final album = demoAlbums[index];
              return _AlbumCard(album: album, onTap: () => onOpenAlbum(album));
            },
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(32, 26, 32, 12),
          sliver: SliverToBoxAdapter(child: _SectionHeader(title: '继续聆听')),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(32, 0, 32, 140),
          sliver: SliverList.separated(
            itemCount: demoAlbums.take(3).length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
            itemBuilder: (context, index) {
              final album = demoAlbums[index];
              final track = album.tracks.first;
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 5),
                onTap: () => onOpenAlbum(album),
                leading: SizedBox.square(
                  dimension: 48,
                  child: AlbumArt(album: album, borderRadius: 6),
                ),
                title: Text(
                  track.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  '${album.artist} · ${album.title}',
                  style: const TextStyle(fontSize: 12, color: Colors.white54),
                ),
                trailing: SourceBadge(album.source),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LibraryTabs extends StatelessWidget {
  const _LibraryTabs();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: const Row(
        children: [
          _TabLabel('最近', active: true),
          _TabLabel('专辑'),
          _TabLabel('歌曲'),
          _TabLabel('艺人'),
          _TabLabel('流派'),
        ],
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel(this.label, {this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 26),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              label,
              style: TextStyle(
                color: active ? SoundColors.accent : Colors.white54,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Container(
            width: 28,
            height: 2,
            color: active ? SoundColors.accent : Colors.transparent,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.onAction});

  final String title;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (onAction != null)
          TextButton(onPressed: onAction, child: const Text('查看全部')),
      ],
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

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}
