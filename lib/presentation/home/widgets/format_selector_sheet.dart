import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../models/video_metadata.dart';
import '../../../models/download_format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/quality_badge.dart';
import '../../../core/widgets/liquid_glass_card.dart';
import '../../../services/download_manager.dart';

class FormatSelectorSheet extends ConsumerStatefulWidget {
  final VideoMetadata metadata;
  final List<DownloadFormat> formats;
  final VoidCallback onDownloadStarted;

  const FormatSelectorSheet({
    super.key,
    required this.metadata,
    required this.formats,
    required this.onDownloadStarted,
  });

  @override
  ConsumerState<FormatSelectorSheet> createState() => _FormatSelectorSheetState();
}

class _FormatSelectorSheetState extends ConsumerState<FormatSelectorSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final videoFormats = widget.formats.where((f) => !f.isAudio).toList();
    final audioFormats = widget.formats.where((f) => f.isAudio).toList();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Video Info Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: widget.metadata.thumbnailUrl,
                        width: 120,
                        height: 72,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(
                          width: 120,
                          height: 72,
                          color: AppColors.surface,
                        ),
                        errorWidget: (_, __, ___) => Container(
                          width: 120,
                          height: 72,
                          color: AppColors.surface,
                          child: const Icon(Icons.broken_image, color: Colors.white38),
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            widget.metadata.durationFormatted,
                            style: AppTypography.badgeText.copyWith(color: Colors.white, fontSize: 9),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.metadata.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleSmall.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.metadata.author} • ${widget.metadata.viewsFormatted}',
                        style: AppTypography.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tabs: Video / Audio
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppColors.redGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTypography.titleSmall.copyWith(fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.movie_outlined, size: 18), text: 'Video (MP4)'),
                Tab(icon: Icon(Icons.music_note_outlined, size: 18), text: 'Âm thanh (MP3 / M4A)'),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Formats List
          Flexible(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFormatList(videoFormats, false),
                _buildFormatList(audioFormats, true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatList(List<DownloadFormat> list, bool isAudio) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Không có định dạng phù hợp',
            style: AppTypography.bodyMedium,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      shrinkWrap: true,
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final format = list[index];
        return LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: 14,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isAudio
                      ? AppColors.secondary.withOpacity(0.15)
                      : AppColors.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  isAudio ? Icons.music_note : Icons.play_arrow_rounded,
                  color: isAudio ? AppColors.secondary : AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          format.resolution,
                          style: AppTypography.titleSmall.copyWith(fontSize: 14),
                        ),
                        if (format.qualityBadge.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          QualityBadge(label: format.qualityBadge, isAudio: isAudio),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '📦 ${format.filesizeFormatted}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          format.ext.toUpperCase(),
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ref.read(downloadManagerProvider.notifier).startDownload(
                        metadata: widget.metadata,
                        format: format,
                      );
                  Navigator.pop(context);
                  widget.onDownloadStarted();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAudio ? AppColors.secondary : AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  isAudio ? 'Tải Nhạc' : 'Tải Về',
                  style: AppTypography.badgeText.copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
