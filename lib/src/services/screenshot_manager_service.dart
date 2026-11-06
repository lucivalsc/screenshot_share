import 'package:flutter/material.dart';

import '../config/screenshot_config.dart';
import '../config/screenshot_strings.dart';
import '../enums/share_mode.dart';
import '../exceptions/screenshot_exceptions.dart';
import '../models/screen_size.dart';
import '../models/screenshot_data.dart';
import '../models/screenshot_result.dart';
import '../utils/async_lock.dart';
import '../widgets/dual_button_wrapper.dart';
import 'capture_pipeline.dart';
import 'storage_service.dart';

/// Captures several screens, keeps them on disk, and shares them as one ZIP.
class ScreenshotManagerService {
  static final ScreenshotManagerService _instance =
      ScreenshotManagerService._internal();

  /// Returns the singleton service.
  factory ScreenshotManagerService() => _instance;

  ScreenshotManagerService._internal();

  /// Pending captures, keyed by group id, in insertion order.
  final Map<String, List<ScreenshotData>> _captureGroups =
      <String, List<ScreenshotData>>{};

  final AsyncLock _captureLock = AsyncLock();
  final AsyncLock _shareLock = AsyncLock();
  final CapturePipeline _pipeline = const CapturePipeline();

  /// Number of pending image variants.
  ///
  /// Listen to this instead of polling: version 0.1.4 rebuilt the whole
  /// application once per second to keep a badge up to date.
  final ValueNotifier<int> storedCount = ValueNotifier<int>(0);

  /// Total size on disk of the pending variants, in bytes.
  final ValueNotifier<int> storedBytes = ValueNotifier<int>(0);

  /// Number of pending image variants.
  int get storedScreenshotsCount => storedCount.value;

  /// Number of pending capture groups.
  int get captureGroupsCount => _captureGroups.length;

  /// Whether a capture or a share operation is currently running.
  bool get isProcessing => _captureLock.isLocked || _shareLock.isLocked;

  List<ScreenshotData> get _allScreenshots =>
      _captureGroups.values.expand((group) => group).toList(growable: false);

  /// Wraps [child] with a capture button and a share button.
  static Widget wrapScreen({
    required Widget child,
    bool? showButtons,
    AlignmentGeometry? buttonPosition,
    Color? captureButtonColor,
    Color? shareButtonColor,
    ShareMode? overrideShareMode,
    ScreenshotStrings? strings,
    bool enableKeyboardShortcut = true,
    ValueChanged<ScreenshotResult>? onCaptureResult,
    ValueChanged<ScreenshotResult>? onShareResult,
  }) {
    final config = ScreenshotConfig();

    return DualButtonScreenshotWrapper(
      mostrarBotoes: showButtons ?? config.shouldShowButtons,
      posicaoBotoes: buttonPosition ?? Alignment.bottomRight,
      corCapturarBotao: captureButtonColor,
      corEnviarBotao: shareButtonColor,
      shareMode: overrideShareMode ?? config.shareMode,
      strings: strings ?? config.strings,
      enableKeyboardShortcut: enableKeyboardShortcut,
      onCaptureResult: onCaptureResult,
      onShareResult: onShareResult,
      child: child,
    );
  }

  /// Captures the subtree behind [repaintKey] and stores it for later.
  ///
  /// Returns [ScreenshotBusy] when a capture is already running, or a
  /// [ScreenshotFailure] with [ScreenshotErrorKind.bufferFull] when storing
  /// another capture would exceed `maxStoredCaptures` / `maxTotalBytes`.
  Future<ScreenshotResult> captureScreen(
    GlobalKey repaintKey, {
    required double pixelRatio,
    String? customName,
    int? quality,
    List<ScreenSize>? customSizes,
    ValueChanged<ScreenshotResult>? onResult,
  }) async {
    final result = await _captureLock.runIfFree(() async {
      final config = ScreenshotConfig();
      final strings = config.strings;

      try {
        _assertBufferHasRoom(config, strings);

        final screenshots = await _pipeline.captureVariants(
          repaintKey: repaintKey,
          pixelRatio: pixelRatio,
          customName: customName,
          quality: quality,
          customSizes: customSizes,
        );

        final addedBytes = screenshots.fold<int>(
          0,
          (sum, shot) => sum + shot.sizeInBytes,
        );

        if (storedBytes.value + addedBytes > config.maxTotalBytes) {
          // Roll the capture back rather than exceeding the configured cap.
          await StorageService().deleteScreenshotFiles(screenshots);
          throw CaptureBufferFullException(
            strings.bufferFullFor(
              _captureGroups.length,
              storedBytes.value + addedBytes,
            ),
            storedCaptures: _captureGroups.length,
            storedBytes: storedBytes.value,
          );
        }

        _captureGroups[screenshots.first.group] = screenshots;
        _refreshCounters();

        debugPrint('📸 ${screenshots.length} variantes armazenadas. '
            'Total: ${storedCount.value} em ${_captureGroups.length} grupos '
            '(${(storedBytes.value / (1024 * 1024)).toStringAsFixed(1)} MB)');

        return ScreenshotSuccess(count: screenshots.length);
      } catch (error, stackTrace) {
        debugPrint('❌ captureScreen falhou: $error');
        return CapturePipeline.describeError(
          error,
          stackTrace,
          fallbackMessage: strings.captureError,
        );
      }
    });

    final outcome = result ?? const ScreenshotBusy();
    onResult?.call(outcome);
    return outcome;
  }

