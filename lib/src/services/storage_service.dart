import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/screenshot_config.dart';
import '../exceptions/screenshot_exceptions.dart';
import '../models/screenshot_data.dart';
import '../utils/file_name_sanitizer.dart';

/// What the native share sheet reported back.
enum ShareOutcome {
  /// The archive was handed over successfully, or the platform cannot tell.
  completed,

  /// The user dismissed the share sheet without choosing a target.
  dismissed,
}

/// Filesystem, archiving and native-sharing operations.
///
/// Every destination receives a single ZIP archive: individual variants are
/// never exposed as loose files, so one capture session always travels as one
/// artefact.
class StorageService {
  static final StorageService _instance = StorageService._internal();

  /// Returns the singleton storage service.
  factory StorageService() => _instance;

  StorageService._internal();

  /// Name of the package-owned folder inside the system cache directory.
  static const String cacheFolderName = 'screenshot_share';

  /// Age after which temporary artefacts are discarded by
  /// [cleanupTemporaryArtifacts].
  static const Duration temporaryArtifactMaxAge = Duration(hours: 24);

  // --------------------------------------------------------------- locations

  /// Directory holding freshly generated variants.
  Future<Directory> captureCacheDirectory() =>
      _ensureCacheSubdirectory('captures');

  /// Directory holding assembled ZIP archives.
  Future<Directory> archiveCacheDirectory() =>
      _ensureCacheSubdirectory('archives');

