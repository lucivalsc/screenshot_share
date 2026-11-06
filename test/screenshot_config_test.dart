import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

void main() {
  // The configuration is a process-wide singleton: without this the suite
  // becomes order-dependent, which is exactly what version 0.1.4's single
  // test set up for whoever added the second one.
  setUp(ScreenshotConfig.resetToDefaults);
  tearDown(ScreenshotConfig.resetToDefaults);

  group('defaults', () {
    test('uses safe defaults', () {
      final config = ScreenshotConfig();

      expect(config.imageQuality, 90);
      expect(config.shareMode, ShareMode.shareWithApps);
      expect(config.resizeStrategy, ResizeStrategy.fitContain);
      expect(config.fileNamePrefix, 'screenshot');
      expect(config.savePath, isNull);
      expect(config.pixelRatio, isNull);
      expect(config.showButtonsInDebugOnly, isTrue);
      expect(
          config.maxStoredCaptures, ScreenshotConfig.defaultMaxStoredCaptures);
      expect(config.maxTotalBytes, ScreenshotConfig.defaultMaxTotalBytes);
      expect(config.strings, same(ScreenshotStrings.en));
    });

    test('resetToDefaults undoes configure', () {
      ScreenshotConfig.configure(imageQuality: 10, fileNamePrefix: 'custom');
      expect(ScreenshotConfig().imageQuality, 10);

      ScreenshotConfig.resetToDefaults();

      expect(ScreenshotConfig().imageQuality, 90);
      expect(ScreenshotConfig().fileNamePrefix, 'screenshot');
    });
  });

  group('validation', () {
    test('rejects imageQuality outside 1-100', () {
      expect(
        () => ScreenshotConfig.configure(imageQuality: 0),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(imageQuality: 101),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(imageQuality: -5),
        throwsArgumentError,
      );
    });

    test('accepts imageQuality at the boundaries', () {
      ScreenshotConfig.configure(imageQuality: 1);
      expect(ScreenshotConfig().imageQuality, 1);

      ScreenshotConfig.configure(imageQuality: 100);
      expect(ScreenshotConfig().imageQuality, 100);
    });

    test('rejects pixelRatio outside the supported range', () {
      expect(
        () => ScreenshotConfig.configure(pixelRatio: 0.5),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(pixelRatio: 4),
        throwsArgumentError,
      );
    });

    test('rejects empty collections and blank savePath', () {
      expect(
        () => ScreenshotConfig.configure(screenSizes: const []),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(deviceTypes: const []),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(savePath: '   '),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range buffer limits', () {
      expect(
        () => ScreenshotConfig.configure(maxStoredCaptures: 0),
        throwsArgumentError,
      );
      expect(
        () => ScreenshotConfig.configure(maxTotalBytes: 10),
        throwsArgumentError,
      );
    });

    test('sanitises fileNamePrefix against path traversal', () {
      ScreenshotConfig.configure(fileNamePrefix: '../../etc/pa:ss*wd');

      final prefix = ScreenshotConfig().fileNamePrefix;
      expect(prefix, isNot(contains('..')));
      expect(prefix, isNot(contains('/')));
      expect(prefix, isNot(contains(':')));
      expect(prefix, isNot(contains('*')));
    });

    test('falls back when fileNamePrefix sanitises to nothing', () {
      ScreenshotConfig.configure(fileNamePrefix: '///');
      expect(ScreenshotConfig().fileNamePrefix, 'screenshot');
    });
  });

  group('screenSizes precedence', () {
    test('explicit sizes win over device types', () {
      final custom = [
        ScreenSize(width: 100, height: 200, suffix: 'tiny'),
      ];

      ScreenshotConfig.configure(
        deviceTypes: [DeviceType.ipad],
        screenSizes: custom,
      );

      expect(ScreenshotConfig().screenSizes, equals(custom));
    });

    test('device types filter the built-in set', () {
      ScreenshotConfig.configure(deviceTypes: [DeviceType.android]);

      final sizes = ScreenshotConfig().screenSizes;
      expect(sizes, hasLength(2));
      expect(sizes.every((s) => s.suffix.startsWith('android_')), isTrue);
    });

    test('defaults to the mobile set when nothing is filtered', () {
      final sizes = ScreenshotConfig().screenSizes;

      // Android (2) + iPhone (2) + iPad (2)
      expect(sizes, hasLength(6));
      expect(sizes.map((s) => s.suffix).toSet(), hasLength(6));
    });

    test('desktop device types now resolve to real resolutions', () {
      // In 0.1.4 these mapped to empty lists, so selecting them produced an
      // empty variant list and a generic "list is empty" failure.
      for (final type in [
        DeviceType.windows,
        DeviceType.macos,
        DeviceType.linux,
      ]) {
        ScreenshotConfig.resetToDefaults();
        ScreenshotConfig.configure(deviceTypes: [type]);

        final sizes = ScreenshotConfig().screenSizes;
        expect(sizes, isNotEmpty, reason: 'sem resoluções para ${type.name}');
        expect(sizes.every((s) => s.width > 0 && s.height > 0), isTrue);
      }
    });

    test('every device type exposes at least one resolution', () {
      for (final type in DeviceType.values) {
        expect(
          ScreenshotConfig.sizesForDeviceType(type),
          isNotEmpty,
          reason: 'DeviceType.${type.name} está vazio',
        );
      }
    });

    test('returned list is unmodifiable', () {
      final sizes = ScreenshotConfig().screenSizes;
      expect(
        () => sizes.add(ScreenSize(width: 1, height: 1, suffix: 'x')),
        throwsUnsupportedError,
      );
    });
  });

  group('misc getters', () {
    test('clampPixelRatio honours the supported bounds', () {
      expect(ScreenshotConfig.clampPixelRatio(0.1), 1.0);
      expect(ScreenshotConfig.clampPixelRatio(2.0), 2.0);
      expect(ScreenshotConfig.clampPixelRatio(9.0), 3.0);
    });

    test('shouldShowButtons follows showButtonsInDebugOnly', () {
      ScreenshotConfig.configure(showButtonsInDebugOnly: false);
      expect(ScreenshotConfig().shouldShowButtons, isTrue);
    });

    test('stores strings and background colour', () {
      ScreenshotConfig.configure(
        strings: ScreenshotStrings.ptBr,
        backgroundColor: const Color(0xFF123456),
      );

      expect(ScreenshotConfig().strings.cancel, 'Cancelar');
      expect(ScreenshotConfig().backgroundColor, const Color(0xFF123456));
    });
  });
}
