import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';

/// Track list on the back of a flipped cover. Larger than the cover itself.
class IpodAlbumTrackList extends StatelessWidget {
  const IpodAlbumTrackList({
    required this.album,
    required this.onPlayTrack,
    required this.onClose,
    this.playingTrackId,
    super.key,
  });

  final Album album;
  final ValueChanged<Track> onPlayTrack;
  final VoidCallback onClose;
  final String? playingTrackId;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: ValueKey('ipod-flip-back-${album.id}'),
      color: const Color(0xFF161616),
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                IconButton(
                  key: const ValueKey('ipod-flip-back'),
                  tooltip: '返回',
                  onPressed: onClose,
                  color: const Color(0xFFE8E8E8),
                  visualDensity: VisualDensity.compact,
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(KaitingIcons.back, size: 18),
                ),
                Expanded(
                  child: Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFF4F4F4),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0x22FFFFFF)),
          Expanded(
            child: album.tracks.isEmpty
                ? const Center(
                    child: Text(
                      '没有可播放的歌曲',
                      style: TextStyle(color: Color(0xFF9A9A9A)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: album.tracks.length,
                    itemBuilder: (context, index) {
                      final track = album.tracks[index];
                      final active = track.id == playingTrackId;
                      final number = track.trackNumber > 0
                          ? track.trackNumber
                          : index + 1;
                      return InkWell(
                        key: ValueKey('ipod-track-${track.id}'),
                        onTap: () => onPlayTrack(track),
                        child: ColoredBox(
                          color: active
                              ? const Color(0x22FFFFFF)
                              : Colors.transparent,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  child: Text(
                                    '$number',
                                    style: TextStyle(
                                      color: active
                                          ? const Color(0xFFF4F4F4)
                                          : const Color(0xFF8A8A8A),
                                      fontSize: 13,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: const Color(0xFFF4F4F4),
                                      fontSize: 15,
                                      fontWeight: active
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatIpodDuration(track.duration),
                                  style: const TextStyle(
                                    color: Color(0xFF8A8A8A),
                                    fontSize: 12,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

String formatIpodDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).abs();
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
