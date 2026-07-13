class AlbumArtistResolver {
  final Map<String, _ArtistCandidate> _candidates = {};

  void add(String artist) {
    final display = artist.trim();
    if (display.isEmpty) return;
    final key = display.toLowerCase();
    final existing = _candidates[key];
    _candidates[key] = _ArtistCandidate(
      display: existing?.display ?? display,
      count: (existing?.count ?? 0) + 1,
    );
  }

  String resolve({String fallback = '未知艺人'}) {
    if (_candidates.isEmpty) return fallback;
    if (_candidates.length == 1) return _candidates.values.single.display;

    final ranked = _candidates.values.toList(growable: false)
      ..sort((left, right) => right.count.compareTo(left.count));
    if (ranked[0].count > ranked[1].count) return ranked[0].display;

    Set<String>? commonParts;
    final displayByPart = <String, String>{};
    for (final candidate in _candidates.values) {
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
