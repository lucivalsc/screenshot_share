import 'package:flutter_test/flutter_test.dart';
import 'package:screenshot_share_telegram/screenshot_share.dart';

void main() {
  test('ScreenshotConfig configuration test', () {
    ScreenshotConfig.configure(
      telegramToken: 'test_token',
      telegramChatId: 'test_chat_id',
    );
    final config = ScreenshotConfig();
    expect(config.telegramToken, equals('test_token'));
    expect(config.telegramChatId, equals('test_chat_id'));
    expect(config.isTelegramConfigValid, isTrue);
  });
}