  Future<Directory> _ensureCacheSubdirectory(String name) async {
    try {
      final base = await getTemporaryDirectory();
      final directory = Directory(
        '${base.path}${Platform.pathSeparator}$cacheFolderName'
        '${Platform.pathSeparator}$name',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } on FileSystemException catch (error, stackTrace) {
      throw StorageFailureException(
        'Não foi possível preparar o diretório de cache "$name"',
        isPermissionIssue: _looksLikePermissionIssue(error),
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  /// Resolves where saved archives are written.
  ///
  /// Uses `savePath` when configured, otherwise a directory the app can always
  /// write to without any OS permission. Note that version 0.1.4 requested the
  /// long-obsolete `Permission.storage` for a destination that never needed
  /// it, which made local saving fail outright on Android 13+.
  Future<Directory> resolveSaveDirectory() async {
    final customPath = ScreenshotConfig().savePath;

    if (customPath != null && customPath.isNotEmpty) {
      try {
        final directory = Directory(customPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      } on FileSystemException catch (error, stackTrace) {
        throw StorageFailureException(
          'Não foi possível usar o savePath configurado "$customPath". '
          'O diretório precisa ser gravável pelo app sem permissões extras.',
          isPermissionIssue: true,
          cause: error,
          causeStackTrace: stackTrace,
        );
      }
    }

    try {
      if (Platform.isAndroid) {
        return await getExternalStorageDirectory() ??
            await getApplicationDocumentsDirectory();
      }
      if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      }
      return await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    } catch (error, stackTrace) {
      throw StorageFailureException(
        'Não foi possível resolver o diretório de destino',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  // ----------------------------------------------------------------- archive

  /// Builds a ZIP archive containing every file in [screenshots].
  ///
  /// Entries are streamed straight from disk into the archive file, so peak
  /// memory stays flat regardless of how many captures are pending — version
  /// 0.1.4 materialised the whole archive in memory, tripling the peak.
  Future<File> createZipArchive(
    List<ScreenshotData> screenshots, {
    required String archiveName,
  }) async {
    if (screenshots.isEmpty) {
      throw const StorageFailureException(
        'Nenhuma captura para arquivar',
      );
    }

    final directory = await archiveCacheDirectory();
    final safeName = sanitizeFileNameComponent(
      archiveName,
      fallback: 'screenshots',
    );
    final zipPath = '${directory.path}${Platform.pathSeparator}'
        '${safeName}_${DateTime.now().millisecondsSinceEpoch}.zip';

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    try {
      for (final screenshot in screenshots) {
        final file = screenshot.file;
        if (!await file.exists()) {
          throw StorageFailureException(
            'Variante ausente no cache: ${screenshot.filename}. '
            'O diretório temporário pode ter sido limpo pelo sistema.',
          );
        }
        await encoder.addFile(file, screenshot.filename);
      }
    } on StorageFailureException {
      await encoder.close();
      await _deleteQuietly(File(zipPath));
      rethrow;
    } catch (error, stackTrace) {
      await encoder.close();
      await _deleteQuietly(File(zipPath));
      throw StorageFailureException(
        'Falha ao montar o arquivo ZIP',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }

    await encoder.close();
    return File(zipPath);
  }

  // -------------------------------------------------------------- operations

  /// Copies [archive] into the resolved destination directory.
  ///
  /// Returns the final absolute path.
  Future<String> saveArchiveLocally(
    File archive, {
    required String archiveName,
  }) async {
    final directory = await resolveSaveDirectory();
    final safeName = sanitizeFileNameComponent(
      archiveName,
      fallback: 'screenshots',
    );
    final target = File(
      '${directory.path}${Platform.pathSeparator}'
      '${safeName}_${DateTime.now().millisecondsSinceEpoch}.zip',
    );

    try {
      await archive.copy(target.path);
      return target.path;
    } on FileSystemException catch (error, stackTrace) {
      throw StorageFailureException(
        'Falha ao salvar o arquivo em ${target.path}',
        isPermissionIssue: _looksLikePermissionIssue(error),
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  /// Hands [archive] to the native share sheet.
  Future<ShareOutcome> shareArchive(
    File archive, {
    String? subject,
    String? text,
  }) async {
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archive.path, mimeType: 'application/zip')],
          fileNameOverrides: [_basename(archive.path)],
          subject: subject,
          text: text,
        ),
      );

      return result.status == ShareResultStatus.dismissed
          ? ShareOutcome.dismissed
          : ShareOutcome.completed;
    } catch (error, stackTrace) {
      throw StorageFailureException(
        'Falha ao acionar o compartilhamento nativo',
        cause: error,
        causeStackTrace: stackTrace,
      );
    }
  }

  // ------------------------------------------------------------------ hygiene

  /// Deletes the files backing [screenshots].
  Future<void> deleteScreenshotFiles(List<ScreenshotData> screenshots) async {
    for (final screenshot in screenshots) {
      await screenshot.delete();
    }
  }

  /// Removes package-owned temporary artefacts older than [maxAge].
  ///
  /// Version 0.1.4 never cleaned up: every share created a new timestamped
  /// folder that stayed behind indefinitely.
  Future<void> cleanupTemporaryArtifacts({
    Duration maxAge = temporaryArtifactMaxAge,
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);

    for (final directory in [
      await captureCacheDirectory(),
      await archiveCacheDirectory(),
    ]) {
      try {
        await for (final entity in directory.list(followLinks: false)) {
          try {
            final stat = await entity.stat();
            if (stat.modified.isBefore(cutoff)) {
              await entity.delete(recursive: true);
            }
          } on FileSystemException {
            // Another isolate or the OS may have removed it already.
          }
        }
      } on FileSystemException catch (error) {
        debugPrint('⚠️ Falha ao limpar ${directory.path}: $error');
      }
    }
  }

  /// Deletes [archive], used after a successful hand-off.
  Future<void> discardArchive(File archive) => _deleteQuietly(archive);

  Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      // Nothing to do: the file is already gone or locked by the receiver.
    }
  }

  static String _basename(String path) =>
      path.split(RegExp(r'[/\\]')).where((part) => part.isNotEmpty).last;

  static bool _looksLikePermissionIssue(FileSystemException error) {
    final code = error.osError?.errorCode;
    // EACCES / EPERM on POSIX, ERROR_ACCESS_DENIED on Windows.
    return code == 1 || code == 13 || code == 5;
  }
}
