import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/download_format.dart';
import '../models/download_task.dart';
import '../models/video_metadata.dart';
import 'native_muxer.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class DownloadManagerNotifier extends StateNotifier<List<DownloadTask>> {
  DownloadManagerNotifier() : super([]);

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

    // Isolated hidden temporary directory .tmp to prevent partial files from cluttering user library
    final tempDir = Directory('${targetDir.path}/.tmp');
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final safeTaskId = taskId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final videoTempPath = '${tempDir.path}/${safeTaskId}_v.raw';
    final audioTempPath = '${tempDir.path}/${safeTaskId}_a.raw';
    final audioTempMuxPath = '${tempDir.path}/${safeTaskId}_m.raw';
    final muxOutputPath = '${tempDir.path}/${safeTaskId}_out.mp4';

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
    DateTime lastUiTime = DateTime.now();
    DateTime lastNotifTime = DateTime.now();
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
      final hasNativeTags = format.videoId != null &&
          (format.videoTag != null || format.audioTag != null);

      if (hasNativeTags) {
        final yt = YoutubeExplode();
        try {
          final manifest =
              await yt.videos.streamsClient.getManifest(format.videoId!);

          if (format.needsMuxing) {
            // VIDEO ONLY + AUDIO => Ghép bằng Native MediaMuxer siêu tốc
            final videoStreamInfo =
                manifest.streams.firstWhere((s) => s.tag == format.videoTag);
            final audioStreamInfo =
                manifest.streams.firstWhere((s) => s.tag == format.audioTag);

            final vFile = File(videoTempPath);
            final aFile = File(audioTempPath);
            if (await vFile.exists()) await vFile.delete();
            if (await aFile.exists()) await aFile.delete();

            final totalSize =
                videoStreamInfo.size.totalBytes + audioStreamInfo.size.totalBytes;
            _updateTask(taskId, (t) => t.totalBytes = totalSize);

            int videoReceived = 0;
            final vSink = vFile.openWrite();

            // 1. Tải Video stream
            final vStream = yt.videos.streamsClient.get(videoStreamInfo);
            await for (final chunk in vStream) {
              if (_activeCancellations[taskId] == true) {
                await vSink.close();
                throw Exception('Download cancelled');
              }
              vSink.add(chunk);
              videoReceived += chunk.length;

              final now = DateTime.now();
              final elapsedUi = now.difference(lastUiTime).inMilliseconds;
              final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

              if (elapsedUi >= 300) {
                final speed = formatSpeed(videoReceived - lastBytes, now.difference(lastTime).inMilliseconds);
                lastBytes = videoReceived;
                lastTime = now;
                lastUiTime = now;
                final progress = (videoReceived / totalSize).clamp(0.0, 0.95);
                _updateTask(taskId, (t) {
                  t.downloadedBytes = videoReceived;
                  t.progress = progress;
                  if (speed.isNotEmpty) t.speedStr = speed;
                });
              }

              if (elapsedNotif >= 1000) {
                lastNotifTime = now;
                final progress = (videoReceived / totalSize).clamp(0.0, 0.95);
                NotificationService().showDownloadProgress(
                  id: notifId,
                  title: metadata.title,
                  progress: (progress * 100).round(),
                  speedStr: tSpeed(task),
                );
              }
            }
            await vSink.flush();
            await vSink.close();

            // 2. Tải Audio stream
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
              final elapsedUi = now.difference(lastUiTime).inMilliseconds;
              final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

              final currentDownloaded = videoReceived + audioReceived;
              final progress = (currentDownloaded / totalSize).clamp(0.0, 0.98);

              if (elapsedUi >= 300) {
                final speed = formatSpeed(audioReceived - lastBytes, now.difference(lastTime).inMilliseconds);
                lastBytes = audioReceived;
                lastTime = now;
                lastUiTime = now;
                _updateTask(taskId, (t) {
                  t.downloadedBytes = currentDownloaded;
                  t.progress = progress;
                  if (speed.isNotEmpty) t.speedStr = speed;
                });
              }

              if (elapsedNotif >= 1000) {
                lastNotifTime = now;
                NotificationService().showDownloadProgress(
                  id: notifId,
                  title: metadata.title,
                  progress: (progress * 100).round(),
                  speedStr: tSpeed(task),
                );
              }
            }
            await aSink.flush();
            await aSink.close();

            // 3. Ghép Video + Audio thành file MP4 chuẩn hoàn chỉnh bằng Native MediaMuxer siêu tốc
            _updateTask(taskId, (t) => t.speedStr = 'Đang ghép âm thanh...');
            final muxSuccess = await NativeMuxer.mux(
              videoPath: videoTempPath,
              audioPath: audioTempPath,
              outputPath: muxOutputPath,
            );

            final muxFile = File(muxOutputPath);
            if (muxSuccess && await muxFile.exists() && (await muxFile.length() > 0)) {
              final finalFile = File(targetPath);
              if (await finalFile.exists()) await finalFile.delete();
              await muxFile.rename(targetPath);

              // Xóa sạch file tạm trong .tmp/
              try { if (await vFile.exists()) await vFile.delete(); } catch (_) {}
              try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
            } else {
              // Dự phòng: nếu muxing có vấn đề, cứu luồng video thành phẩm
              if (await vFile.exists()) {
                final finalFile = File(targetPath);
                if (await finalFile.exists()) await finalFile.delete();
                await vFile.rename(targetPath);
              }
              try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
              try { if (await muxFile.exists()) await muxFile.delete(); } catch (_) {}
            }
          } else if (format.isAudio) {
            // TẢI ÂM THANH (M4A / MP3):
            // Các luồng adaptive audio độc lập (itag 140/251) của YouTube thường bị áp đặt SABR buffer
            // giới hạn ~1.2MB và trả về 403 Forbidden đối với Range request vượt ngưỡng ở các video dài.
            // Ngược lại, luồng Muxed (itag 18 - 360p) luôn có cờ ratebypass=yes, tải siêu tốc (15MB/s) không bao giờ bị 403.
            // Do đó: Ưu tiên tải luồng Muxed nhỏ nhất (360p) rồi dùng Native Demuxer trích xuất track AAC sạch chỉ mất 0.2s!
            final muxedCandidates = manifest.muxed.sortByVideoQuality();
            final muxedStream =
                muxedCandidates.isNotEmpty ? muxedCandidates.last : null;

            if (muxedStream != null) {
              final mFile = File(audioTempMuxPath);
              if (await mFile.exists()) await mFile.delete();

              final totalExpected = muxedStream.size.totalBytes;
              _updateTask(taskId, (t) => t.totalBytes = totalExpected);

              int received = 0;
              final mSink = mFile.openWrite();
              final stream = yt.videos.streamsClient.get(muxedStream);

              await for (final chunk in stream) {
                if (_activeCancellations[taskId] == true) {
                  await mSink.close();
                  throw Exception('Download cancelled');
                }
                mSink.add(chunk);
                received += chunk.length;

                final now = DateTime.now();
                final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                final elapsedNotif =
                    now.difference(lastNotifTime).inMilliseconds;

                final progress = totalExpected > 0
                    ? (received / totalExpected).clamp(0.0, 0.95)
                    : 0.0;

                if (elapsedUi >= 300) {
                  final speed = formatSpeed(received - lastBytes,
                      now.difference(lastTime).inMilliseconds);
                  lastBytes = received;
                  lastTime = now;
                  lastUiTime = now;
                  _updateTask(taskId, (t) {
                    t.downloadedBytes = received;
                    t.progress = progress;
                    if (speed.isNotEmpty) t.speedStr = speed;
                  });
                }

                if (elapsedNotif >= 1000) {
                  lastNotifTime = now;
                  NotificationService().showDownloadProgress(
                    id: notifId,
                    title: metadata.title,
                    progress: (progress * 100).round(),
                    speedStr: tSpeed(task),
                  );
                }
              }
              await mSink.flush();
              await mSink.close();

              // Trích xuất audio AAC từ file Muxed MP4 bằng Android Native MediaExtractor + MediaMuxer
              _updateTask(taskId, (t) {
                t.progress = 0.98;
                t.speedStr = 'Đang trích xuất âm thanh...';
              });

              final extractSuccess = await NativeMuxer.extractAudio(
                inputPath: audioTempMuxPath,
                outputPath: targetPath,
              );

              final targetFile = File(targetPath);
              if (!extractSuccess ||
                  !await targetFile.exists() ||
                  await targetFile.length() == 0) {
                // Dự phòng: nếu native demuxer gặp trục trặc, giữ lại file tải về
                if (await mFile.exists()) {
                  await mFile.rename(targetPath);
                }
              }

              // Xóa sạch file muxed tạm trong .tmp/
              try {
                if (await mFile.exists()) await mFile.delete();
              } catch (_) {}

              if (await targetFile.exists()) {
                final finalLen = await targetFile.length();
                _updateTask(taskId, (t) {
                  t.totalBytes = finalLen;
                  t.downloadedBytes = finalLen;
                });
              }
            } else {
              // Fallback nếu không có luồng muxed nào (tải trực tiếp từ audio tag)
              final targetTag = format.audioTag ?? format.videoTag!;
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
                final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                final elapsedNotif =
                    now.difference(lastNotifTime).inMilliseconds;

                final progress = totalExpected > 0
                    ? (received / totalExpected).clamp(0.0, 1.0)
                    : 0.0;

                if (elapsedUi >= 300) {
                  final speed = formatSpeed(received - lastBytes,
                      now.difference(lastTime).inMilliseconds);
                  lastBytes = received;
                  lastTime = now;
                  lastUiTime = now;
                  _updateTask(taskId, (t) {
                    t.downloadedBytes = received;
                    t.progress = progress;
                    if (speed.isNotEmpty) t.speedStr = speed;
                  });
                }

                if (elapsedNotif >= 1000) {
                  lastNotifTime = now;
                  NotificationService().showDownloadProgress(
                    id: notifId,
                    title: metadata.title,
                    progress: (progress * 100).round(),
                    speedStr: tSpeed(task),
                  );
                }
              }
              await sink.flush();
              await sink.close();

              if (await targetFile.exists()) {
                final actualLength = await targetFile.length();
                if (actualLength < totalExpected) {
                  throw Exception(
                      'Tệp tải chưa đầy đủ ($actualLength / $totalExpected bytes)');
                }
              }
            }
          } else {
            // SINGLE VIDEO STREAM (Video có sẵn audio, ví dụ 360p hoặc 720p muxed)
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
              final elapsedUi = now.difference(lastUiTime).inMilliseconds;
              final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

              final progress =
                  totalExpected > 0 ? (received / totalExpected).clamp(0.0, 1.0) : 0.0;

              if (elapsedUi >= 300) {
                final speed = formatSpeed(received - lastBytes, now.difference(lastTime).inMilliseconds);
                lastBytes = received;
                lastTime = now;
                lastUiTime = now;
                _updateTask(taskId, (t) {
                  t.downloadedBytes = received;
                  t.progress = progress;
                  if (speed.isNotEmpty) t.speedStr = speed;
                });
              }

              if (elapsedNotif >= 1000) {
                lastNotifTime = now;
                NotificationService().showDownloadProgress(
                  id: notifId,
                  title: metadata.title,
                  progress: (progress * 100).round(),
                  speedStr: tSpeed(task),
                );
              }
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
            final elapsedUi = now.difference(lastUiTime).inMilliseconds;
            final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

            final progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;

            if (elapsedUi >= 300) {
              final speed = formatSpeed(received - lastBytes, now.difference(lastTime).inMilliseconds);
              lastBytes = received;
              lastTime = now;
              lastUiTime = now;
              _updateTask(taskId, (t) {
                t.downloadedBytes = received;
                t.totalBytes = total;
                t.progress = progress;
                if (speed.isNotEmpty) t.speedStr = speed;
              });
            }

            if (elapsedNotif >= 1000) {
              lastNotifTime = now;
              NotificationService().showDownloadProgress(
                id: notifId,
                title: metadata.title,
                progress: (progress * 100).round(),
                speedStr: tSpeed(task),
              );
            }
          },
        );
      }

      _updateTask(taskId, (t) {
        t.status = TaskStatus.completed;
        t.progress = 1.0;
        t.speedStr = '';
      });

      NotificationService().showDownloadComplete(
        id: notifId,
        title: metadata.title,
        filePath: targetPath,
      );
    } catch (e) {
      if (_activeCancellations[taskId] == true) {
        _updateTask(taskId, (t) {
          t.status = TaskStatus.failed;
          t.speedStr = 'Đã hủy';
        });
      } else {
        _updateTask(taskId, (t) {
          t.status = TaskStatus.failed;
          t.speedStr = 'Lỗi tải: ${e.toString().split('\n').first}';
        });
      }

      // Cleanup on error
      try { if (await File(videoTempPath).exists()) await File(videoTempPath).delete(); } catch (_) {}
      try { if (await File(audioTempPath).exists()) await File(audioTempPath).delete(); } catch (_) {}
      try { if (await File(audioTempMuxPath).exists()) await File(audioTempMuxPath).delete(); } catch (_) {}
      try { if (await File(muxOutputPath).exists()) await File(muxOutputPath).delete(); } catch (_) {}
    } finally {
      _cancelTokens.remove(taskId);
      _activeCancellations.remove(taskId);
    }
  }

  void cancelDownload(String taskId) {
    _activeCancellations[taskId] = true;
    _cancelTokens[taskId]?.cancel();
    _updateTask(taskId, (t) {
      t.status = TaskStatus.failed;
      t.speedStr = 'Đã hủy';
    });
  }

  void retryDownload(DownloadTask task) {}

  void removeTask(String taskId) {
    state = state.where((t) => t.id != taskId).toList();
  }

  void _updateTask(String id, void Function(DownloadTask) updater) {
    state = [
      for (final t in state)
        if (t.id == id)
          (() {
            updater(t);
            return t;
          })()
        else
          t,
    ];
  }

  String tSpeed(DownloadTask t) {
    final current = state.firstWhere((item) => item.id == t.id, orElse: () => t);
    return current.speedStr;
  }
}

final downloadManagerProvider =
    StateNotifierProvider<DownloadManagerNotifier, List<DownloadTask>>((ref) {
  return DownloadManagerNotifier();
});
