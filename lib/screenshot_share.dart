/// A Flutter package for capturing screenshots and sharing them as a single
/// ZIP archive, either saved to the device or handed to the native share
/// sheet.
library;

// Configuration
export 'src/config/screenshot_config.dart';
export 'src/config/screenshot_strings.dart';

// Enums
export 'src/enums/device_type.dart';
export 'src/enums/resize_strategy.dart';
export 'src/enums/share_mode.dart';

// Errors
export 'src/exceptions/screenshot_exceptions.dart';

// Models
export 'src/models/screen_size.dart';
export 'src/models/screenshot_data.dart';
export 'src/models/screenshot_result.dart';

// Services
export 'src/services/capture_pipeline.dart' show ShareModePicker;
export 'src/services/screenshot_manager_service.dart';
export 'src/services/screenshot_service.dart';
export 'src/services/storage_service.dart' show ShareOutcome, StorageService;

// Widgets
export 'src/widgets/dual_button_wrapper.dart';
export 'src/widgets/screenshot_wrapper.dart';
export 'src/widgets/share_mode_sheet.dart';
