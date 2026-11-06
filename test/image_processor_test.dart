import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:screenshot_share_telegram/screenshot_share.dart';
import 'package:screenshot_share_telegram/src/utils/image_processor.dart';

/// Builds a PNG with a solid fill, used as a synthetic capture.
Uint8List buildPng({
  required int width,
  required int height,
  int r = 220,
  int g = 40,
  int b = 40,
}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  late Directory workDir;

  setUp(() {
    ScreenshotConfig.resetToDefaults();
    workDir = Directory.systemTemp.createTempSync('shot_proc_test');
  });

  tearDown(() {
    ScreenshotConfig.resetToDefaults();
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }
  });

  Future<List<ScreenshotData>> process({
    required Uint8List png,
    required List<ScreenSize> sizes,
    ResizeStrategy strategy = ResizeStrategy.fitContain,
    int quality = 85,
    int background = 0x000000,
  }) {
    return const ImageProcessor().processImage(
      pngBytes: png,
      screenName: 'unit',
      screenSizes: sizes,
      imageQuality: quality,
      resizeStrategy: strategy,
      backgroundColor: background,
      outputDirectoryPath: workDir.path,
      timestamp: 1700000000000,
    );
  }

  test('writes one file per target size and returns metadata', () async {
    final sizes = [
      ScreenSize(width: 200, height: 400, suffix: 'tall'),
      ScreenSize(width: 400, height: 200, suffix: 'wide'),
    ];

    final result = await process(
      png: buildPng(width: 100, height: 100),
      sizes: sizes,
    );

    expect(result, hasLength(2));

    for (var i = 0; i < result.length; i++) {
      final shot = result[i];
      expect(shot.width, sizes[i].width);
      expect(shot.height, sizes[i].height);
      expect(shot.filename, contains(sizes[i].suffix));
      expect(shot.filename, endsWith('.jpg'));
      expect(shot.group, 'unit_1700000000000');

      // The bytes live on disk, not in memory — this is what keeps a batch
      // of captures from growing the heap without bound.
      final file = File(shot.path);
      expect(file.existsSync(), isTrue, reason: 'arquivo não gravado');
      expect(shot.sizeInBytes, file.lengthSync());
      expect(shot.sizeInBytes, greaterThan(0));
      expect(await shot.readBytes(), hasLength(shot.sizeInBytes));
    }
  });

  test('encoded files really have the requested dimensions', () async {
    final result = await process(
      png: buildPng(width: 120, height: 60),
      sizes: [ScreenSize(width: 300, height: 500, suffix: 'target')],
    );

    final decoded = img.decodeJpg(await result.single.readBytes())!;
    expect(decoded.width, 300);
    expect(decoded.height, 500);
  });

  group('resize strategies', () {
    // A square source into a tall target: the distortion that made 0.1.4's
    // output unusable for app-store submissions.
    final source = buildPng(width: 100, height: 100, r: 255, g: 0, b: 0);
    final target = ScreenSize(width: 200, height: 600, suffix: 'tall');

    test('fitContain pads instead of distorting', () async {
      final result = await process(
        png: source,
        sizes: [target],
        strategy: ResizeStrategy.fitContain,
        background: 0x0000FF,
        quality: 100,
      );

      final decoded = img.decodeJpg(await result.single.readBytes())!;
      expect(decoded.width, 200);
      expect(decoded.height, 600);

      // Top band is padding (blue-ish), the centre keeps the source (red-ish).
      final top = decoded.getPixel(100, 5);
      final centre = decoded.getPixel(100, 300);

      expect(top.b, greaterThan(top.r), reason: 'faixa superior não é padding');
      expect(centre.r, greaterThan(centre.b), reason: 'centro não é a imagem');
    });

    test('fitCover fills the frame without padding', () async {
      final result = await process(
        png: source,
        sizes: [target],
        strategy: ResizeStrategy.fitCover,
        background: 0x0000FF,
        quality: 100,
      );

      final decoded = img.decodeJpg(await result.single.readBytes())!;
      expect(decoded.width, 200);
      expect(decoded.height, 600);

      // No padding anywhere: every sampled pixel comes from the source.
      for (final y in [5, 300, 595]) {
        final pixel = decoded.getPixel(100, y);
        expect(pixel.r, greaterThan(pixel.b), reason: 'padding em y=$y');
      }
    });

    test('stretch still fills the frame exactly', () async {
      final result = await process(
        png: source,
        sizes: [target],
        strategy: ResizeStrategy.stretch,
        quality: 100,
      );

      final decoded = img.decodeJpg(await result.single.readBytes())!;
      expect(decoded.width, 200);
      expect(decoded.height, 600);

      final top = decoded.getPixel(100, 5);
      expect(top.r, greaterThan(top.b));
    });
  });

  group('error reporting', () {
    test('invalid PNG throws a typed decode failure', () async {
      // 0.1.4 swallowed this and returned an empty list, collapsing every
      // possible cause into one indistinguishable symptom.
      await expectLater(
        process(
          png: Uint8List.fromList(List<int>.filled(64, 7)),
          sizes: [ScreenSize(width: 10, height: 10, suffix: 's')],
        ),
        throwsA(
          isA<ImageProcessingException>().having(
            (e) => e.stage,
            'stage',
            ImageProcessingStage.decode,
          ),
        ),
      );
    });

    test('empty size list throws instead of returning an empty result', () {
      expect(
        () => process(png: buildPng(width: 10, height: 10), sizes: const []),
        throwsA(isA<ImageProcessingException>()),
      );
    });

    test('unwritable output directory throws a write failure', () async {
      await expectLater(
        const ImageProcessor().processImage(
          pngBytes: buildPng(width: 10, height: 10),
          screenName: 'unit',
          screenSizes: [ScreenSize(width: 10, height: 10, suffix: 's')],
          imageQuality: 80,
          resizeStrategy: ResizeStrategy.fitContain,
          backgroundColor: 0,
          outputDirectoryPath:
              '${workDir.path}${Platform.pathSeparator}nao_existe',
          timestamp: 1,
        ),
        throwsA(
          isA<ImageProcessingException>().having(
            (e) => e.stage,
            'stage',
            ImageProcessingStage.write,
          ),
        ),
      );
    });
  });

  test('quality setting changes the encoded size', () async {
    final png = buildPng(width: 200, height: 200);
    final sizes = [ScreenSize(width: 200, height: 200, suffix: 's')];

    final low = await process(png: png, sizes: sizes, quality: 10);
    final high = await process(png: png, sizes: sizes, quality: 100);

    expect(high.single.sizeInBytes, greaterThan(low.single.sizeInBytes));
  });

  test('delete() removes the backing file', () async {
    final result = await process(
      png: buildPng(width: 20, height: 20),
      sizes: [ScreenSize(width: 20, height: 20, suffix: 's')],
    );

    final shot = result.single;
    expect(File(shot.path).existsSync(), isTrue);

    await shot.delete();
    expect(File(shot.path).existsSync(), isFalse);

    // Deleting twice is a no-op, not an error.
    await shot.delete();
  });
}
