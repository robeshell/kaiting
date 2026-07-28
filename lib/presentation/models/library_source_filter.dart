import 'package:flutter/material.dart';

import '../../core/kaiting_icons.dart';
import '../../domain/library_models.dart';

class LibrarySourceFilter {
  const LibrarySourceFilter(this.source);

  static const all = LibrarySourceFilter(null);
  static const local = LibrarySourceFilter(SourceKind.local);
  static const webDav = LibrarySourceFilter(SourceKind.webDav);

  final SourceKind? source;

  String get label => source == null ? '全部来源' : source!.label;

  IconData get icon => source == null ? KaitingIcons.library : source!.icon;

  bool matches(SourceKind candidate) => source == null || source == candidate;

  static List<LibrarySourceFilter> options(Iterable<SourceKind> sources) {
    final unique = sources.toSet().toList()
      ..sort((left, right) {
        if (left == SourceKind.local) return -1;
        if (right == SourceKind.local) return 1;
        return left.label.compareTo(right.label);
      });
    return [all, for (final source in unique) LibrarySourceFilter(source)];
  }

  @override
  bool operator ==(Object other) {
    return other is LibrarySourceFilter && other.source == source;
  }

  @override
  int get hashCode => source.hashCode;
}
