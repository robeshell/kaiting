import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaiting/library/persistence/library_database.dart';

import 'generated_migrations/sound_library/schema.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  for (final fromVersion in [1, 2]) {
    test('migrates v$fromVersion to the v3 playlist schema', () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(fromVersion);
      final database = LibraryDatabase(schema.newConnection());

      await verifier.migrateAndValidate(database, 3);

      await database.close();
      schema.close();
    });
  }
}
