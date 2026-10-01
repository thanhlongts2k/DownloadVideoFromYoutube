import 'package:flutter_test/flutter_test.dart';
import 'package:ytdownloader/models/download_format.dart';
import 'package:ytdownloader/models/download_task.dart';
import 'package:ytdownloader/models/video_metadata.dart';
import 'package:ytdownloader/services/download_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadTask State and Status Tests', () {
    test('TaskStatus and getters work correctly for active and inactive states', () {
      final taskDownloading = DownloadTask(
        id: 't1',
        videoId: 'v1',
        title: 'Video 1',
        author: 'Author',
        thumbnailUrl: '',
        resolution: '1080p',
        ext: 'mp4',
        filePath: '/tmp/v1.mp4',
        totalBytes: 1000,
        status: TaskStatus.downloading,
      );

      expect(taskDownloading.isActive, isTrue);
      expect(taskDownloading.isDownloading, isTrue);
      expect(taskDownloading.isFailedOrCanceled, isFalse);

      final taskCanceled = DownloadTask(
        id: 't2',
        videoId: 'v2',
        title: 'Video 2',
        author: 'Author',
        thumbnailUrl: '',
        resolution: '720p',
        ext: 'mp4',
        filePath: '/tmp/v2.mp4',
        totalBytes: 1000,
        status: TaskStatus.canceled,
      );

      expect(taskCanceled.isCanceled, isTrue);
      expect(taskCanceled.isActive, isFalse);
      expect(taskCanceled.isFailedOrCanceled, isTrue);

      final taskFailed = DownloadTask(
        id: 't3',
        videoId: 'v3',
        title: 'Video 3',
        author: 'Author',
        thumbnailUrl: '',
        resolution: '360p',
        ext: 'mp4',
        filePath: '/tmp/v3.mp4',
        totalBytes: 1000,
        status: TaskStatus.failed,
      );

      expect(taskFailed.isFailed, isTrue);
      expect(taskFailed.isActive, isFalse);
      expect(taskFailed.isFailedOrCanceled, isTrue);
    });

    test('DownloadManagerNotifier manages cancel, remove, and clearInactiveTasks correctly', () {
      final notifier = DownloadManagerNotifier();

      final metadata = VideoMetadata(
        id: 'vid_123',
        title: 'Test Title',
        author: 'Channel',
        channelUrl: '',
        thumbnailUrl: '',
        duration: const Duration(minutes: 3),
        viewCount: 1000,
        originalUrl: 'https://youtube.com/watch?v=vid_123',
      );

      final format = DownloadFormat(
        formatId: '137',
        resolution: '1080p',
        resLabel: '1080p',
        ext: 'mp4',
        type: FormatType.video,
        filesize: 1000,
      );

      final task1 = DownloadTask(
        id: 'task_1',
        videoId: 'vid_123',
        title: 'Task 1',
        author: 'Channel',
        thumbnailUrl: '',
        resolution: '1080p',
        ext: 'mp4',
        filePath: '/tmp/task1.mp4',
        totalBytes: 1000,
        metadata: metadata,
        format: format,
        status: TaskStatus.downloading,
      );

      final task2 = DownloadTask(
        id: 'task_2',
        videoId: 'vid_456',
        title: 'Task 2',
        author: 'Channel',
        thumbnailUrl: '',
        resolution: '720p',
        ext: 'mp4',
        filePath: '/tmp/task2.mp4',
        totalBytes: 2000,
        status: TaskStatus.failed,
      );

      notifier.state = [task1, task2];
      expect(notifier.state.length, 2);

      // Cancel task 1
      notifier.cancelDownload('task_1');
      final canceledTask = notifier.state.firstWhere((t) => t.id == 'task_1');
      expect(canceledTask.status, TaskStatus.canceled);
      expect(canceledTask.speedStr, 'Đã hủy');

      // Clear inactive tasks
      notifier.clearInactiveTasks();
      expect(notifier.state.isEmpty, isTrue);

      // Add back and remove specific task
      notifier.state = [task1, task2];
      notifier.removeTask('task_2');
      expect(notifier.state.length, 1);
      expect(notifier.state.first.id, 'task_1');
    });
  });
}
