/// Utility helpers to prevent sensitive tokens, auth codes, or signed URLs
/// from appearing in debug/crash logs.
class LogSanitizer {
  /// Returns only scheme, host, and path for a [Uri], stripping query
  /// parameters and fragments that may hold OAuth codes or signed tokens.
  static String sanitizeUri(Uri uri) {
    final hostPart = uri.host.isNotEmpty ? '://${uri.host}' : ':';
    return '${uri.scheme}$hostPart${uri.path}';
  }

  /// Parses [rawUrl] and returns a query/fragment-free representation.
  static String sanitizeUrl(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '<empty>';
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null || !parsed.hasScheme) {
      return '<local-or-invalid-path>';
    }
    if (parsed.scheme == 'file') {
      return 'file://<local-file>';
    }
    return sanitizeUri(parsed);
  }

  /// Masks a secret/token, keeping at most the first 4 characters.
  static String maskToken(String? token) {
    if (token == null || token.isEmpty) return '<empty>';
    if (token.length <= 4) return '••••';
    return '${token.substring(0, 4)}••••';
  }
}
