import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../enums/resize_strategy.dart';
import '../exceptions/screenshot_exceptions.dart';
import '../models/screen_size.dart';
import '../models/screenshot_data.dart';

/// Decodes a capture and produces one JPEG variant per target resolution.
///
/// The work runs in a background isolate and each variant is written straight
/// to [outputDirectoryPath], so the caller only receives lightweight metadata
/// instead of holding every image in memory.
class ImageProcessor {
  /// Creates an image processor.
  const ImageProcessor();

  /// Processes [pngBytes] into one variant per entry of [screenSizes].
  ///
  /// Throws [ImageProcessingException] identifying the failing stage and
  /// target size. Never returns an empty list for a non-empty input.
  Future<List<ScreenshotData>> processImage({
    required Uint8List pngBytes,
    required String screenName,
    required List<ScreenSize> screenSizes,
    required int imageQuality,
    required ResizeStrategy resizeStrategy,
    required int backgroundColor,
    required String outputDirectoryPath,
    required int timestamp,
  }) {
    if (screenSizes.isEmpty) {
      throw const ImageProcessingException(
        'Nenhuma resolução alvo informada',
        stage: ImageProcessingStage.resize,
      );
    }

    return compute(
      _processImageIsolate,
      _ImageProcessParams(
        pngBytes: pngBytes,
        screenName: screenName,
        screenSizes: screenSizes,
        imageQuality: imageQuality,
        resizeStrategy: resizeStrategy,
        backgroundColor: backgroundColor,
        outputDirectoryPath: outputDirectoryPath,
        timestamp: timestamp,
      ),
      debugLabel: 'screenshot_share.processImage',
    );
  }
}

/// Entry point executed inside the background isolate.
List<ScreenshotData> _processImageIsolate(_ImageProcessParams params) {
  final img.Image decoded;
  try {
    final result = img.decodePng(params.pngBytes);
    if (result == null) {
      throw const ImageProcessingException(
        'decodePng retornou null; os bytes capturados não são um PNG válido',
        stage: ImageProcessingStage.decode,
      );
    }
    decoded = result;
  } on ImageProcessingException {
    rethrow;
  } catch (error, stackTrace) {
    throw ImageProcessingException(
      'Falha ao decodificar a imagem capturada '
      '(${params.pngBytes.length} bytes)',
      stage: ImageProcessingStage.decode,
      cause: error,
      causeStackTrace: stackTrace,
    );
  }

  final captureId = '${params.screenName}_${params.timestamp}';
  final background = img.ColorRgb8(
    (params.backgroundColor >> 16) & 0xFF,
    (params.backgroundColor >> 8) & 0xFF,
    params.backgroundColor & 0xFF,
  );

  final screenshots = <ScreenshotData>[];

  for (var index = 0; index < params.screenSizes.length; index++) {
    final size = params.screenSizes[index];

    final img.Image fitted;
    try {
      fitted = _fitToSize(decoded, size, params.resizeStrategy, background);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Falha ao redimensionar para ${size.width}x${size.height}',
        stage: ImageProcessingStage.resize,
        sizeIndex: index,
        size: size,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    final List<int> jpegBytes;
    try {
      jpegBytes = img.encodeJpg(fitted, quality: params.imageQuality);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Falha ao codificar JPEG (qualidade ${params.imageQuality})',
        stage: ImageProcessingStage.encode,
        sizeIndex: index,
        size: size,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    final filename = '${params.screenName}_${params.timestamp}'
        '_${size.suffix}.jpg';
    final file = File('${params.outputDirectoryPath}'
        '${Platform.pathSeparator}$filename');

    try {
      file.writeAsBytesSync(jpegBytes, flush: true);
    } catch (error, stackTrace) {
      throw ImageProcessingException(
        'Falha ao gravar a variante em ${file.path}',
        stage: ImageProcessingStage.write,
        sizeIndex: index,
        size: size,
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    screenshots.add(
      ScreenshotData(
        path: file.path,
        filename: filename,
        width: size.width,
        height: size.height,
        sizeInBytes: jpegBytes.length,
        group: captureId,
        timestamp: params.timestamp,
      ),
    );
  }

  return screenshots;
}

/// Fits [source] into [size] according to [strategy].
img.Image _fitToSize(
  img.Image source,
  ScreenSize size,
  ResizeStrategy strategy,
  img.Color background,
) {
  switch (strategy) {
    case ResizeStrategy.stretch:
      return img.copyResize(
        source,
        width: size.width,
        height: size.height,
        interpolation: img.Interpolation.linear,
      );

    case ResizeStrategy.fitContain:
      final scale = math.min(
        size.width / source.width,
        size.height / source.height,
      );
      final scaledWidth = math.max(1, (source.width * scale).round());
      final scaledHeight = math.max(1, (source.height * scale).round());

      final scaled = img.copyResize(
        source,
        width: scaledWidth,
        height: scaledHeight,
        interpolation: img.Interpolation.linear,
      );

      final canvas = img.Image(
        width: size.width,
        height: size.height,
        backgroundColor: background,
      )..clear(background);

      final dstX = (size.width - scaledWidth) ~/ 2;
      final dstY = (size.height - scaledHeight) ~/ 2;

      return img.compositeImage(
        canvas,
        scaled,
        dstX: dstX,
        dstY: dstY,
      );

    case ResizeStrategy.fitCover:
      final scale = math.max(
        size.width / source.width,
        size.height / source.height,
      );
      final coveredWidth = math.max(size.width, (source.width * scale).ceil());
      final coveredHeight =
          math.max(size.height, (source.height * scale).ceil());

      final covered = img.copyResize(
        source,
        width: coveredWidth,
        height: coveredHeight,
        interpolation: img.Interpolation.linear,
      );

      return img.copyCrop(
        covered,
        x: (coveredWidth - size.width) ~/ 2,
        y: (coveredHeight - size.height) ~/ 2,
        width: size.width,
        height: size.height,
      );
  }
}

/// Parameters handed to the background isolate.
@immutable
class _ImageProcessParams {
  final Uint8List pngBytes;
  final String screenName;
  final List<ScreenSize> screenSizes;
  final int imageQuality;
  final ResizeStrategy resizeStrategy;
  final int backgroundColor;
  final String outputDirectoryPath;
  final int timestamp;

  const _ImageProcessParams({
    required this.pngBytes,
    required this.screenName,
    required this.screenSizes,
    required this.imageQuality,
    required this.resizeStrategy,
    required this.backgroundColor,
    required this.outputDirectoryPath,
    required this.timestamp,
  });
}
