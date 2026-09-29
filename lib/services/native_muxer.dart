import 'package:flutter/services.dart';

class NativeMuxer {
  static const MethodChannel _channel =
      MethodChannel('com.antigravity.ytdownloader/muxer');

  static Future<bool> mux({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('mux', {
        'videoPath': videoPath,
        'audioPath': audioPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> extractAudio({
    required String inputPath,
    required String outputPath,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('extractAudio', {
        'inputPath': inputPath,
        'outputPath': outputPath,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }
}
