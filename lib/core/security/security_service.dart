import 'package:safe_device/safe_device.dart';
import 'package:logger/logger.dart';

class SecurityService {
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 50,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  Future<bool> isDeviceSecure() async {
    bool isRooted = await SafeDevice.isJailBroken;
    bool isRealDevice = await SafeDevice.isRealDevice;
    bool isDevelopmentMode = await SafeDevice.isDevelopmentModeEnable;

    if (isRooted) {
      _logger.e('Security Alert: Device is rooted/jailbroken');
      return false;
    }

    if (!isRealDevice) {
      _logger.i('Security Info: Running on emulator');
      // We can allow emulators for development, or block them
      // return false;
    }

    if (isDevelopmentMode) {
      _logger.i('Security Info: Development mode is enabled');
    }

    return true;
  }

  void secureLog(String message) {
    // Avoid logging sensitive info in production
    // For now, just a wrapper
    _logger.i(message);
  }

  void secureError(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}
