/// Native-only; never invoked on web (Drift uses [DriftWebOptions] instead).
Future<String> resolveLibraryDatabaseFilePath() async {
  throw UnsupportedError(
    'resolveLibraryDatabaseFilePath is only available on native platforms.',
  );
}
