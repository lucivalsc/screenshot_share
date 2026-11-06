import 'package:flutter/foundation.dart';

import '../utils/file_name_sanitizer.dart';

/// A validated target resolution for a generated screenshot variant.
///
/// Replaces the untyped `Map<String, dynamic>` used up to version 0.1.4, so
/// malformed sizes are rejected at configuration time instead of crashing
/// inside the processing isolate.
@immutable
class ScreenSize {
  /// Target width in pixels. Always greater than zero.
  final int width;

  /// Target height in pixels. Always greater than zero.
  final int height;

  /// Filename suffix identifying this variant (already sanitised).
  final String suffix;

  /// Creates a target resolution.
  ///
  /// Throws [ArgumentError] when [width] or [height] is not a positive number
  /// within [maxDimension], or when [suffix] is empty.
  ScreenSize({
    required this.width,
    required this.height,
    required String suffix,
  }) : suffix = sanitizeFileNameComponent(suffix, fallback: 'variant') {
    if (width <= 0 || width > maxDimension) {
      throw ArgumentError.value(
        width,
        'width',
        'Deve ser maior que zero e no máximo $maxDimension',
      );
    }
    if (height <= 0 || height > maxDimension) {
      throw ArgumentError.value(
        height,
        'height',
        'Deve ser maior que zero e no máximo $maxDimension',
      );
    }
    if (suffix.trim().isEmpty) {
      throw ArgumentError.value(suffix, 'suffix', 'Não pode ser vazio');
    }
  }

  /// Upper bound for a single dimension, guarding against accidental
  /// out-of-memory conditions while resizing.
  static const int maxDimension = 20000;

  /// Builds a [ScreenSize] from the legacy map format.
  ///
  /// Accepts `int` and `double` values for `width`/`height` (a `1080.0`
  /// literal used to throw a `TypeError` inside the isolate). Throws
  /// [ArgumentError] when a key is missing or has an unsupported type.
  factory ScreenSize.fromMap(Map<String, dynamic> map) {
    return ScreenSize(
      width: _readDimension(map, 'width'),
      height: _readDimension(map, 'height'),
      suffix: _readSuffix(map),
    );
  }

  static int _readDimension(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is double) {
      if (value != value.roundToDouble()) {
        throw ArgumentError.value(
          value,
          key,
          'Deve ser um número inteiro de pixels',
        );
      }
      return value.round();
    }
    if (value == null) {
      throw ArgumentError.value(map, 'screenSizes', 'Chave "$key" ausente');
    }
    throw ArgumentError.value(
      value,
      key,
      'Deve ser int ou double, recebido ${value.runtimeType}',
    );
  }

  static String _readSuffix(Map<String, dynamic> map) {
    final value = map['suffix'];
    if (value is String) return value;
    if (value == null) {
      throw ArgumentError.value(map, 'screenSizes', 'Chave "suffix" ausente');
    }
    throw ArgumentError.value(
      value,
      'suffix',
      'Deve ser String, recebido ${value.runtimeType}',
    );
  }

  /// Serialises back to the legacy map format.
  Map<String, dynamic> toMap() => {
        'width': width,
        'height': height,
        'suffix': suffix,
      };

  @override
  bool operator ==(Object other) =>
      other is ScreenSize &&
      other.width == width &&
      other.height == height &&
      other.suffix == suffix;

  @override
  int get hashCode => Object.hash(width, height, suffix);

  @override
  String toString() => 'ScreenSize($width x $height, $suffix)';
}
