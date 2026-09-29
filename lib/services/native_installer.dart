import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

class NativeInstaller {
  static const MethodChannel _channel =
      MethodChannel('com.antigravity.ytdownloader/muxer');

  /// Kiểm tra xem ứng dụng đã được cấp quyền cài đặt APK (REQUEST_INSTALL_PACKAGES) hay chưa
  static Future<bool> canInstallApk() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('canInstallApk');
      return result ?? false;
    } catch (_) {
      return true;
    }
  }

  /// Mở màn hình cài đặt hệ thống để người dùng bật "Cho phép từ nguồn này" (Install Unknown Apps)
  static Future<bool> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result =
          await _channel.invokeMethod<bool>('openInstallPermissionSettings');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Khởi chạy trình cài đặt APK thông qua Android Native FileProvider và ACTION_VIEW
  static Future<bool> installApk(String apkPath) async {
    if (!Platform.isAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('installApk', {
        'apkPath': apkPath,
      });
      if (result == true) return true;
    } catch (_) {}

    // Fallback sang OpenFilex nếu native gặp sự cố
    try {
      final openResult = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      return openResult.type == ResultType.done;
    } catch (_) {
      return false;
    }
  }
}
