import 'package:flutter/material.dart';

import '../../domain/library_models.dart';
import 'artwork_image_provider.dart';

class AlbumArt extends StatelessWidget {
  const AlbumArt({
    required this.album,
    this.size,
    this.borderRadius = 10,
    super.key,
  });

  final Album album;
  final double? size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final art = LayoutBuilder(
      builder: (context, constraints) {
        final logicalExtent = constraints.biggest.shortestSide;
        final hasFiniteExtent = logicalExtent.isFinite && logicalExtent > 0;
        final cacheExtent = hasFiniteExtent
            ? _quantizedPhysicalExtent(
                logicalExtent,
                MediaQuery.devicePixelRatioOf(context),
              )
            : null;
        final imageProvider = artworkImageProvider(
          album.artworkUri,
          cacheWidth: cacheExtent,
          cacheHeight: cacheExtent,
        );
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: album.palette,
            ),
            boxShadow: hasFiniteExtent && logicalExtent < 96
                ? const []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: imageProvider == null
                ? _ArtworkPlaceholder(album: album)
                : Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, _, _) =>
                        _ArtworkPlaceholder(album: album),
                  ),
          ),
        );
      },
    );

    if (size == null) return AspectRatio(aspectRatio: 1, child: art);
    return SizedBox.square(dimension: size, child: art);
  }
}

const _decodeBucket = 64;

int _quantizedPhysicalExtent(double logicalExtent, double devicePixelRatio) {
  final physicalExtent = (logicalExtent * devicePixelRatio).ceil();
  return ((physicalExtent + _decodeBucket - 1) ~/ _decodeBucket) *
      _decodeBucket;
}

class _ArtworkPlaceholder extends StatelessWidget {
  const _ArtworkPlaceholder({required this.album});

  final Album album;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          right: -24,
          top: -24,
          child: _Disc(color: Colors.white.withValues(alpha: 0.08)),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                album.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                album.artist.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      alignment: Alignment.center,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white.withValues(alpha: 0.52),
          size: 18,
        ),
      ),
    );
  }
}
