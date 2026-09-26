import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_task.dart';
import '../models/download_format.dart';
import '../models/video_metadata.dart';
import 'storage_service.dart';
import 'notification_service.dart';

final downloadManagerProvider =
    StateNotifierProvider<DownloadManager, List<DownloadTask>>((ref) {
  return DownloadManager();
});

class DownloadManager extends StateNotifier<List<DownloadTask>> {
  DownloadManager() : super([]);

  final Dio _dio = Dio();
  final Map<String, CancelToken> _cancelTokens = {};

  Future<void> startDownload({
    required VideoMetadata metadata,
    required DownloadFormat format,
  }) async {
    final taskId = '${metadata.id}_${format.resolution}_${format.ext}';

    // Không tải trùng nếu đang chạy
    if (state.any((t) => t.id == taskId && t.isDownloading)) return;

    final targetDir =
        await StorageService.getDownloadDirectory(isAudio: format.isAudio);
    final safeTitle = StorageService.sanitizeFilename(metadata.title);
    final targetPath = '${targetDir.path}/${safeTitle}_${format.resolution}.${format.ext}';

    final task = DownloadTask(
      id: taskId,
      videoId: metadata.id,
      title: metadata.title,
      author: metadata.author,
      thumbnailUrl: metadata.thumbnailUrl,
      resolution: format.resolution,
      ext: format.ext,
      filePath: targetPath,
      totalBytes: format.filesize ?? 0,
      status: TaskStatus.downloading,
    );

    // Cập nhật state
    state = [task, ...state.where((t) => t.id != taskId)];

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    int lastBytes = 0;
    DateTime lastTime = DateTime.now();
    final notifId = taskId.hashCode.abs() % 10000;

    try {
      final downloadUrl = format.directStreamUrl;
      if (downloadUrl == null) throw Exception('Stream URL không khả dụng');

      await _dio.download(
        downloadUrl,
        targetPath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          String speed = '';
          if (elapsed >= 500) {
            final bytesDelta = received - lastBytes;
            final speedBytesPerSec = (bytesDelta / (elapsed / 1000)).round();
            if (speedBytesPerSec >= 1024 * 1024) {
              speed = '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              speed = '${(speedBytesPerSec / 1024).round()} KB/s';
            }
            lastBytes = received;
            lastTime = now;
          }

          final effectiveTotal = total > 0 ? total : (task.totalBytes > 0 ? task.totalBytes : received);
          final progress = effectiveTotal > 0 ? (received / effectiveTotal).clamp(0.0, 1.0) : 0.0;

          _updateTask(taskId, (t) {
            t.downloadedBytes = received;
            t.progress = progress;
            if (speed.isNotEmpty) t.speedStr = speed;
          });

          NotificationService().showDownloadProgress(
            id: notifId,
            title: metadata.title,
            progress: (progress * 100).round(),
            speedStr: tSpeed(task),
          );
        },
      );

      _updateTask(taskId, (t) {
        t.status = TaskStatus.completed;
        t.progress = 1.0;
        t.completedAt = DateTime.now();
      });

      NotificationService().showDownloadComplete(
        id: notifId,
        title: metadata.title,
        filePath: targetPath,
      );
    } catch (e) {
      if (cancelToken.isCancelled) {
        _updateTask(taskId, (t) => t.status = TaskStatus.paused);
      } else {
        _updateTask(taskId, (t) {
          t.status = TaskStatus.failed;
          t.errorMessage = e.toString();
        });
      }
      NotificationService().cancelNotification(notifId);
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  void cancelDownload(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel();
    }
  }

  void deleteTask(String taskId) {
    cancelDownload(taskId);
    state = state.where((t) => t.id != taskId).toList();
  }

  String tSpeed(DownloadTask t) => t.speedStr.isNotEmpty ? t.speedStr : '...';

  void _updateTask(String id, void Function(DownloadTask) updater) {
    state = state.map((t) {
      if (t.id == id) {
        updater(t);
        return t;
      }
      return t;
    }).toList();
  }
}
