class AlbumArtistResolver {
  final Map<String, _ArtistCandidate> _candidates = {};
  final Map<String, _ArtistCandidate> _explicitCandidates = {};
  bool _isCompilation = false;

  void add(String artist) {
    _addCandidate(_candidates, artist);
  }

  void addAlbumArtist(String? artist) {
    if (artist == null) return;
    _addCandidate(_explicitCandidates, artist);
  }

  void markCompilation() {
    _isCompilation = true;
  }

  void _addCandidate(Map<String, _ArtistCandidate> candidates, String artist) {
    final display = artist.trim();
    if (display.isEmpty) return;
    final key = display.toLowerCase();
    final existing = candidates[key];
    candidates[key] = _ArtistCandidate(
      display: existing?.display ?? display,
      count: (existing?.count ?? 0) + 1,
    );
  }

  String resolve({String fallback = '未知艺人'}) {
    if (_explicitCandidates.isNotEmpty) {
      return _resolveCandidates(_explicitCandidates, fallback: fallback);
    }
    if (_isCompilation) return '群星';
    return _resolveCandidates(_candidates, fallback: fallback);
  }

  String _resolveCandidates(
    Map<String, _ArtistCandidate> candidates, {
    required String fallback,
  }) {
    if (candidates.isEmpty) return fallback;
    if (candidates.length == 1) return candidates.values.single.display;

    final ranked = candidates.values.toList(growable: false)
      ..sort((left, right) => right.count.compareTo(left.count));
    if (ranked[0].count > ranked[1].count) return ranked[0].display;

    Set<String>? commonParts;
    final displayByPart = <String, String>{};
    for (final candidate in candidates.values) {
      final parts = _artistParts(candidate.display);
      for (final part in parts) {
        displayByPart.putIfAbsent(part.toLowerCase(), () => part);
      }
      final normalized = parts.map((part) => part.toLowerCase()).toSet();
      commonParts = commonParts == null
          ? normalized
          : commonParts.intersection(normalized);
    }
    if (commonParts != null && commonParts.length == 1) {
      return displayByPart[commonParts.single] ?? fallback;
    }
    return '群星';
  }
}

List<String> _artistParts(String value) {
  return value
      .split(
        RegExp(
          r'\s*(?:&|/|、|,|，|;|；|\bfeat\.?\b|\bfeaturing\b|\bft\.?\b)\s*',
          caseSensitive: false,
        ),
      )
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
}

class _ArtistCandidate {
  const _ArtistCandidate({required this.display, required this.count});

  final String display;
  final int count;
}
