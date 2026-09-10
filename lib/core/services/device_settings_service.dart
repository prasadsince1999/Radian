import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Service providing access to Android system permissions and battery
/// optimization exemptions to ensure reliable background routine synchronization.
class DeviceSettingsService {
  static const MethodChannel _channel = MethodChannel(
    'com.ksmxtech.sectograph_mcp/widget',
  );

  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Checks if the app is currently exempt from Android battery optimizations.
  static Future<bool> isBatteryOptimizationIgnored() async {
    if (!isAndroid) return true;
    try {
      final isIgnored = await _channel.invokeMethod<bool>(
        'isBatteryOptimizationIgnored',
      );
      return isIgnored ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the Android system dialog to request exemption from battery optimizations.
  static Future<bool> requestIgnoreBatteryOptimization() async {
    if (!isAndroid) return true;
    try {
      final success = await _channel.invokeMethod<bool>(
        'requestIgnoreBatteryOptimization',
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the application battery/details settings page.
  static Future<bool> openBatterySettings() async {
    if (!isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>('openBatterySettings');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether app notifications are enabled.
  static Future<bool> areNotificationsEnabled() async {
    if (!isAndroid) return true;
    try {
      final enabled = await _channel.invokeMethod<bool>(
        'areNotificationsEnabled',
      );
      return enabled ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Opens the system notification settings for this application.
  static Future<bool> openNotificationSettings() async {
    if (!isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>(
        'openNotificationSettings',
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether Health Connect is supported/available on this device.
  static Future<bool> isHealthConnectAvailable() async {
    if (!isAndroid) return false;
    try {
      final available = await _channel.invokeMethod<bool>(
        'isHealthConnectAvailable',
      );
      return available ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Checks whether Health Connect biometrics permissions have been granted.
  static Future<bool> hasHealthPermissions() async {
    if (!isAndroid) return false;
    try {
      final granted = await _channel.invokeMethod<bool>('hasHealthPermissions');
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Prompts the system Health Connect permissions dialog or screen.
  static Future<bool> requestHealthPermissions() async {
    if (!isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>(
        'requestHealthPermissions',
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Opens the native Android Health Connect permission manager for this application.
  static Future<bool> openHealthConnectSettings() async {
    if (!isAndroid) return false;
    try {
      final success = await _channel.invokeMethod<bool>(
        'openHealthConnectSettings',
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Provider to observe battery optimization exemption status
final batteryOptimizationStatusProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  return await DeviceSettingsService.isBatteryOptimizationIgnored();
});

/// Provider to observe Health Connect biometrics permissions status
final healthPermissionsStatusProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  return await DeviceSettingsService.hasHealthPermissions();
});
