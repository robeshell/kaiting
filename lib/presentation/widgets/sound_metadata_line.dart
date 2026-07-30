import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';

/// Tappable artist / album metadata used across list rows, mini player and
/// now-playing.
///
/// Visually identical to plain secondary metadata text — no link color,
/// underline, or weight change. Navigation is wired with box hit targets
/// (not [TextSpan] recognizers) so mobile single-tap rows do not swallow
/// the gesture for the whole track.
class SoundMetadataLine extends StatelessWidget {
  const SoundMetadataLine({
    required this.artist,
    required this.album,
    this.onOpenArtist,
    this.onOpenAlbum,
    this.separator = ' · ',
    this.style,
    this.maxLines = 1,
    this.textAlign = TextAlign.start,
    super.key,
  });

  final String artist;
  final String album;
  final VoidCallback? onOpenArtist;
  final VoidCallback? onOpenAlbum;
  final String separator;
  final TextStyle? style;
  final int maxLines;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final textStyle =
        style ??
        TextStyle(
          color: context.soundMutedText.withValues(
            alpha: context.soundMutedText.a * 0.82,
          ),
          fontSize: 11,
        );
    final artistLabel =
        artist.trim().isEmpty ? '未知艺人' : artist.trim();
    final albumLabel = album.trim().isEmpty ? '未知专辑' : album.trim();

    return Row(
      children: [
        Flexible(
          child: _MetadataSegment(
            label: artistLabel,
            style: textStyle,
            maxLines: maxLines,
            textAlign: textAlign,
            onTap: onOpenArtist,
            semanticLabel: onOpenArtist == null ? null : '打开艺人 $artistLabel',
          ),
        ),
        Text(separator, style: textStyle),
        Flexible(
          child: _MetadataSegment(
            label: albumLabel,
            style: textStyle,
            maxLines: maxLines,
            textAlign: textAlign,
            onTap: onOpenAlbum,
            semanticLabel: onOpenAlbum == null ? null : '打开专辑 $albumLabel',
          ),
        ),
      ],
    );
  }
}

class _MetadataSegment extends StatelessWidget {
  const _MetadataSegment({
    required this.label,
    required this.style,
    required this.maxLines,
    required this.textAlign,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final TextStyle style;
  final int maxLines;
  final TextAlign textAlign;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: style,
    );
    if (onTap == null) return text;

    // Opaque box hit target so parent row InkWell (mobile single-tap play)
    // loses the gesture arena when the finger is on this label.
    return Semantics(
      button: true,
      label: semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: text,
        ),
      ),
    );
  }
}
