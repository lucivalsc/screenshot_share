import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/screenshot_config.dart';

/// Service responsible for interacting with the Telegram Bot API
class TelegramService {
  // Singleton pattern
  static final TelegramService _instance = TelegramService._internal();
  factory TelegramService() => _instance;
  TelegramService._internal();

  /// Send a document (ZIP or Image) to Telegram
  /// Returns a [TelegramSendResult] indicating success or failure details
  Future<TelegramSendResult> sendDocument({
    required Uint8List fileBytes,
    required String filename,
    String? caption,
  }) async {
    try {
      final config = ScreenshotConfig();

      if (!config.isTelegramConfigValid) {
        return TelegramSendResult.error(
          'Configuração inválida: Token ou Chat ID não definidos.',
        );
      }

      debugPrint('📤 Sending document to Telegram: $filename');

      final url =
          'https://api.telegram.org/bot${config.telegramToken}/sendDocument';

      final request = http.MultipartRequest('POST', Uri.parse(url))
        ..fields['chat_id'] = config.telegramChatId
        ..files.add(
          http.MultipartFile.fromBytes(
            'document',
            fileBytes,
            filename: filename,
          ),
        );

      if (caption != null) {
        request.fields['caption'] = caption;
      }

      final response = await request.send();
      final statusCode = response.statusCode;
      final responseBody = await response.stream.bytesToString();

      debugPrint('📤 Telegram API Response: $statusCode');

      if (statusCode >= 200 && statusCode < 300) {
        return TelegramSendResult.success();
      } else {
        return TelegramSendResult.error(
          'Falha na API ($statusCode): $responseBody',
          statusCode: statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ Error sending to Telegram: $e');
      return TelegramSendResult.error('Erro de conexão ou exceção: $e');
    }
  }
}

/// Result object for Telegram operations
class TelegramSendResult {
  final bool success;
  final String? errorMessage;
  final int? statusCode;

  TelegramSendResult({
    required this.success,
    this.errorMessage,
    this.statusCode,
  });

  factory TelegramSendResult.success() {
    return TelegramSendResult(success: true);
  }

  factory TelegramSendResult.error(String message, {int? statusCode}) {
    return TelegramSendResult(
      success: false,
      errorMessage: message,
      statusCode: statusCode,
    );
  }
}
