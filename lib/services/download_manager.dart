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
  final Map<String, YoutubeExplode> _activeYtClients = {};
  final Map<String, StreamSubscription> _activeSubscriptions = {};
  final Map<String, IOSink> _activeSinks = {};

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
      metadata: metadata,
      format: format,
      speedStr: 'Đang kết nối...',
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
        _activeYtClients[taskId] = yt;
        try {
          final manifest = await yt.videos.streamsClient
              .getManifest(format.videoId!)
              .timeout(const Duration(seconds: 25));

          if (_activeCancellations[taskId] == true) {
            throw Exception('Download cancelled');
          }

          if (format.needsMuxing) {
            final vFile = File(videoTempPath);
            final aFile = File(audioTempPath);
            final mTempFile = File(audioTempMuxPath);
            final muxFile = File(muxOutputPath);

            try {
              // VIDEO ONLY + AUDIO => Ghép bằng Native MediaMuxer siêu tốc
              final videoStreamInfo =
                  manifest.streams.firstWhere((s) => s.tag == format.videoTag);
              final audioStreamInfo =
                  manifest.streams.firstWhere((s) => s.tag == format.audioTag);

              if (await vFile.exists()) await vFile.delete();
              if (await aFile.exists()) await aFile.delete();

              // BYPASS SABR: Kiểm tra luồng Muxed (360p) có cờ ratebypass=yes để trích xuất âm thanh AAC sạch,
              // tránh triệt để lỗi YouTube chặn 403 Forbidden trên luồng audio độc lập (itag 140).
              final muxedCandidates = manifest.muxed.sortByVideoQuality();
              final muxedAudioCandidate =
                  muxedCandidates.isNotEmpty ? muxedCandidates.last : null;

              final audioExpectedSize = muxedAudioCandidate != null
                  ? muxedAudioCandidate.size.totalBytes
                  : audioStreamInfo.size.totalBytes;

              final totalSize =
                  videoStreamInfo.size.totalBytes + audioExpectedSize;
              _updateTask(taskId, (t) => t.totalBytes = totalSize);

              int videoReceived = 0;
              final vSink = vFile.openWrite();
              _activeSinks[taskId] = vSink;

              // 1. Tải Video stream có cơ chế pipe stream & watchdog an toàn
              _updateTask(taskId, (t) => t.speedStr = 'Đang tải video...');
              final vStream = yt.videos.streamsClient.get(videoStreamInfo);
              await _pipeStream(
                stream: vStream,
                sink: vSink,
                taskId: taskId,
                onChunk: (chunkLength) {
                  videoReceived += chunkLength;
                  final now = DateTime.now();
                  final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                  final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

                  if (elapsedUi >= 300) {
                    final speed = formatSpeed(
                        videoReceived - lastBytes, now.difference(lastTime).inMilliseconds);
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
                },
              );

              await vSink.flush();
              await vSink.close();
              _activeSinks.remove(taskId);

              if (_activeCancellations[taskId] == true) {
                throw Exception('Download cancelled');
              }

              // 2. Tải Audio stream bằng cơ chế Smart Bypass chống 403
              lastBytes = 0;
              lastTime = DateTime.now();
              int audioReceived = 0;

              if (muxedAudioCandidate != null) {
                _updateTask(taskId, (t) => t.speedStr = 'Đang tải âm thanh (Bypass)...');
                if (await mTempFile.exists()) await mTempFile.delete();

                final mSink = mTempFile.openWrite();
                _activeSinks[taskId] = mSink;
                final stream = yt.videos.streamsClient.get(muxedAudioCandidate);

                await _pipeStream(
                  stream: stream,
                  sink: mSink,
                  taskId: taskId,
                  onChunk: (chunkLength) {
                    audioReceived += chunkLength;
                    final now = DateTime.now();
                    final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                    final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

                    final currentDownloaded = videoReceived + audioReceived;
                    final progress = (currentDownloaded / totalSize).clamp(0.0, 0.98);

                    if (elapsedUi >= 300) {
                      final speed = formatSpeed(
                          audioReceived - lastBytes, now.difference(lastTime).inMilliseconds);
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
                  },
                );

                await mSink.flush();
                await mSink.close();
                _activeSinks.remove(taskId);

                if (_activeCancellations[taskId] == true) {
                  throw Exception('Download cancelled');
                }

                // Trích xuất audio AAC sạch từ file Muxed MP4 bằng Native MediaExtractor + MediaMuxer (0.2s)
                _updateTask(taskId, (t) {
                  t.progress = 0.98;
                  t.speedStr = 'Đang trích xuất âm thanh...';
                });

                final extractSuccess = await NativeMuxer.extractAudio(
                  inputPath: audioTempMuxPath,
                  outputPath: audioTempPath,
                );

                try {
                  if (await mTempFile.exists()) await mTempFile.delete();
                } catch (_) {}

                if (!extractSuccess || !await File(audioTempPath).exists() || await File(audioTempPath).length() == 0) {
                  throw Exception('Không thể trích xuất luồng âm thanh');
                }
              } else {
                // Fallback nếu không có luồng Muxed: tải trực tiếp từ audioStreamInfo (itag 140)
                _updateTask(taskId, (t) => t.speedStr = 'Đang tải âm thanh trực tiếp...');
                final aSink = aFile.openWrite();
                _activeSinks[taskId] = aSink;

                final aStream = yt.videos.streamsClient.get(audioStreamInfo);
                await _pipeStream(
                  stream: aStream,
                  sink: aSink,
                  taskId: taskId,
                  onChunk: (chunkLength) {
                    audioReceived += chunkLength;
                    final now = DateTime.now();
                    final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                    final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

                    final currentDownloaded = videoReceived + audioReceived;
                    final progress = (currentDownloaded / totalSize).clamp(0.0, 0.98);

                    if (elapsedUi >= 300) {
                      final speed = formatSpeed(
                          audioReceived - lastBytes, now.difference(lastTime).inMilliseconds);
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
                  },
                );

                await aSink.flush();
                await aSink.close();
                _activeSinks.remove(taskId);
              }

              if (_activeCancellations[taskId] == true) {
                throw Exception('Download cancelled');
              }

              // 3. Ghép Video + Audio thành file MP4 chuẩn hoàn chỉnh bằng Native MediaMuxer siêu tốc
              _updateTask(taskId, (t) => t.speedStr = 'Đang ghép âm thanh...');
              final muxSuccess = await NativeMuxer.mux(
                videoPath: videoTempPath,
                audioPath: audioTempPath,
                outputPath: muxOutputPath,
              );

              if (_activeCancellations[taskId] == true) {
                throw Exception('Download cancelled');
              }

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
            } catch (muxError) {
              if (_activeCancellations[taskId] == true) rethrow;

              // SMART AUTO-FALLBACK: Nếu luồng video độ phân giải cao bị YouTube chặn 403 Forbidden (>35MB) hoặc timeout,
              // tự động kích hoạt luồng Muxed chuẩn YouTube (360p/720p có cờ ratebypass=yes) để cứu vãn 100% video hoàn chỉnh có âm thanh!
              final muxedFallbacks = manifest.muxed.sortByVideoQuality();
              if (muxedFallbacks.isNotEmpty) {
                final fallbackStream = muxedFallbacks.first;
                _updateTask(taskId, (t) {
                  t.speedStr = 'Tự động tải bản chuẩn ổn định...';
                  t.progress = 0.05;
                  t.downloadedBytes = 0;
                  t.totalBytes = fallbackStream.size.totalBytes;
                });

                final fFile = File(targetPath);
                if (await fFile.exists()) await fFile.delete();
                final fSink = fFile.openWrite();
                _activeSinks[taskId] = fSink;

                int fallbackReceived = 0;
                lastBytes = 0;
                lastTime = DateTime.now();
                final fStream = yt.videos.streamsClient.get(fallbackStream);

                await _pipeStream(
                  stream: fStream,
                  sink: fSink,
                  taskId: taskId,
                  onChunk: (chunkLength) {
                    fallbackReceived += chunkLength;
                    final now = DateTime.now();
                    final elapsedUi = now.difference(lastUiTime).inMilliseconds;
                    final elapsedNotif = now.difference(lastNotifTime).inMilliseconds;

                    final progress = fallbackStream.size.totalBytes > 0
                        ? (fallbackReceived / fallbackStream.size.totalBytes).clamp(0.0, 0.99)
                        : 0.0;

                    if (elapsedUi >= 300) {
                      final speed = formatSpeed(
                          fallbackReceived - lastBytes, now.difference(lastTime).inMilliseconds);
                      lastBytes = fallbackReceived;
                      lastTime = now;
                      lastUiTime = now;
                      _updateTask(taskId, (t) {
                        t.downloadedBytes = fallbackReceived;
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

                await fSink.flush();
                await fSink.close();
                _activeSinks.remove(taskId);

                try { if (await vFile.exists()) await vFile.delete(); } catch (_) {}
                try { if (await aFile.exists()) await aFile.delete(); } catch (_) {}
                try { if (await mTempFile.exists()) await mTempFile.delete(); } catch (_) {}
                try { if (await muxFile.exists()) await muxFile.delete(); } catch (_) {}
              } else {
                rethrow;
              }
            }
          } else if (format.isAudio) {
            // TẢI ÂM THANH (M4A / MP3):
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
              _activeSinks[taskId] = mSink;
              final stream = yt.videos.streamsClient.get(muxedStream);

              await _pipeStream(
                stream: stream,
                sink: mSink,
                taskId: taskId,
                onChunk: (chunkLength) {
                  received += chunkLength;
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
                },
              );

              await mSink.flush();
              await mSink.close();
              _activeSinks.remove(taskId);

              if (_activeCancellations[taskId] == true) {
                throw Exception('Download cancelled');
              }

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

              final tempFile = File(audioTempPath);
              if (await tempFile.exists()) await tempFile.delete();
              final sink = tempFile.openWrite();
              _activeSinks[taskId] = sink;
              int received = 0;
              final totalExpected = streamInfo.size.totalBytes;
              _updateTask(taskId, (t) => t.totalBytes = totalExpected);

              final stream = yt.videos.streamsClient.get(streamInfo);
              await _pipeStream(
                stream: stream,
                sink: sink,
                taskId: taskId,
                onChunk: (chunkLength) {
                  received += chunkLength;
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
                },
              );

              await sink.flush();
              await sink.close();
              _activeSinks.remove(taskId);

              if (_activeCancellations[taskId] == true) {
                throw Exception('Download cancelled');
              }

              if (await tempFile.exists()) {
                final actualLength = await tempFile.length();
                if (actualLength < totalExpected) {
                  throw Exception(
                      'Tệp tải chưa đầy đủ ($actualLength / $totalExpected bytes)');
                }
                final targetFile = File(targetPath);
                if (await targetFile.exists()) await targetFile.delete();
                await tempFile.rename(targetPath);
              }
            }
          } else {
            // SINGLE VIDEO STREAM (Video có sẵn audio, ví dụ 360p hoặc 720p muxed)
            final targetTag = format.videoTag ?? format.audioTag!;
            final streamInfo =
                manifest.streams.firstWhere((s) => s.tag == targetTag);

            final tempFile = File(videoTempPath);
            if (await tempFile.exists()) await tempFile.delete();
            final sink = tempFile.openWrite();
            _activeSinks[taskId] = sink;
            int received = 0;
            final totalExpected = streamInfo.size.totalBytes;
            _updateTask(taskId, (t) => t.totalBytes = totalExpected);

            final stream = yt.videos.streamsClient.get(streamInfo);
            await _pipeStream(
              stream: stream,
              sink: sink,
              taskId: taskId,
              onChunk: (chunkLength) {
                received += chunkLength;
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
              },
            );

            await sink.flush();
            await sink.close();
            _activeSinks.remove(taskId);

            if (_activeCancellations[taskId] == true) {
              throw Exception('Download cancelled');
            }

            // Xác thực tính toàn vẹn (Integrity check) & đổi tên vào targetPath
            if (await tempFile.exists()) {
              final actualLength = await tempFile.length();
              if (actualLength < totalExpected) {
                throw Exception('Tệp tải chưa đầy đủ ($actualLength / $totalExpected bytes)');
              }
              final targetFile = File(targetPath);
              if (await targetFile.exists()) await targetFile.delete();
              await tempFile.rename(targetPath);
            }
          }
        } finally {
          _activeYtClients.remove(taskId);
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
      final notifId = taskId.hashCode.abs() % 10000;
      NotificationService().cancelNotification(notifId);

      final isCanceled = _activeCancellations[taskId] == true ||
          e.toString().contains('Download cancelled');

      if (isCanceled) {
        _updateTask(taskId, (t) {
          t.status = TaskStatus.canceled;
          t.speedStr = 'Đã hủy';
        });
      } else {
        _updateTask(taskId, (t) {
          t.status = TaskStatus.failed;
          final errStr = e.toString().split('\n').first.replaceAll('Exception: ', '');
          t.errorMessage = errStr;
          t.speedStr = 'Lỗi: $errStr';
        });
      }

      // Cleanup on error
      try { if (await File(videoTempPath).exists()) await File(videoTempPath).delete(); } catch (_) {}
      try { if (await File(audioTempPath).exists()) await File(audioTempPath).delete(); } catch (_) {}
      try { if (await File(audioTempMuxPath).exists()) await File(audioTempMuxPath).delete(); } catch (_) {}
      try { if (await File(muxOutputPath).exists()) await File(muxOutputPath).delete(); } catch (_) {}
    } finally {
      final yt = _activeYtClients.remove(taskId);
      if (yt != null) {
        try { yt.close(); } catch (_) {}
      }
      final sub = _activeSubscriptions.remove(taskId);
      if (sub != null) {
        try { sub.cancel(); } catch (_) {}
      }
      final sink = _activeSinks.remove(taskId);
      if (sink != null) {
        try { sink.close(); } catch (_) {}
      }
      _cancelTokens.remove(taskId);
      _activeCancellations.remove(taskId);
    }
  }

  Future<void> _pipeStream({
    required Stream<List<int>> stream,
    required IOSink sink,
    required String taskId,
    required Function(int chunkLength) onChunk,
  }) async {
    final completer = Completer<void>();
    Timer? watchdogTimer;

    void resetWatchdog() {
      watchdogTimer?.cancel();
      // Watchdog 15 giây: nếu quá 15s không có chunk dữ liệu nào được phát ra (do YouTube bóp/chặn 403)
      watchdogTimer = Timer(const Duration(seconds: 15), () {
        if (!completer.isCompleted) {
          completer.completeError(
            TimeoutException('Quá thời gian chờ mạng YouTube phản hồi (15s)'),
          );
        }
      });
    }

    resetWatchdog();

    StreamSubscription<List<int>>? sub;
    sub = stream.listen(
      (chunk) {
        if (_activeCancellations[taskId] == true) {
          watchdogTimer?.cancel();
          if (!completer.isCompleted) {
            completer.completeError(Exception('Download cancelled'));
          }
          return;
        }
        resetWatchdog();
        sink.add(chunk);
        onChunk(chunk.length);
      },
      onError: (e) {
        watchdogTimer?.cancel();
        if (!completer.isCompleted) completer.completeError(e);
      },
      onDone: () {
        watchdogTimer?.cancel();
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    _activeSubscriptions[taskId] = sub;
    try {
      await completer.future;
    } finally {
      watchdogTimer?.cancel();
      _activeSubscriptions.remove(taskId);
      await sub.cancel();
    }
  }

  void cancelDownload(String taskId) {
    _activeCancellations[taskId] = true;
    _cancelTokens[taskId]?.cancel('User canceled download');

    final sub = _activeSubscriptions.remove(taskId);
    if (sub != null) {
      try { sub.cancel(); } catch (_) {}
    }

    final sink = _activeSinks.remove(taskId);
    if (sink != null) {
      try { sink.close(); } catch (_) {}
    }

    final yt = _activeYtClients.remove(taskId);
    if (yt != null) {
      try { yt.close(); } catch (_) {}
    }

    final notifId = taskId.hashCode.abs() % 10000;
    NotificationService().cancelNotification(notifId);

    _updateTask(taskId, (t) {
      t.status = TaskStatus.canceled;
      t.speedStr = 'Đã hủy';
    });
  }

  void retryDownload(DownloadTask task) {
    if (task.metadata != null && task.format != null) {
      removeTask(task.id);
      startDownload(
        metadata: task.metadata!,
        format: task.format!,
      );
    }
  }

  void removeTask(String taskId) {
    cancelDownload(taskId);
    state = state.where((t) => t.id != taskId).toList();
  }

  void clearInactiveTasks() {
    final inactiveList = state.where((t) => t.isFailedOrCanceled).toList();
    for (final task in inactiveList) {
      cancelDownload(task.id);
    }
    state = state.where((t) => t.isActive).toList();
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
