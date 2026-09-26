import 'package:flutter_test/flutter_test.dart';
import 'package:ytdownloader/services/update_service.dart';

void main() {
  group('UpdateService semver tests', () {
    test('isNewerVersion accurately detects higher major version', () {
      expect(UpdateService.isNewerVersion('2.0.0', '1.0.2'), isTrue);
    });

    test('isNewerVersion accurately detects higher minor version', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.2'), isTrue);
    });

    test('isNewerVersion accurately detects higher patch version', () {
      expect(UpdateService.isNewerVersion('1.0.3', '1.0.2'), isTrue);
    });

    test('isNewerVersion returns false for same or older versions', () {
      expect(UpdateService.isNewerVersion('1.0.2', '1.0.2'), isFalse);
      expect(UpdateService.isNewerVersion('1.0.1', '1.0.2'), isFalse);
      expect(UpdateService.isNewerVersion('0.9.9', '1.0.2'), isFalse);
    });
  });
}
