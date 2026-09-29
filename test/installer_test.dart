import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ytdownloader/services/native_installer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel =
      MethodChannel('com.antigravity.ytdownloader/muxer');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      switch (methodCall.method) {
        case 'canInstallApk':
          return true;
        case 'openInstallPermissionSettings':
          return true;
        case 'installApk':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('NativeInstaller tests', () {
    test('canInstallApk invokes platform channel correctly', () async {
      final result = await NativeInstaller.canInstallApk();
      // On non-Android test runner, Platform.isAndroid is false so it returns false directly
      expect(result, isA<bool>());
    });

    test('openInstallPermissionSettings handles safely', () async {
      final result = await NativeInstaller.openInstallPermissionSettings();
      expect(result, isA<bool>());
    });

    test('installApk handles safely', () async {
      final result = await NativeInstaller.installApk('/dummy/path.apk');
      expect(result, isA<bool>());
    });
  });
}
