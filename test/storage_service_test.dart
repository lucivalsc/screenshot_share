import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

import 'image_processor_test.dart' show buildPng;

/// Writes a real JPEG-ish file and returns its metadata.
ScreenshotData writeFixture(
  Directory dir,
  String filename, {
  String group = 'g1',
}) {
  final file = File('${dir.path}${Platform.pathSeparator}$filename');
  final bytes = buildPng(width: 32, height: 32);
  file.writeAsBytesSync(bytes);

  return ScreenshotData(
    path: file.path,
    filename: filename,
    width: 32,
    height: 32,
    sizeInBytes: bytes.length,
    group: group,
    timestamp: 1,
  );
}

void main() {
  late Directory workDir;

  setUp(() {
    ScreenshotConfig.resetToDefaults();
    workDir = Directory.systemTemp.createTempSync('shot_storage_test');
  });

  tearDown(() {
    ScreenshotConfig.resetToDefaults();
    if (workDir.existsSync()) {
      workDir.deleteSync(recursive: true);
    }
  });

  group('ZIP assembly', () {
    // Sharing now always produces one archive. Up to 0.1.4 the
    // "share with apps" path handed over loose image files instead.
    test('archives every variant under its sanitised filename', () async {
      final shots = [
        writeFixture(workDir, 'a_android_1080x1920.jpg'),
        writeFixture(workDir, 'a_iphone_6.5_disp.jpg'),
        writeFixture(workDir, 'a_ipad_12.9_disp.jpg'),
      ];

      final zipPath = '${workDir.path}${Platform.pathSeparator}out.zip';
      final encoder = ZipFileEncoder();
      encoder.create(zipPath);
      for (final shot in shots) {
        await encoder.addFile(shot.file, shot.filename);
      }
      await encoder.close();

      final archive = ZipDecoder().decodeBytes(File(zipPath).readAsBytesSync());

      expect(archive.files, hasLength(3));
      expect(
        archive.files.map((f) => f.name).toSet(),
        shots.map((s) => s.filename).toSet(),
      );
      for (final entry in archive.files) {
        expect(entry.size, greaterThan(0));
        // No entry may escape its extraction root (zip-slip).
        expect(entry.name, isNot(contains('..')));
        expect(entry.name, isNot(startsWith('/')));
      }
    });

    test('entry names never contain path separators', () {
      final shot = writeFixture(workDir, 'plain.jpg');
      expect(shot.filename, isNot(contains('/')));
      expect(shot.filename, isNot(contains(r'\')));
    });
  });

  group('deleteScreenshotFiles', () {
    test('removes every backing file', () async {
      final shots = [
        writeFixture(workDir, 'one.jpg'),
        writeFixture(workDir, 'two.jpg'),
      ];
      expect(shots.every((s) => s.file.existsSync()), isTrue);

      await StorageService().deleteScreenshotFiles(shots);

      expect(shots.any((s) => s.file.existsSync()), isFalse);
    });

    test('tolerates files that are already gone', () async {
      final shot = writeFixture(workDir, 'gone.jpg');
      shot.file.deleteSync();

      await StorageService().deleteScreenshotFiles([shot]);
    });

    test('accepts an empty list', () async {
      await StorageService().deleteScreenshotFiles(const []);
    });
  });

  group('ScreenshotData', () {
    test('reports size in kilobytes', () {
      const shot = ScreenshotData(
        path: 'x',
        filename: 'x.jpg',
        width: 1,
        height: 1,
        sizeInBytes: 2048,
        group: 'g',
        timestamp: 0,
      );

      expect(shot.fileSizeKB, 2.0);
    });

    test('exposes the backing file by path', () {
      final shot = writeFixture(workDir, 'file.jpg');
      expect(shot.file.path, shot.path);
      expect(shot.file.existsSync(), isTrue);
    });
  });
}
