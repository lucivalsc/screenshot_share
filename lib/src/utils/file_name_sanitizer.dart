/// Characters that are illegal in filenames on Windows, and control
/// characters that are unsafe on every platform.
final RegExp _illegalCharacters = RegExp(r'[\x00-\x1F<>:"/\\|?*]');
final RegExp _pathTraversal = RegExp(r'\.{2,}');
final RegExp _repeatedSeparators = RegExp(r'_{2,}');
final RegExp _edgeNoise = RegExp(r'^[_\s.]+|[_\s.]+$');

/// Maximum length of a single sanitised filename component.
const int maxFileNameComponentLength = 60;

/// Makes [input] safe to use as a filename component and as a ZIP entry name.
///
/// Strips path separators, Windows-illegal characters, control characters and
/// `..` sequences — the last one preventing a *zip-slip* when the archive is
/// later extracted by the recipient. Returns [fallback] when nothing usable
/// remains.
String sanitizeFileNameComponent(String input, {String fallback = 'file'}) {
  final sanitized = input
      .replaceAll(_illegalCharacters, '_')
      .replaceAll(_pathTraversal, '_')
      .replaceAll(_repeatedSeparators, '_')
      .replaceAll(_edgeNoise, '');

  if (sanitized.isEmpty) return fallback;

  return sanitized.length > maxFileNameComponentLength
      ? sanitized.substring(0, maxFileNameComponentLength)
      : sanitized;
}
