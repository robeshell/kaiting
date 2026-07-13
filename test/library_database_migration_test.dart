import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sound_player/library/persistence/library_database.dart';

import 'generated_migrations/sound_library/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('migrates the v1 catalog to the v2 user-state schema', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.schemaAt(1);
    final database = LibraryDatabase(schema.newConnection());

    await verifier.migrateAndValidate(database, 2);

    await database.close();
    schema.close();
  });
}
