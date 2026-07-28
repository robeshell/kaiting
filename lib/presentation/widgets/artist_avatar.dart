import 'package:flutter/material.dart';

import '../../core/sound_theme.dart';
import '../../domain/library_models.dart';
import '../../library/scanning/image_bytes.dart';
import 'album_art.dart';
import 'artwork_image_provider.dart';

/// Circular artist visual: representative cover when available, else monogram.
///
/// Local libraries rarely have true artist photos. This keeps the list/detail
/// scannable without network enrich — square album art stays for albums.
class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    required this.collection,
    this.size,
    this.showShadow = true,
    this.cacheExtent,
    this.gaplessPlayback = false,
    super.key,
  });

  final LibraryCollection collection;
  final double? size;
  final bool showShadow;
  final int? cacheExtent;
  final bool gaplessPlayback;

  @override
  Widget build(BuildContext context) {
    final art = LayoutBuilder(
      builder: (context, constraints) {
        final logicalExtent = constraints.biggest.shortestSide;
        final hasFiniteExtent = logicalExtent.isFinite && logicalExtent > 0;
        final resolvedCacheExtent =
            cacheExtent ??
            (hasFiniteExtent
                ? quantizedArtworkCacheExtent(
                    logicalExtent,
                    MediaQuery.devicePixelRatioOf(context),
                  )
                : null);

        final album = collection.representativeAlbum;
        final artworkUri = album?.artworkUri?.trim();
        final useCover =
            album != null &&
            artworkUri != null &&
            artworkUri.isNotEmpty &&
            artworkFileLooksValid(artworkUri);
        final imageProvider = useCover
            ? artworkImageProvider(
                artworkUri,
                cacheWidth: resolvedCacheExtent,
                cacheHeight: resolvedCacheExtent,
              )
            : null;

        final shadows =
            !showShadow ||
                !hasFiniteExtent ||
                logicalExtent < 96 ||
                context.soundSkinEffects.shadowScale <= 0
            ? const <BoxShadow>[]
            : [
                BoxShadow(
                  color: context.soundGlass.shadow,
                  blurRadius: 10 * context.soundSkinEffects.shadowScale,
                  offset: Offset(0, 3 * context.soundSkinEffects.shadowScale),
                ),
              ];

        return DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: shadows),
          child: ClipOval(
            child: imageProvider == null
                ? _MonogramFace(
                    monogram: collection.monogram,
                    colors: collection.monogramPalette,
                    extent: hasFiniteExtent ? logicalExtent : 48,
                  )
                : Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: gaplessPlayback,
                    errorBuilder: (_, _, _) => _MonogramFace(
                      monogram: collection.monogram,
                      colors: collection.monogramPalette,
                      extent: hasFiniteExtent ? logicalExtent : 48,
                    ),
                  ),
          ),
        );
      },
    );

    if (size == null) return AspectRatio(aspectRatio: 1, child: art);
    return SizedBox.square(dimension: size, child: art);
  }
}

class _MonogramFace extends StatelessWidget {
  const _MonogramFace({
    required this.monogram,
    required this.colors,
    required this.extent,
  });

  final String monogram;
  final List<Color> colors;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final fontSize = (extent * 0.38).clamp(14.0, 96.0);
    final start = colors.isNotEmpty ? colors.first : const Color(0xFF385057);
    final end = colors.length > 1 ? colors.last : start;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
      child: Center(
        child: Text(
          monogram,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.94),
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            height: 1,
            letterSpacing: -0.4,
          ),
        ),
      ),
    );
  }
}
