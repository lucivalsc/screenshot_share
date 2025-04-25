// Serviço de armazenamento
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

import '../config/screenshot_config.dart';
import '../models/screenshot_data.dart';

/// Service for storing and sharing screenshots
class StorageService {
  // Singleton pattern
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  /// Save a list of screenshots to the device storage
  Future<String?> saveScreenshotsLocally(List<ScreenshotData> screenshots) async {
    try {
      if (screenshots.isEmpty) {
        debugPrint('⚠️ No screenshots to save');
        return null;
      }

      // Check storage permission
      final permission = await _requestStoragePermission();
      if (!permission) {
        debugPrint('❌ Storage permission denied');
        return null;
      }

      // Determine save directory
      final directory = await _getSaveDirectory();
      if (directory == null) {
        debugPrint('❌ Could not get save directory');
        return null;
      }

      // Create a subfolder with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final subfolder = Directory('${directory.path}/screenshots_$timestamp');
      if (!await subfolder.exists()) {
        await subfolder.create(recursive: true);
      }

      // Save each screenshot
      final savedFiles = <String>[];
      for (var screenshot in screenshots) {
        final file = File('${subfolder.path}/${screenshot.filename}');
        await file.writeAsBytes(screenshot.bytes);
        savedFiles.add(file.path);
        debugPrint('✅ Saved screenshot: ${file.path}');
      }

      debugPrint('✅ Saved ${savedFiles.length} screenshots to ${subfolder.path}');
      return subfolder.path;
    } catch (e) {
      debugPrint('❌ Error saving screenshots: $e');
      return null;
    }
  }

  /// Share screenshots with other apps
  Future<bool> shareScreenshots(List<ScreenshotData> screenshots) async {
    try {
      if (screenshots.isEmpty) {
        debugPrint('⚠️ No screenshots to share');
        return false;
      }

      // Determine temporary directory for sharing
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final shareFolder = Directory('${directory.path}/share_$timestamp');
      
      if (!await shareFolder.exists()) {
        await shareFolder.create(recursive: true);
      }

      // Save files to temp folder for sharing
      final filesToShare = <XFile>[];
      for (var screenshot in screenshots) {
        final file = File('${shareFolder.path}/${screenshot.filename}');
        await file.writeAsBytes(screenshot.bytes);
        filesToShare.add(XFile(file.path, mimeType: 'image/jpeg'));
      }

      // Share files
      await Share.shareXFiles(
        filesToShare,
        subject: 'Screenshots',
        text: 'Sharing ${filesToShare.length} screenshots',
      );

      debugPrint('✅ Shared ${filesToShare.length} screenshots');
      return true;
    } catch (e) {
      debugPrint('❌ Error sharing screenshots: $e');
      return false;
    }
  }

  /// Create a ZIP archive from screenshots
  Future<Uint8List> createZipArchive(List<ScreenshotData> screenshots, String archiveName) async {
    try {
      final archive = Archive();

      for (var screenshot in screenshots) {
        archive.addFile(
          ArchiveFile(
            screenshot.filename,
            screenshot.bytes.length,
            screenshot.bytes,
          ),
        );
      }

      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      if (zipBytes == null) {
        throw Exception('Failed to create ZIP archive');
      }

      return Uint8List.fromList(zipBytes);
    } catch (e) {
      debugPrint('❌ Error creating ZIP archive: $e');
      rethrow;
    }
  }

  /// Save a ZIP file to the device storage
  Future<String?> saveZipArchive(Uint8List zipBytes, String archiveName) async {
    try {
      // Check storage permission
      final permission = await _requestStoragePermission();
      if (!permission) {
        debugPrint('❌ Storage permission denied');
        return null;
      }

      // Determine save directory
      final directory = await _getSaveDirectory();
      if (directory == null) {
        debugPrint('❌ Could not get save directory');
        return null;
      }

      // Save the ZIP file
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFile = File('${directory.path}/${archiveName}_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      debugPrint('✅ Saved ZIP file: ${zipFile.path}');
      return zipFile.path;
    } catch (e) {
      debugPrint('❌ Error saving ZIP file: $e');
      return null;
    }
  }

  /// Share a ZIP file with other apps
  Future<bool> shareZipArchive(Uint8List zipBytes, String archiveName) async {
    try {
      // Save ZIP to temporary directory
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final zipFile = File('${directory.path}/${archiveName}_$timestamp.zip');
      await zipFile.writeAsBytes(zipBytes);

      // Share the ZIP file
      await Share.shareXFiles(
        [XFile(zipFile.path, mimeType: 'application/zip')],
        subject: 'Screenshots ZIP',
        text: 'Sharing screenshots archive',
      );

      debugPrint('✅ Shared ZIP file: ${zipFile.path}');
      return true;
    } catch (e) {
      debugPrint('❌ Error sharing ZIP file: $e');
      return false;
    }
  }

  /// Request storage permission
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      // No need to check permission on other platforms
      return true;
    }

    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    return status.isGranted;
  }

  /// Get the directory for saving screenshots
  Future<Directory?> _getSaveDirectory() async {
    try {
      // Use custom path if specified in config
      final customPath = ScreenshotConfig().savePath;
      if (customPath != null && customPath.isNotEmpty) {
        final directory = Directory(customPath);
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }
        return directory;
      }

      // Default paths based on platform
      if (Platform.isAndroid) {
        return await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        return await getApplicationDocumentsDirectory();
      } else {
        return await getApplicationDocumentsDirectory();
      }
    } catch (e) {
      debugPrint('❌ Error getting save directory: $e');
      return null;
    }
  }
}