  /// Zips every pending capture and delivers it to the chosen destination.
  ///
  /// Pending captures are cleared — and their files deleted — only after a
  /// successful hand-off, so a failure never loses work.
  Future<ScreenshotResult> processScreenshots({
    ShareMode? overrideMode,
    bool clearAfterProcessing = true,
    ShareModePicker? modePicker,
    ValueChanged<ScreenshotResult>? onResult,
  }) async {
    final result = await _shareLock.runIfFree(() async {
      final config = ScreenshotConfig();
      final strings = config.strings;

      final pending = _allScreenshots;
      if (pending.isEmpty) {
        return ScreenshotFailure(
          kind: ScreenshotErrorKind.noData,
          message: strings.noScreenshots,
        );
      }

      try {
        final dispatchResult = await _pipeline.dispatchArchive(
          screenshots: pending,
          archiveName: '${config.fileNamePrefix}_bundle',
          mode: overrideMode ?? config.shareMode,
          strings: strings,
          modePicker: modePicker,
        );

        if (dispatchResult.isSuccess && clearAfterProcessing) {
          await StorageService().deleteScreenshotFiles(pending);
          _captureGroups.clear();
          _refreshCounters();
          debugPrint('🧹 Capturas limpas após o compartilhamento');
        }

        return dispatchResult;
      } catch (error, stackTrace) {
        debugPrint('❌ processScreenshots falhou: $error');
        return CapturePipeline.describeError(
          error,
          stackTrace,
          fallbackMessage: strings.shareError,
        );
      }
    });

    final outcome = result ?? const ScreenshotBusy();
    onResult?.call(outcome);
    return outcome;
  }

  /// Discards every pending capture and deletes its files from the cache.
  Future<void> clearScreenshots() async {
    final pending = _allScreenshots;
    _captureGroups.clear();
    _refreshCounters();
    await StorageService().deleteScreenshotFiles(pending);
    debugPrint('🧹 Todas as capturas foram descartadas');
  }

  /// Every pending variant, in capture order.
  List<ScreenshotData> getAllScreenshots() => _allScreenshots;

  /// Variants belonging to [groupId].
  List<ScreenshotData> getScreenshotsForGroup(String groupId) =>
      List.unmodifiable(_captureGroups[groupId] ?? const []);

  /// Ids of every pending capture group, in capture order.
  List<String> getAllGroupIds() => List.unmodifiable(_captureGroups.keys);

  void _assertBufferHasRoom(
    ScreenshotConfig config,
    ScreenshotStrings strings,
  ) {
    if (_captureGroups.length >= config.maxStoredCaptures) {
      throw CaptureBufferFullException(
        strings.bufferFullFor(_captureGroups.length, storedBytes.value),
        storedCaptures: _captureGroups.length,
        storedBytes: storedBytes.value,
      );
    }
    if (storedBytes.value >= config.maxTotalBytes) {
      throw CaptureBufferFullException(
        strings.bufferFullFor(_captureGroups.length, storedBytes.value),
        storedCaptures: _captureGroups.length,
        storedBytes: storedBytes.value,
      );
    }
  }

  void _refreshCounters() {
    var count = 0;
    var bytes = 0;
    for (final group in _captureGroups.values) {
      count += group.length;
      for (final shot in group) {
        bytes += shot.sizeInBytes;
      }
    }
    storedCount.value = count;
    storedBytes.value = bytes;
  }

  /// Releases the notifiers. Only useful in tests: the service is a
  /// process-lifetime singleton in normal use.
  @visibleForTesting
  void disposeNotifiers() {
    storedCount.dispose();
    storedBytes.dispose();
  }
}
