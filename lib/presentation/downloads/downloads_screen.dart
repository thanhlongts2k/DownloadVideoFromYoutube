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
    final visibleTasks = tasks.where((t) => !t.isCompleted).toList();
    final activeCount = visibleTasks.where((t) => t.isActive).length;
    final hasInactive = visibleTasks.any((t) => t.isFailedOrCanceled);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Đang Tải Xuống ($activeCount)',
          style: AppTypography.titleMedium,
        ),
        actions: [
          if (hasInactive)
            IconButton(
              icon: const Icon(Icons.cleaning_services_outlined, color: Colors.white70),
              tooltip: 'Dọn dẹp tác vụ đã dừng',
              onPressed: () {
                ref.read(downloadManagerProvider.notifier).clearInactiveTasks();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã dọn dẹp các tác vụ đã hủy/lỗi'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
        ],
      ),
      body: visibleTasks.isEmpty
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
              itemCount: visibleTasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final task = visibleTasks[index];

                Color progressBarColor = AppColors.primary;
                if (task.isFailed) {
                  progressBarColor = Colors.redAccent;
                } else if (task.isCanceled) {
                  progressBarColor = Colors.white24;
                }

                Color statusTextColor = AppColors.secondary;
                if (task.isFailed) {
                  statusTextColor = Colors.redAccent;
                } else if (task.isCanceled) {
                  statusTextColor = Colors.white54;
                }

                return Dismissible(
                  key: Key(task.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  ),
                  onDismissed: (_) {
                    ref.read(downloadManagerProvider.notifier).removeTask(task.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đã xóa "${task.title}" khỏi danh sách'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  child: LiquidGlassCard(
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

                            // Action buttons: Cancel if active, Retry + Close if failed/canceled
                            if (task.isActive)
                              IconButton(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.white38),
                                tooltip: 'Hủy tải',
                                onPressed: () {
                                  ref.read(downloadManagerProvider.notifier).cancelDownload(task.id);
                                },
                              )
                            else
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (task.metadata != null && task.format != null)
                                    IconButton(
                                      icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                                      tooltip: 'Thử lại',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        ref.read(downloadManagerProvider.notifier).retryDownload(task);
                                      },
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                                    tooltip: 'Xóa khỏi danh sách',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      ref.read(downloadManagerProvider.notifier).removeTask(task.id);
                                    },
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: task.isCanceled ? 0.0 : task.progress,
                            backgroundColor: Colors.white12,
                            valueColor: AlwaysStoppedAnimation<Color>(progressBarColor),
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
                                      color: statusTextColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  task.progressPercentage,
                                  style: AppTypography.badgeText.copyWith(
                                    color: task.isFailedOrCanceled ? statusTextColor : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
