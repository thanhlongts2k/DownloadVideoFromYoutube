import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
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
  final Map<String, bool> _activeCancellations = {};

  Future<void> startDownload({
    required VideoMetadata metadata,
    required DownloadFormat format,
  }) async {
    final taskId = '${metadata.id}_${format.resolution}_${format.ext}';

    if (state.any((t) => t.id == taskId && t.isDownloading)) return;

    final targetDir =
        await StorageService.getDownloadDirectory(isAudio: format.isAudio);
    final safeTitle = StorageService.sanitizeFilename(metadata.title);
    final targetPath =
        '${targetDir.path}/${safeTitle}_${format.resolution}.${format.ext}';

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

    state = [task, ...state.where((t) => t.id != taskId)];

    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;
    _activeCancellations[taskId] = false;

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
      // KIỂM TRA CHẾ ĐỘ ENGINE:
      // Nếu có videoId + (videoTag hoặc audioTag) => Sử dụng Engine A siêu tốc qua youtube_explode_dart
      final hasNativeTags = format.videoId != null &&
          (format.videoTag != null || format.audioTag != null);

      if (hasNativeTags) {
        final yt = YoutubeExplode();
        try {
          final manifest =
              await yt.videos.streamsClient.getManifest(format.videoId!);

          if (format.needsMuxing) {
            // VIDEO ONLY + AUDIO => Ghép bằng Native MediaMuxer
            final videoStreamInfo =
                manifest.streams.firstWhere((s) => s.tag == format.videoTag);
            final audioStreamInfo =
                manifest.streams.firstWhere((s) => s.tag == format.audioTag);

            final videoTempPath = '$targetPath.video.tmp';
            final audioTempPath = '$targetPath.audio.tmp';
            final vFile = File(videoTempPath);
            final aFile = File(audioTempPath);

            final totalSize =
                videoStreamInfo.size.totalBytes + audioStreamInfo.size.totalBytes;
            _updateTask(taskId, (t) => t.totalBytes = totalSize);

            int videoReceived = 0;
            final vSink = vFile.openWrite();

            // 1. Tải Video stream siêu tốc
            final vStream = yt.videos.streamsClient.get(videoStreamInfo);
            await for (final chunk in vStream) {
              if (_activeCancellations[taskId] == true) {
                await vSink.close();
                throw Exception('Download cancelled');
              }
              vSink.add(chunk);
              videoReceived += chunk.length;

              final now = DateTime.now();
              final elapsed = now.difference(lastTime).inMilliseconds;
              String speed = '';
              if (elapsed >= 500) {
                speed = formatSpeed(videoReceived - lastBytes, elapsed);
                lastBytes = videoReceived;
                lastTime = now;
              }

              final progress = (videoReceived / totalSize).clamp(0.0, 0.95);
              _updateTask(taskId, (t) {
                t.downloadedBytes = videoReceived;
                t.progress = progress;
                if (speed.isNotEmpty) t.speedStr = speed;
              });

              NotificationService().showDownloadProgress(
                id: notifId,
                title: metadata.title,
                progress: (progress * 100).round(),
                speedStr: tSpeed(task),
              );
            }
            await vSink.flush();
            await vSink.close();

            // 2. Tải Audio stream siêu tốc
            lastBytes = 0;
            lastTime = DateTime.now();
            int audioReceived = 0;
            final aSink = aFile.openWrite();

            final aStream = yt.videos.streamsClient.get(audioStreamInfo);
            await for (final chunk in aStream) {
              if (_activeCancellations[taskId] == true) {
                await aSink.close();
                throw Exception('Download cancelled');
              }
              aSink.add(chunk);
              audioReceived += chunk.length;

              final now = DateTime.now();
              final elapsed = now.difference(lastTime).inMilliseconds;
              String speed = '';
              if (elapsed >= 500) {
                speed = formatSpeed(audioReceived - lastBytes, elapsed);
                lastBytes = audioReceived;
                lastTime = now;
              }

              final currentDownloaded = videoReceived + audioReceived;
              final progress = (currentDownloaded / totalSize).clamp(0.0, 0.98);
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
            }
            await aSink.flush();
            await aSink.close();

            // 3. Ghép Video + Audio thành file MP4 chuẩn hoàn chỉnh
            _updateTask(taskId, (t) => t.speedStr = 'Đang ghép âm thanh...');
            final muxSuccess = await NativeMuxer.mux(
              videoPath: videoTempPath,
              audioPath: audioTempPath,
              outputPath: targetPath,
            );

            if (muxSuccess && await File(targetPath).exists()) {
              try { if (await vFile.exists()) await vFile.delete(); } catch (_) {}
              try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
            } else {
              if (await vFile.exists()) await vFile.rename(targetPath);
              try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
            }
          } else {
            // SINGLE STREAM (Audio MP3/M4A hoặc Video 360p có sẵn audio)
            final targetTag = format.videoTag ?? format.audioTag!;
            final streamInfo =
                manifest.streams.firstWhere((s) => s.tag == targetTag);

            final targetFile = File(targetPath);
            final sink = targetFile.openWrite();
            int received = 0;
            final totalExpected = streamInfo.size.totalBytes;
            _updateTask(taskId, (t) => t.totalBytes = totalExpected);

            final stream = yt.videos.streamsClient.get(streamInfo);
            await for (final chunk in stream) {
              if (_activeCancellations[taskId] == true) {
                await sink.close();
                throw Exception('Download cancelled');
              }
              sink.add(chunk);
              received += chunk.length;

              final now = DateTime.now();
              final elapsed = now.difference(lastTime).inMilliseconds;
              String speed = '';
              if (elapsed >= 500) {
                speed = formatSpeed(received - lastBytes, elapsed);
                lastBytes = received;
                lastTime = now;
              }

              final progress =
                  totalExpected > 0 ? (received / totalExpected).clamp(0.0, 1.0) : 0.0;
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
            }
            await sink.flush();
            await sink.close();

            // Xác thực tính toàn vẹn (Integrity check)
            if (await targetFile.exists()) {
              final actualLength = await targetFile.length();
              if (actualLength < totalExpected) {
                throw Exception('Tệp tải chưa đầy đủ ($actualLength / $totalExpected bytes)');
              }
            }
          }
        } finally {
          yt.close();
        }
      } else {
        // FALLBACK: Engine B (Server Mode qua Flask API)
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
      if (_activeCancellations[taskId] == true || cancelToken.isCancelled) {
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
      _activeCancellations.remove(taskId);
    }
  }

  void cancelDownload(String taskId) {
    _activeCancellations[taskId] = true;
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
