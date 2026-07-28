import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/domain/library_models.dart';
import 'package:kaiting/library/library_records.dart';
import 'package:kaiting/presentation/models/library_source_filter.dart';
import 'package:kaiting/sources/source_provider.dart';

void main() {
  test('source identifiers preserve unknown future providers', () {
    final libraryType = LibrarySourceType.fromName('subsonic');
    final domainType = SourceKind.fromName(libraryType.name);

    expect(libraryType, const LibrarySourceType('subsonic'));
    expect(libraryType.name, 'subsonic');
    expect(domainType, const SourceKind('subsonic'));
    expect(domainType.label, 'subsonic');
  });

  test('registry exposes capabilities and rejects duplicate identifiers', () {
    final local = builtInSourceProviders.providerFor(LibrarySourceType.local);
    final webDav = builtInSourceProviders.providerFor(LibrarySourceType.webDav);

    expect(
      local!.supports(SourceProviderCapability.directorySelection),
      isTrue,
    );
    expect(
      local.supports(SourceProviderCapability.connectionManagement),
      isFalse,
    );
    expect(
      webDav!.supports(SourceProviderCapability.connectionManagement),
      isTrue,
    );
    expect(() => SourceProviderRegistry([local, local]), throwsArgumentError);
  });

  test('scan registry routes by provider identifier', () async {
    final local = _FakeScanProvider(LibrarySourceType.local);
    final future = _FakeScanProvider(const LibrarySourceType('subsonic'));
    final registry = SourceScanProviderRegistry([local, future]);

    final result = await registry
        .requireProvider(const LibrarySourceType('subsonic'))
        .rescan('album-1');

    expect(result.indexedTracks, 1);
    expect(future.lastSourceId, 'album-1');
    expect(
      () => registry.requireProvider(LibrarySourceType.webDav),
      throwsStateError,
    );
    expect(
      () => SourceScanProviderRegistry([local, local]),
      throwsArgumentError,
    );
  });

  test(
    'connection registry routes a future protocol without shared branches',
    () {
      final provider = _FakeConnectionProvider(
        const LibrarySourceType('subsonic'),
      );
      final registry = SourceConnectionProviderRegistry([provider]);

      expect(
        registry.requireProvider(const LibrarySourceType('subsonic')),
        same(provider),
      );
      expect(
        () => SourceConnectionProviderRegistry([provider, provider]),
        throwsArgumentError,
      );
    },
  );

  test('library filters expose future sources without adding enum cases', () {
    final options = LibrarySourceFilter.options(const [
      SourceKind('subsonic'),
      SourceKind.local,
      SourceKind('subsonic'),
    ]);

    expect(options.map((option) => option.label), ['全部来源', '本地', 'subsonic']);
    expect(options.last.matches(const SourceKind('subsonic')), isTrue);
    expect(options.last.matches(SourceKind.local), isFalse);
  });
}

class _FakeScanProvider implements SourceScanProvider {
  _FakeScanProvider(this.type);

  @override
  final LibrarySourceType type;

  String? lastSourceId;

  @override
  bool cancel(String sourceId) => true;

  @override
  bool isScanning(String sourceId) => false;

  @override
  Future<SourceScanSummary> rescan(String sourceId) async {
    lastSourceId = sourceId;
    return const SourceScanSummary(indexedTracks: 1);
  }
}

class _FakeConnectionProvider implements SourceConnectionProvider {
  _FakeConnectionProvider(this.type);

  @override
  final LibrarySourceType type;

  @override
  Future<SourceDirectoryBrowser> openBrowser(String connectionId) {
    throw UnimplementedError();
  }

  @override
  Future<SourceManagedResource> probe(String connectionId) {
    throw UnimplementedError();
  }

  @override
  Future<void> remove(String resourceId) async {}

  @override
  Stream<List<SourceManagedResource>> watchResources() => const Stream.empty();
}
