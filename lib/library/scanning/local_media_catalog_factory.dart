import 'local_media_catalog.dart';
import 'local_media_catalog_factory_stub.dart'
    if (dart.library.io) 'local_media_catalog_factory_io.dart'
    as platform;

LocalMediaCatalog createLocalMediaCatalog() =>
    platform.createLocalMediaCatalog();
