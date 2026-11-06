import 'package:flutter/foundation.dart';

/// Every user-facing string used by the package.
///
/// Up to version 0.1.4 these were hardcoded and mixed English (widgets) with
/// Portuguese (network layer). Pass a custom instance to
/// [ScreenshotConfig.configure] or to a wrapper to localise or override them.
@immutable
class ScreenshotStrings {
  /// Tooltip and semantic label of the capture button.
  final String captureButtonLabel;

  /// Tooltip and semantic label of the share button.
  final String shareButtonLabel;

  /// Shown after a successful capture in dual-button mode.
  final String captureSuccess;

  /// Shown when a capture fails and no specific message is available.
  final String captureError;

  /// Shown after the archive reaches its destination.
  final String shareSuccess;

  /// Shown when sharing fails and no specific message is available.
  final String shareError;

  /// Shown when the user dismisses the share sheet or the picker.
  final String shareCancelled;

  /// Shown when there is nothing to share.
  final String noScreenshots;

  /// Shown when the capture buffer is full. Supports `{captures}` and
  /// `{megabytes}` placeholders.
  final String bufferFull;

  /// Shown after a local save. Supports a `{path}` placeholder.
  final String savedTo;

  /// Title of the destination picker.
  final String chooseDestination;

  /// Label of the "save locally" option in the picker.
  final String destinationLocalSave;

  /// Label of the "share with apps" option in the picker.
  final String destinationShareWithApps;

  /// Label of the picker's cancel action.
  final String cancel;

  /// Shown when [ShareMode.askUser] is used without an available picker.
  final String pickerUnavailable;

  /// Semantic label of the pending-captures badge. Supports a `{count}`
  /// placeholder.
  final String pendingCaptures;

  /// Subject used when handing the archive to the native share sheet.
  final String shareSubject;

  /// Body text used when handing the archive to the native share sheet.
  /// Supports a `{count}` placeholder.
  final String shareText;

  /// Creates a string table. Prefer [ScreenshotStrings.en] or
  /// [ScreenshotStrings.ptBr] and `copyWith` for partial overrides.
  const ScreenshotStrings({
    required this.captureButtonLabel,
    required this.shareButtonLabel,
    required this.captureSuccess,
    required this.captureError,
    required this.shareSuccess,
    required this.shareError,
    required this.shareCancelled,
    required this.noScreenshots,
    required this.bufferFull,
    required this.savedTo,
    required this.chooseDestination,
    required this.destinationLocalSave,
    required this.destinationShareWithApps,
    required this.cancel,
    required this.pickerUnavailable,
    required this.pendingCaptures,
    required this.shareSubject,
    required this.shareText,
  });

  /// English string table (the package default).
  static const ScreenshotStrings en = ScreenshotStrings(
    captureButtonLabel: 'Capture screen',
    shareButtonLabel: 'Share captures',
    captureSuccess: 'Screen captured',
    captureError: 'Could not capture the screen',
    shareSuccess: 'Captures shared',
    shareError: 'Could not share the captures',
    shareCancelled: 'Sharing cancelled',
    noScreenshots: 'No captures to share yet',
    bufferFull: 'Capture buffer is full ({captures} captures, '
        '{megabytes} MB). Share or clear them first.',
    savedTo: 'Saved to {path}',
    chooseDestination: 'Where should the archive go?',
    destinationLocalSave: 'Save to this device',
    destinationShareWithApps: 'Share with another app',
    cancel: 'Cancel',
    pickerUnavailable:
        'ShareMode.askUser needs a Navigator ancestor or an explicit picker.',
    pendingCaptures: '{count} captures pending',
    shareSubject: 'Screenshots',
    shareText: 'Archive with {count} screenshots',
  );

  /// Brazilian Portuguese string table.
  static const ScreenshotStrings ptBr = ScreenshotStrings(
    captureButtonLabel: 'Capturar tela',
    shareButtonLabel: 'Compartilhar capturas',
    captureSuccess: 'Tela capturada',
    captureError: 'Não foi possível capturar a tela',
    shareSuccess: 'Capturas compartilhadas',
    shareError: 'Não foi possível compartilhar as capturas',
    shareCancelled: 'Compartilhamento cancelado',
    noScreenshots: 'Nenhuma captura para compartilhar',
    bufferFull: 'Limite de capturas atingido ({captures} capturas, '
        '{megabytes} MB). Compartilhe ou limpe antes de continuar.',
    savedTo: 'Salvo em {path}',
    chooseDestination: 'Para onde enviar o arquivo?',
    destinationLocalSave: 'Salvar neste dispositivo',
    destinationShareWithApps: 'Compartilhar com outro app',
    cancel: 'Cancelar',
    pickerUnavailable: 'ShareMode.askUser exige um Navigator ancestral '
        'ou um seletor explícito.',
    pendingCaptures: '{count} capturas pendentes',
    shareSubject: 'Screenshots',
    shareText: 'Arquivo com {count} screenshots',
  );

  /// [bufferFull] with its placeholders resolved.
  String bufferFullFor(int captures, int bytes) => bufferFull
      .replaceAll('{captures}', '$captures')
      .replaceAll('{megabytes}', (bytes / (1024 * 1024)).toStringAsFixed(1));

  /// [savedTo] with its placeholder resolved.
  String savedToFor(String path) => savedTo.replaceAll('{path}', path);

  /// [pendingCaptures] with its placeholder resolved.
  String pendingCapturesFor(int count) =>
      pendingCaptures.replaceAll('{count}', '$count');

  /// [shareText] with its placeholder resolved.
  String shareTextFor(int count) => shareText.replaceAll('{count}', '$count');

  /// Returns a copy with the given fields replaced.
  ScreenshotStrings copyWith({
    String? captureButtonLabel,
    String? shareButtonLabel,
    String? captureSuccess,
    String? captureError,
    String? shareSuccess,
    String? shareError,
    String? shareCancelled,
    String? noScreenshots,
    String? bufferFull,
    String? savedTo,
    String? chooseDestination,
    String? destinationLocalSave,
    String? destinationShareWithApps,
    String? cancel,
    String? pickerUnavailable,
    String? pendingCaptures,
    String? shareSubject,
    String? shareText,
  }) {
    return ScreenshotStrings(
      captureButtonLabel: captureButtonLabel ?? this.captureButtonLabel,
      shareButtonLabel: shareButtonLabel ?? this.shareButtonLabel,
      captureSuccess: captureSuccess ?? this.captureSuccess,
      captureError: captureError ?? this.captureError,
      shareSuccess: shareSuccess ?? this.shareSuccess,
      shareError: shareError ?? this.shareError,
      shareCancelled: shareCancelled ?? this.shareCancelled,
      noScreenshots: noScreenshots ?? this.noScreenshots,
      bufferFull: bufferFull ?? this.bufferFull,
      savedTo: savedTo ?? this.savedTo,
      chooseDestination: chooseDestination ?? this.chooseDestination,
      destinationLocalSave: destinationLocalSave ?? this.destinationLocalSave,
      destinationShareWithApps:
          destinationShareWithApps ?? this.destinationShareWithApps,
      cancel: cancel ?? this.cancel,
      pickerUnavailable: pickerUnavailable ?? this.pickerUnavailable,
      pendingCaptures: pendingCaptures ?? this.pendingCaptures,
      shareSubject: shareSubject ?? this.shareSubject,
      shareText: shareText ?? this.shareText,
    );
  }
}
