import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/liquid_glass_card.dart';
import '../../core/widgets/quality_badge.dart';

import '../../services/download_manager.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadManagerProvider);
    final activeTasks = tasks.where((t) => !t.isCompleted).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Đang Tải Xuống (${activeTasks.length})', style: AppTypography.titleMedium),
      ),
      body: activeTasks.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_download_outlined,
                      color: Colors.white24,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Không có tiến trình tải nào', style: AppTypography.titleSmall),
                  const SizedBox(height: 6),
                  Text('Các file đang tải sẽ hiển thị tại đây', style: AppTypography.bodySmall),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: activeTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = activeTasks[index];
                return LiquidGlassCard(
                  padding: const EdgeInsets.all(14),
                  borderRadius: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: task.thumbnailUrl,
                              width: 80,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 80,
                                height: 48,
                                color: AppColors.surface,
                                child: const Icon(Icons.video_file, color: Colors.white24),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleSmall.copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    QualityBadge(label: task.resolution),
                                    const SizedBox(width: 6),
                                    Text(
                                      task.ext.toUpperCase(),
                                      style: AppTypography.bodySmall,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.cancel_outlined, color: Colors.white38),
                            onPressed: () {
                              ref.read(downloadManagerProvider.notifier).cancelDownload(task.id);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          backgroundColor: Colors.white12,
                          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                          minHeight: 6,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Status info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${task.downloadedSizeFormatted} / ${task.totalSizeFormatted}',
                            style: AppTypography.bodySmall,
                          ),
                          Row(
                            children: [
                              if (task.speedStr.isNotEmpty) ...[
                                Text(
                                  task.speedStr,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.secondary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                task.progressPercentage,
                                style: AppTypography.badgeText.copyWith(color: AppColors.primary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
