import 'package:http/http.dart' as http;

/// Creates the default HTTP client for web (browser-based).
http.Client createDefaultWebDavClient() {
  return http.Client();
}

/// On web, TLS is handled by the browser — the lenient client is identical to
/// the default client.
http.Client createLenientWebDavClient() {
  return http.Client();
}

/// Parses an HTTP-date string (RFC 1123 / 7231) on platforms without dart:io.
///
/// Handles the three HTTP-date formats:
/// - IMF-fixdate: `Sun, 06 Nov 1994 08:49:37 GMT` (preferred)
/// - RFC 850:     `Sunday, 06-Nov-94 08:49:37 GMT` (obsolete)
/// - asctime:     `Sun Nov  6 08:49:37 1994` (obsolete)
DateTime? parseHttpDate(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final trimmed = value.trim();

    // IMF-fixdate: "Sun, 06 Nov 1994 08:49:37 GMT"
    final imfMatch = _imfFixdateRx.firstMatch(trimmed);
    if (imfMatch != null) {
      return DateTime.utc(
        int.parse(imfMatch.group(3)!),
        _monthIndex(imfMatch.group(2)!),
        int.parse(imfMatch.group(1)!),
        int.parse(imfMatch.group(4)!),
        int.parse(imfMatch.group(5)!),
        int.parse(imfMatch.group(6)!),
      );
    }

    // RFC 850: "Sunday, 06-Nov-94 08:49:37 GMT"
    final rfc850Match = _rfc850Rx.firstMatch(trimmed);
    if (rfc850Match != null) {
      var year = int.parse(rfc850Match.group(3)!);
      // Two-digit years: 00-49 → 2000s, 50-99 → 1900s
      year = year < 50 ? year + 2000 : year + 1900;
      return DateTime.utc(
        year,
        _monthIndex(rfc850Match.group(2)!),
        int.parse(rfc850Match.group(1)!),
        int.parse(rfc850Match.group(4)!),
        int.parse(rfc850Match.group(5)!),
        int.parse(rfc850Match.group(6)!),
      );
    }

    // asctime: "Sun Nov  6 08:49:37 1994"
    // groups: 1=month 2=day 3=hour 4=minute 5=second 6=year
    final asctimeMatch = _asctimeRx.firstMatch(trimmed);
    if (asctimeMatch != null) {
      final day = int.parse(asctimeMatch.group(2)!.trim());
      return DateTime.utc(
        int.parse(asctimeMatch.group(6)!),
        _monthIndex(asctimeMatch.group(1)!),
        day,
        int.parse(asctimeMatch.group(3)!),
        int.parse(asctimeMatch.group(4)!),
        int.parse(asctimeMatch.group(5)!),
      );
    }

    return null;
  } catch (_) {
    return null;
  }
}

int _monthIndex(String name) {
  const months = {
    'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
    'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
    'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
  };
  return months[name.toLowerCase()] ?? 1;
}

/// Returns `null` on web — TLS errors are handled by the browser and do not
/// surface as exceptions.
String? tryGetTlsFriendlyMessage(Object error) => null;

// Matches: "Sun, 06 Nov 1994 08:49:37 GMT"
final _imfFixdateRx = RegExp(
  r'^\w{3},\s+(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  caseSensitive: false,
);

// Matches: "Sunday, 06-Nov-94 08:49:37 GMT"
final _rfc850Rx = RegExp(
  r'^\w+,\s+(\d{1,2})-(\w{3})-(\d{2,4})\s+(\d{2}):(\d{2}):(\d{2})\s+GMT$',
  caseSensitive: false,
);

// Matches: "Sun Nov  6 08:49:37 1994"
final _asctimeRx = RegExp(
  r'^\w{3}\s+(\w{3})\s+(\s?\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})$',
  caseSensitive: false,
);
