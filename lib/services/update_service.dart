import 'storage_service.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../core/constants/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_typography.dart';
import '../core/widgets/glass_button.dart';

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
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
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

          // Prioritize branded TubeX/YouTubex APK over generic build artifacts
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
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _progress = 0.0;
    });

    try {
      final downloadDir = await StorageService.getDownloadDirectory(isAudio: false);
      final apkPath =
          '${downloadDir.path}/YouTubex_${widget.update.tagName}.apk';
      final file = File(apkPath);
      if (await file.exists()) await file.delete();

      int lastBytes = 0;
      DateTime lastTime = DateTime.now();

      await Dio().download(
        widget.update.apkDownloadUrl,
        apkPath,
        onReceiveProgress: (received, total) {
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
              _progress = total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
            });
          }
        },
      );

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
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Tải thất bại: $e';
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
              Text(
                _errorMessage!,
                style: AppTypography.bodySmall.copyWith(color: Colors.redAccent),
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
                  Text(
                    'Đang tải... ${(_progress * 100).toStringAsFixed(1)}%',
                    style: AppTypography.bodySmall,
                  ),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Để sau',
                      style: AppTypography.bodyMedium.copyWith(color: Colors.white54),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassButton(
                    label: 'Cập nhật ngay',
                    icon: Icons.download_rounded,
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
