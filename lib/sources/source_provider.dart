import '../library/library_records.dart';

enum SourceProviderCapability {
  directorySelection,
  connectionManagement,
  directoryBrowsing,
  scanning,
  streaming,
  offline,
}

class SourceProviderDefinition {
  const SourceProviderDefinition({
    required this.type,
    required this.displayName,
    required this.addActionLabel,
    required this.sectionDescription,
    required this.capabilities,
  });

  final LibrarySourceType type;
  final String displayName;
  final String addActionLabel;
  final String sectionDescription;
  final Set<SourceProviderCapability> capabilities;

  bool supports(SourceProviderCapability capability) {
    return capabilities.contains(capability);
  }
}

class SourceProviderRegistry {
  SourceProviderRegistry(Iterable<SourceProviderDefinition> providers)
    : _providers = List.unmodifiable(providers) {
    final identifiers = <String>{};
    for (final provider in _providers) {
      if (!identifiers.add(provider.type.name)) {
        throw ArgumentError('Duplicate source provider: ${provider.type.name}');
      }
    }
  }

  final List<SourceProviderDefinition> _providers;

  List<SourceProviderDefinition> get providers => _providers;

  SourceProviderDefinition? providerFor(LibrarySourceType type) {
    for (final provider in _providers) {
      if (provider.type == type) return provider;
    }
    return null;
  }
}

class SourceScanSummary {
  const SourceScanSummary({
    required this.indexedTracks,
    this.skippedFiles = 0,
    this.addedTracks = 0,
    this.modifiedTracks = 0,
    this.movedTracks = 0,
    this.removedTracks = 0,
    this.unchangedTracks = 0,
    this.warnings = const <String>[],
  });

  final int indexedTracks;
  final int skippedFiles;
  final int addedTracks;
  final int modifiedTracks;
  final int movedTracks;
  final int removedTracks;
  final int unchangedTracks;
  final List<String> warnings;
}

abstract interface class SourceScanProvider {
  LibrarySourceType get type;

  bool isScanning(String sourceId);

  bool cancel(String sourceId);

  Future<SourceScanSummary> rescan(String sourceId);
}

class SourceScanProviderRegistry {
  SourceScanProviderRegistry(Iterable<SourceScanProvider> providers) {
    final providersByType = <LibrarySourceType, SourceScanProvider>{};
    for (final provider in providers) {
      if (providersByType.containsKey(provider.type)) {
        throw ArgumentError(
          'Duplicate source scan provider: ${provider.type.name}',
        );
      }
      providersByType[provider.type] = provider;
    }
    _providers = Map.unmodifiable(providersByType);
  }

  late final Map<LibrarySourceType, SourceScanProvider> _providers;

  SourceScanProvider? providerFor(LibrarySourceType type) => _providers[type];

  SourceScanProvider requireProvider(LibrarySourceType type) {
    final provider = providerFor(type);
    if (provider == null) {
      throw StateError('No scan provider registered for ${type.name}.');
    }
    return provider;
  }
}

class SourceDirectoryEntry {
  const SourceDirectoryEntry({
    required this.id,
    required this.displayName,
    required this.isDirectory,
  });

  final String id;
  final String displayName;
  final bool isDirectory;
}

abstract interface class SourceDirectoryBrowser {
  String get rootId;

  Future<List<SourceDirectoryEntry>> browse(String directoryId);
}

class SourceBrowseException implements Exception {
  const SourceBrowseException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum SourceManagedResourceKind { connection, catalog }

enum SourceManagedStatus {
  idle,
  working,
  available,
  authenticationFailed,
  unavailable,
  error,
}

class SourceManagedResource {
  const SourceManagedResource({
    required this.id,
    required this.type,
    required this.kind,
    required this.displayName,
    required this.location,
    required this.status,
    this.parentConnectionId,
    this.errorMessage,
  });

  final String id;
  final LibrarySourceType type;
  final SourceManagedResourceKind kind;
  final String displayName;
  final String location;
  final SourceManagedStatus status;

  /// The connection that owns this catalog resource.
  ///
  /// Connection resources leave this unset. Exposing the relationship here
  /// lets settings surfaces present remote sources as a connection tree
  /// without depending on provider-specific ID formats.
  final String? parentConnectionId;
  final String? errorMessage;

  bool get isAvailable => status == SourceManagedStatus.available;
}

abstract interface class SourceConnectionProvider {
  LibrarySourceType get type;

  Stream<List<SourceManagedResource>> watchResources();

  Future<SourceManagedResource> probe(String connectionId);

  Future<SourceDirectoryBrowser> openBrowser(String connectionId);

  Future<void> remove(String resourceId);
}

class SourceConnectionProviderRegistry {
  SourceConnectionProviderRegistry(
    Iterable<SourceConnectionProvider> providers,
  ) {
    final providersByType = <LibrarySourceType, SourceConnectionProvider>{};
    for (final provider in providers) {
      if (providersByType.containsKey(provider.type)) {
        throw ArgumentError(
          'Duplicate source connection provider: ${provider.type.name}',
        );
      }
      providersByType[provider.type] = provider;
    }
    _providers = Map.unmodifiable(providersByType);
  }

  late final Map<LibrarySourceType, SourceConnectionProvider> _providers;

  SourceConnectionProvider? providerFor(LibrarySourceType type) {
    return _providers[type];
  }

  SourceConnectionProvider requireProvider(LibrarySourceType type) {
    final provider = providerFor(type);
    if (provider == null) {
      throw StateError('No connection provider registered for ${type.name}.');
    }
    return provider;
  }
}

final builtInSourceProviders = SourceProviderRegistry(const [
  SourceProviderDefinition(
    type: LibrarySourceType.local,
    displayName: '本地文件夹',
    addActionLabel: '添加本地文件夹',
    sectionDescription: '来自此设备或系统文件选择器',
    capabilities: {
      SourceProviderCapability.directorySelection,
      SourceProviderCapability.scanning,
      SourceProviderCapability.streaming,
      SourceProviderCapability.offline,
    },
  ),
  SourceProviderDefinition(
    type: LibrarySourceType.webDav,
    displayName: 'WebDAV',
    addActionLabel: '添加 WebDAV',
    sectionDescription: '服务器连接和已加入资料库的远程目录',
    capabilities: {
      SourceProviderCapability.connectionManagement,
      SourceProviderCapability.directoryBrowsing,
      SourceProviderCapability.scanning,
      SourceProviderCapability.streaming,
      SourceProviderCapability.offline,
    },
  ),
]);
