import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/liquid_glass_card.dart';
import '../../services/player_service.dart';
import '../../services/storage_service.dart';
import '../player/full_player_sheet.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<FileSystemEntity> _allFiles = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _isLoading = true);
    final files = <FileSystemEntity>[];
    try {
      final videoDir = await StorageService.getDownloadDirectory(isAudio: false);
      final audioDir = await StorageService.getDownloadDirectory(isAudio: true);

      if (await videoDir.exists()) {
        files.addAll(videoDir.listSync().whereType<File>());
      }
      if (await audioDir.exists()) {
        files.addAll(audioDir.listSync().whereType<File>());
      }

      files.sort((a, b) {
        final aTime = a.statSync().modified;
        final bTime = b.statSync().modified;
        return bTime.compareTo(aTime);
      });
    } catch (_) {}

    if (mounted) {
      setState(() {
        _allFiles = files;
        _isLoading = false;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _openFileExternal(File file) {
    OpenFilex.open(file.path);
  }

  void _shareFile(File file) {
    Share.shareXFiles([XFile(file.path)]);
  }

  Future<void> _deleteFile(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Xác nhận xóa', style: AppTypography.titleSmall),
        content: Text(
          'Bạn có chắc chắn muốn xóa file này khỏi thiết bị?',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final player = ref.read(playerServiceProvider);
        if (player.currentTrack?.filePath == file.path) {
          await player.stop();
        }
        await file.delete();
        _loadFiles();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã xóa file thành công!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (_) {}
    }
  }

  void _playFileInBackground(List<File> fileList, int index) {
    final playerService = ref.read(playerServiceProvider);
    playerService.playQueue(fileList, initialIndex: index);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.headphones, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Đang phát ở chế độ nền...'),
          ],
        ),
        backgroundColor: AppColors.surface,
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Xem',
          textColor: AppColors.secondary,
          onPressed: () => FullPlayerSheet.show(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _allFiles.where((f) {
      final name = f.path.split(Platform.pathSeparator).last.toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final videoFiles = filtered.where((f) => f.path.endsWith('.mp4')).toList();
    final audioFiles = filtered.where((f) => f.path.endsWith('.mp3') || f.path.endsWith('.m4a')).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Thư Viện Đã Tải (${_allFiles.length})', style: AppTypography.titleMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _loadFiles,
            tooltip: 'Làm mới danh sách',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(105),
          child: Column(
            children: [
              // Search input
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: TextField(
                    style: AppTypography.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm file đã tải...',
                      hintStyle: AppTypography.bodySmall,
                      prefixIcon: const Icon(Icons.search, color: Colors.white38, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Tab bar
              TabBar(
                controller: _tabController,
                indicatorColor: AppColors.primary,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textMuted,
                labelStyle: AppTypography.titleSmall.copyWith(fontSize: 13),
                tabs: [
                  Tab(text: 'Tất cả (${filtered.length})'),
                  Tab(text: 'Video (${videoFiles.length})'),
                  Tab(text: 'Nhạc (${audioFiles.length})'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFileList(filtered),
                _buildFileList(videoFiles),
                _buildFileList(audioFiles),
              ],
            ),
    );
  }

  Widget _buildFileList(List<FileSystemEntity> list) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_rounded, color: Colors.white24, size: 48),
            ),
            const SizedBox(height: 14),
            Text('Chưa có file nào', style: AppTypography.titleSmall),
            const SizedBox(height: 4),
            Text('Các video/audio tải xong sẽ xuất hiện ở đây', style: AppTypography.bodySmall),
          ],
        ),
      );
    }

    final typedFiles = list.whereType<File>().toList();
    final playerService = ref.watch(playerServiceProvider);

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: typedFiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entity = typedFiles[index];
        final fileName = entity.path.split(Platform.pathSeparator).last;
        final isAudio = fileName.endsWith('.mp3') || fileName.endsWith('.m4a');
        final stat = entity.statSync();
        final sizeStr = _formatBytes(stat.size);
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(stat.modified);

        final isCurrentPlaying = playerService.currentTrack?.filePath == entity.path;

        return LiquidGlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 14,
          onTap: () => _playFileInBackground(typedFiles, index),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isCurrentPlaying
                      ? AppColors.primary.withOpacity(0.25)
                      : (isAudio
                          ? AppColors.secondary.withOpacity(0.15)
                          : AppColors.primary.withOpacity(0.15)),
                  borderRadius: BorderRadius.circular(10),
                  border: isCurrentPlaying
                      ? Border.all(color: AppColors.primary, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: isCurrentPlaying && playerService.isPlaying
                      ? const Icon(Icons.equalizer_rounded, color: AppColors.primary, size: 24)
                      : Icon(
                          isAudio ? Icons.audiotrack_rounded : Icons.movie_rounded,
                          color: isAudio ? AppColors.secondary : AppColors.primary,
                          size: 22,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        fontSize: 13,
                        color: isCurrentPlaying ? AppColors.primary : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$sizeStr • $dateStr',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isCurrentPlaying && playerService.isPlaying
                      ? Icons.pause_circle_outline_rounded
                      : Icons.play_circle_outline_rounded,
                  color: isCurrentPlaying ? AppColors.primary : Colors.white70,
                  size: 24,
                ),
                tooltip: 'Phát trong nền',
                onPressed: () {
                  if (isCurrentPlaying) {
                    playerService.togglePlay();
                  } else {
                    _playFileInBackground(typedFiles, index);
                  }
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white54, size: 20),
                color: AppColors.surface,
                onSelected: (val) {
                  if (val == 'open_external') {
                    _openFileExternal(entity);
                  } else if (val == 'share') {
                    _shareFile(entity);
                  } else if (val == 'delete') {
                    _deleteFile(entity);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'open_external',
                    child: Row(
                      children: [
                        Icon(Icons.open_in_new, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Mở bằng app ngoài', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share_outlined, color: Colors.white70, size: 18),
                        SizedBox(width: 8),
                        Text('Chia sẻ file', style: TextStyle(color: Colors.white, fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, color: AppColors.error, size: 18),
                        SizedBox(width: 8),
                        Text('Xóa file', style: TextStyle(color: AppColors.error, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
