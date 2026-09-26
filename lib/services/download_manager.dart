import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/download_task.dart';
import '../models/download_format.dart';
import '../models/video_metadata.dart';
import 'storage_service.dart';
import 'notification_service.dart';
import 'native_muxer.dart';

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

    String formatSpeed(int bytesDelta, int elapsedMs) {
      if (elapsedMs <= 0) return '';
      final speedBytesPerSec = (bytesDelta / (elapsedMs / 1000)).round();
      if (speedBytesPerSec >= 1024 * 1024) {
        return '${(speedBytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
      }
      return '${(speedBytesPerSec / 1024).round()} KB/s';
    }

    try {
      final videoUrl = format.directStreamUrl;
      if (videoUrl == null) throw Exception('Stream URL không khả dụng');

      if (format.needsMuxing) {
        // Cần tải cả Video và Audio rồi ghép (Muxing)
        final videoTempPath = '$targetPath.video.tmp';
        final audioTempPath = '$targetPath.audio.tmp';
        final audioUrl = format.audioStreamUrl!;
        final audioSize = format.audioFilesize ?? 0;
        final totalSize = (format.filesize != null && format.filesize! > 0)
            ? format.filesize!
            : 0;

        int videoReceived = 0;

        // 1. Tải Video stream
        await _dio.download(
          videoUrl,
          videoTempPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            videoReceived = received;
            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds;
            String speed = '';
            if (elapsed >= 500) {
              speed = formatSpeed(received - lastBytes, elapsed);
              lastBytes = received;
              lastTime = now;
            }

            final currentTotal = totalSize > 0 ? totalSize : (total + audioSize);
            final progress = currentTotal > 0
                ? (received / currentTotal).clamp(0.0, 0.95)
                : 0.0;

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

        // 2. Tải Audio stream
        lastBytes = 0;
        lastTime = DateTime.now();
        await _dio.download(
          audioUrl,
          audioTempPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds;
            String speed = '';
            if (elapsed >= 500) {
              speed = formatSpeed(received - lastBytes, elapsed);
              lastBytes = received;
              lastTime = now;
            }

            final currentDownloaded = videoReceived + received;
            final currentTotal = totalSize > 0 ? totalSize : (videoReceived + total);
            final progress = currentTotal > 0
                ? (currentDownloaded / currentTotal).clamp(0.0, 0.98)
                : 0.9;

            _updateTask(taskId, (t) {
              t.downloadedBytes = currentDownloaded;
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

        // 3. Ghép Video + Audio thành file MP4 hoàn chỉnh
        _updateTask(taskId, (t) {
          t.speedStr = 'Đang ghép âm thanh...';
        });

        final muxSuccess = await NativeMuxer.mux(
          videoPath: videoTempPath,
          audioPath: audioTempPath,
          outputPath: targetPath,
        );

        // Dọn dẹp tệp tạm
        final vFile = File(videoTempPath);
        final aFile = File(audioTempPath);
        if (muxSuccess && await File(targetPath).exists()) {
          try { if (await vFile.exists()) await vFile.delete(); } catch (_) {}
          try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
        } else {
          // Fallback: giữ lại file video nếu muxer gặp sự cố
          if (await vFile.exists()) {
            await vFile.rename(targetPath);
          }
          try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
        }
      } else {
        // Tải trực tiếp 1 file (MP3, M4A hoặc Video đã có sẵn audio)
        await _dio.download(
          videoUrl,
          targetPath,
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            final now = DateTime.now();
            final elapsed = now.difference(lastTime).inMilliseconds;
            String speed = '';
            if (elapsed >= 500) {
              speed = formatSpeed(received - lastBytes, elapsed);
              lastBytes = received;
              lastTime = now;
            }

            final effectiveTotal =
                total > 0 ? total : (task.totalBytes > 0 ? task.totalBytes : received);
            final progress = effectiveTotal > 0
                ? (received / effectiveTotal).clamp(0.0, 1.0)
                : 0.0;

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
      }

      _updateTask(taskId, (t) {
        t.status = TaskStatus.completed;
        t.progress = 1.0;
        t.downloadedBytes = t.totalBytes > 0 ? t.totalBytes : t.downloadedBytes;
        t.speedStr = '';
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

  void clearCompleted() {
    state = state.where((t) => !t.isCompleted).toList();
  }

  void _updateTask(String taskId, void Function(DownloadTask) updater) {
    state = [
      for (final t in state)
        if (t.id == taskId) ...[
          t..apply(updater)
        ] else
          t,
    ];
  }

  String tSpeed(DownloadTask t) => t.speedStr.isNotEmpty ? t.speedStr : '';
}

extension on DownloadTask {
  void apply(void Function(DownloadTask) updater) {
    updater(this);
  }
}
