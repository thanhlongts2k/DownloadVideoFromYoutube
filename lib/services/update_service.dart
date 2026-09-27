import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/glass_button.dart';
import 'storage_service.dart';

class UpdateInfo {
  final String tagName;
  final String version;
  final String title;
  final String body;
  final String apkDownloadUrl;
  final int apkSize;

  UpdateInfo({
    required this.tagName,
    required this.version,
    required this.title,
    required this.body,
    required this.apkDownloadUrl,
    required this.apkSize,
  });

  String get sizeFormatted {
    if (apkSize <= 0) return '';
    return '${(apkSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class UpdateService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 25),
    headers: {'User-Agent': 'TubeX-App'},
  ));

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await _dio.get(AppConfig.githubReleasesApi);
      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final tagName = data['tag_name'] as String? ?? '';
        final latestVersion = tagName.replaceAll('v', '').trim();
        final currentVersion = AppConfig.appVersion.trim();

        if (isNewerVersion(latestVersion, currentVersion)) {
          final assets = data['assets'] as List? ?? [];
          String apkUrl = '';
          int apkSize = 0;

          // Prioritize branded TubeX APK over generic assets
          for (final asset in assets) {
            final name = (asset['name'] as String? ?? '').toLowerCase();
            if (name.endsWith('.apk') &&
                (name.contains('tubex') || name.contains('youtubex'))) {
              apkUrl = asset['browser_download_url'] as String? ?? '';
              apkSize = asset['size'] as int? ?? 0;
              break;
            }
          }

          if (apkUrl.isEmpty) {
            for (final asset in assets) {
              final name = asset['name'] as String? ?? '';
              if (name.endsWith('.apk')) {
                apkUrl = asset['browser_download_url'] as String? ?? '';
                apkSize = asset['size'] as int? ?? 0;
                break;
              }
            }
          }

          if (apkUrl.isNotEmpty) {
            return UpdateInfo(
              tagName: tagName,
              version: latestVersion,
              title: data['name'] as String? ?? 'Bản cập nhật mới',
              body: data['body'] as String? ?? '',
              apkDownloadUrl: apkUrl,
              apkSize: apkSize,
            );
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static bool isNewerVersion(String latest, String current) {
    try {
      final lParts = latest.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final cParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (lParts.length < 3) {
        lParts.add(0);
      }
      while (cParts.length < 3) {
        cParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
    } catch (_) {}
    return false;
  }

  static Future<void> checkAndPromptUpdate(
    BuildContext context, {
    bool silent = true,
  }) async {
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đang kiểm tra bản cập nhật từ GitHub...'),
          duration: Duration(seconds: 1),
        ),
      );
    }

    final update = await checkForUpdate();
    if (!context.mounted) return;

    if (update != null) {
      showUpdateDialog(context, update);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bạn đang sử dụng phiên bản mới nhất (${AppConfig.appVersion}) ✨',
          ),
          backgroundColor: AppColors.secondary,
        ),
      );
    }
  }

  static void showUpdateDialog(BuildContext context, UpdateInfo update) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => _UpdateDialog(update: update),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final UpdateInfo update;
  const _UpdateDialog({required this.update});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadSpeed = '';
  String _statusText = '';
  String? _errorMessage;

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.update.apkDownloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể mở trình duyệt: $e')),
        );
      }
    }
  }

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _statusText = 'Đang khởi tạo kết nối...';
      _downloadSpeed = '';
    });

    final downloadDir = await StorageService.getDownloadDirectory(isAudio: false);
    final apkPath = '${downloadDir.path}/TubeX_${widget.update.tagName}.apk';
    final partPath = '$apkPath.part';
    final finalFile = File(apkPath);
    final partFile = File(partPath);

    int totalExpected = widget.update.apkSize;

    // Check if full APK already exists
    if (await finalFile.exists()) {
      final existingSize = await finalFile.length();
      if (totalExpected > 0 && existingSize >= totalExpected) {
        if (mounted) {
          Navigator.of(context).pop();
          await OpenFilex.open(
            apkPath,
            type: 'application/vnd.android.package-archive',
          );
        }
        return;
      }
    }

    const int maxRetries = 5;
    int attempt = 0;
    bool success = false;

    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 25),
      receiveTimeout: const Duration(seconds: 45),
      sendTimeout: const Duration(seconds: 25),
      headers: {'User-Agent': 'TubeX-App'},
    ));

    while (attempt < maxRetries && !success) {
      int currentExisting = 0;
      if (await partFile.exists()) {
        currentExisting = await partFile.length();
      }

      if (totalExpected > 0 && currentExisting >= totalExpected) {
        if (await finalFile.exists()) await finalFile.delete();
        await partFile.rename(apkPath);
        success = true;
        break;
      }

      attempt++;
      IOSink? sink;

      try {
        final Map<String, dynamic> headers = {};
        if (currentExisting > 0) {
          headers['Range'] = 'bytes=$currentExisting-';
          if (mounted) {
            setState(() {
              _statusText =
                  'Nối file từ ${(currentExisting / (1024 * 1024)).toStringAsFixed(1)} MB (Lần $attempt/$maxRetries)...';
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _statusText = attempt > 1
                  ? 'Thử lại lần $attempt/$maxRetries...'
                  : 'Đang kết nối tới máy chủ GitHub...';
            });
          }
        }

        final response = await dio.get<ResponseBody>(
          widget.update.apkDownloadUrl,
          options: Options(
            responseType: ResponseType.stream,
            headers: headers,
            followRedirects: true,
            maxRedirects: 5,
            validateStatus: (status) =>
                status != null && (status == 200 || status == 206 || status == 416),
          ),
        );

        if (response.statusCode == 416) {
          if (await finalFile.exists()) await finalFile.delete();
          await partFile.rename(apkPath);
          success = true;
          break;
        }

        if (response.statusCode == 206) {
          final cr = response.headers.value('content-range');
          if (cr != null && cr.contains('/')) {
            final t = int.tryParse(cr.split('/').last.trim());
            if (t != null && t > 0) totalExpected = t;
          }
          sink = partFile.openWrite(mode: FileMode.append);
        } else {
          currentExisting = 0;
          final cl = response.headers.value('content-length');
          if (cl != null) {
            final t = int.tryParse(cl.trim());
            if (t != null && t > 0) totalExpected = t;
          }
          sink = partFile.openWrite(mode: FileMode.write);
        }

        int received = currentExisting;
        int lastBytes = received;
        DateTime lastTime = DateTime.now();

        await for (final chunk in response.data!.stream) {
          sink.add(chunk);
          received += chunk.length;

          final now = DateTime.now();
          final elapsed = now.difference(lastTime).inMilliseconds;
          if (elapsed >= 500) {
            final delta = received - lastBytes;
            final speedBytes = (delta / (elapsed / 1000)).round();
            if (speedBytes >= 1024 * 1024) {
              _downloadSpeed =
                  '${(speedBytes / (1024 * 1024)).toStringAsFixed(1)} MB/s';
            } else {
              _downloadSpeed = '${(speedBytes / 1024).round()} KB/s';
            }
            lastBytes = received;
            lastTime = now;
          }

          if (mounted) {
            setState(() {
              _progress = totalExpected > 0
                  ? (received / totalExpected).clamp(0.0, 1.0)
                  : 0.0;
              final recMB = (received / (1024 * 1024)).toStringAsFixed(1);
              final totMB = totalExpected > 0
                  ? (totalExpected / (1024 * 1024)).toStringAsFixed(1)
                  : '--';
              _statusText = 'Đang tải: $recMB / $totMB MB';
            });
          }
        }

        await sink.flush();
        await sink.close();
        sink = null;

        final finalDownloaded = await partFile.length();
        if (totalExpected <= 0 || finalDownloaded >= totalExpected) {
          if (await finalFile.exists()) await finalFile.delete();
          await partFile.rename(apkPath);
          success = true;
          break;
        }
      } catch (err) {
        if (sink != null) {
          try {
            await sink.flush();
            await sink.close();
          } catch (_) {}
          sink = null;
        }

        if (await partFile.exists()) {
          final len = await partFile.length();
          if (totalExpected > 0 && len >= totalExpected) {
            if (await finalFile.exists()) await finalFile.delete();
            await partFile.rename(apkPath);
            success = true;
            break;
          }
        }

        if (attempt < maxRetries) {
          if (mounted) {
            setState(() {
              _statusText =
                  'Mạng chập chờn, tự động kết nối lại sau 2s (Lần $attempt/$maxRetries)...';
            });
          }
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    if (success) {
      if (mounted) {
        Navigator.of(context).pop();
        final result = await OpenFilex.open(
          apkPath,
          type: 'application/vnd.android.package-archive',
        );
        if (result.type != ResultType.done && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Vui lòng mở file để cài đặt: $apkPath')),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage =
              'Kết nối mạng bị ngắt quãng hoặc máy chủ GitHub CDN đóng kết nối.\nBạn có thể nhấn "Thử lại" để tải tiếp tục, hoặc "Tải bằng trình duyệt".';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF16192E),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cập Nhật Ứng Dụng',
                        style: AppTypography.titleMedium.copyWith(fontSize: 18),
                      ),
                      Text(
                        'Phiên bản mới ${widget.update.tagName} (${widget.update.sizeFormatted})',
                        style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 12),
            Text(
              'Có gì mới:',
              style: AppTypography.titleSmall.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              child: SingleChildScrollView(
                child: Text(
                  widget.update.body.isNotEmpty
                      ? widget.update.body
                      : 'Nâng cấp hiệu năng và sửa các lỗi phát sinh.',
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFFFF8A80),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            if (_isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white10,
                  valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusText.isNotEmpty ? _statusText : 'Đang tải...',
                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_downloadSpeed.isNotEmpty)
                    Text(
                      _downloadSpeed,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ] else ...[
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Để sau',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white54),
                    ),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: BorderSide(color: AppColors.secondary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Trình duyệt'),
                    onPressed: _openInBrowser,
                  ),
                  GlassButton(
                    label: _errorMessage != null ? 'Thử lại' : 'Cập nhật ngay',
                    icon: _errorMessage != null ? Icons.refresh_rounded : Icons.download_rounded,
                    onPressed: _startDownload,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
