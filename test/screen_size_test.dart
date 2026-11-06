import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

void main() {
  group('construction', () {
    test('rejects non-positive dimensions', () {
      expect(
        () => ScreenSize(width: 0, height: 100, suffix: 'a'),
        throwsArgumentError,
      );
      expect(
        () => ScreenSize(width: 100, height: -1, suffix: 'a'),
        throwsArgumentError,
      );
    });

    test('rejects dimensions beyond maxDimension', () {
      expect(
        () => ScreenSize(
          width: ScreenSize.maxDimension + 1,
          height: 100,
          suffix: 'a',
        ),
        throwsArgumentError,
      );
    });

    test('sanitises the suffix', () {
      final size = ScreenSize(width: 10, height: 10, suffix: '../ip:ad*');

      expect(size.suffix, isNot(contains('..')));
      expect(size.suffix, isNot(contains('/')));
      expect(size.suffix, isNot(contains(':')));
      expect(size.suffix, isNot(contains('*')));
    });

    test('equality is by value', () {
      final a = ScreenSize(width: 10, height: 20, suffix: 's');
      final b = ScreenSize(width: 10, height: 20, suffix: 's');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('fromMap (legacy format)', () {
    test('accepts int dimensions', () {
      final size = ScreenSize.fromMap(
        const {'width': 1080, 'height': 1920, 'suffix': 'phone'},
      );

      expect(size.width, 1080);
      expect(size.height, 1920);
      expect(size.suffix, 'phone');
    });

    test('accepts whole doubles — a TypeError inside the isolate in 0.1.4', () {
      final size = ScreenSize.fromMap(
        const {'width': 1080.0, 'height': 1920.0, 'suffix': 'phone'},
      );

      expect(size.width, 1080);
      expect(size.height, 1920);
    });

    test('rejects fractional dimensions', () {
      expect(
        () => ScreenSize.fromMap(
          const {'width': 1080.5, 'height': 1920, 'suffix': 'phone'},
        ),
        throwsArgumentError,
      );
    });

    test('rejects missing keys with a clear error', () {
      expect(
        () => ScreenSize.fromMap(const {'height': 1920, 'suffix': 'phone'}),
        throwsArgumentError,
      );
      expect(
        () => ScreenSize.fromMap(const {'width': 1080, 'height': 1920}),
        throwsArgumentError,
      );
    });

    test('rejects wrong types', () {
      expect(
        () => ScreenSize.fromMap(
          const {'width': '1080', 'height': 1920, 'suffix': 'phone'},
        ),
        throwsArgumentError,
      );
      expect(
        () => ScreenSize.fromMap(
          const {'width': 1080, 'height': 1920, 'suffix': 42},
        ),
        throwsArgumentError,
      );
    });

    test('round-trips through toMap', () {
      final original = ScreenSize(width: 800, height: 600, suffix: 'desktop');
      expect(ScreenSize.fromMap(original.toMap()), equals(original));
    });

    test('screenSizesFromMaps converts a whole list', () {
      final sizes = ScreenshotConfig.screenSizesFromMaps(const [
        {'width': 100, 'height': 200, 'suffix': 'a'},
        {'width': 300, 'height': 400, 'suffix': 'b'},
      ]);

      expect(sizes, hasLength(2));
      expect(sizes.first.suffix, 'a');
    });
  });
}
