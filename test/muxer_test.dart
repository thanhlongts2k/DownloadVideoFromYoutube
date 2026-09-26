import 'package:flutter_test/flutter_test.dart';
import 'package:ytdownloader/models/download_format.dart';
import 'package:ytdownloader/models/download_task.dart';

void main() {
  group('DownloadFormat Muxing tests', () {
    test('needsMuxing returns true when audioStreamUrl is provided', () {
      final format = DownloadFormat(
        formatId: '137',
        resolution: '1080p',
        resLabel: '1080p (Kèm Âm thanh)',
        ext: 'mp4',
        type: FormatType.video,
        directStreamUrl: 'https://example.com/video.mp4',
        audioStreamUrl: 'https://example.com/audio.m4a',
        audioFilesize: 5000000,
        filesize: 50000000,
      );

      expect(format.needsMuxing, isTrue);
      expect(format.isAudio, isFalse);
      expect(format.filesizeFormatted, '47.7 MB');
    });

    test('needsMuxing returns false for audio only or pre-muxed format', () {
      final audioFormat = DownloadFormat(
        formatId: '140',
        resolution: 'Audio (MP3)',
        resLabel: 'Audio MP3',
        ext: 'mp3',
        type: FormatType.audio,
        directStreamUrl: 'https://example.com/audio.mp3',
      );

      expect(audioFormat.needsMuxing, isFalse);
      expect(audioFormat.isAudio, isTrue);

      final muxedFormat = DownloadFormat(
        formatId: '18',
        resolution: '360p',
        resLabel: '360p',
        ext: 'mp4',
        type: FormatType.video,
        directStreamUrl: 'https://example.com/muxed.mp4',
      );

      expect(muxedFormat.needsMuxing, isFalse);
    });
  });

  group('DownloadTask formatting tests', () {
    test('formats sizes cleanly without raw string escapes', () {
      final task = DownloadTask(
        id: 'test_1',
        videoId: 'video_1',
        title: 'Test Video',
        author: 'Channel',
        thumbnailUrl: '',
        resolution: '1080p',
        ext: 'mp4',
        filePath: '/tmp/test.mp4',
        totalBytes: 25 * 1024 * 1024,
        downloadedBytes: 10 * 1024 * 1024,
      );

      expect(task.downloadedSizeFormatted, '10.0 MB');
      expect(task.totalSizeFormatted, '25.0 MB');
    });
  });
}
