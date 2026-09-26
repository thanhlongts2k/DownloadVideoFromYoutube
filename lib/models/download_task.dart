enum TaskStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class DownloadTask {
  final String id;
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String resolution;
  final String ext;
  final String filePath;
  final int totalBytes;
  int downloadedBytes;
  double progress;
  String speedStr;
  TaskStatus status;
  String? errorMessage;
  final DateTime createdAt;
  DateTime? completedAt;

  DownloadTask({
    required this.id,
    required this.videoId,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.resolution,
    required this.ext,
    required this.filePath,
    required this.totalBytes,
    this.downloadedBytes = 0,
    this.progress = 0.0,
    this.speedStr = '',
    this.status = TaskStatus.pending,
    this.errorMessage,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get progressPercentage => '${(progress * 100).toStringAsFixed(1)}%';

  String get downloadedSizeFormatted {
    if (downloadedBytes >= 1024 * 1024 * 1024) {
      return '${(downloadedBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(downloadedBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get totalSizeFormatted {
    if (totalBytes <= 0) return 'Đang tính...';
    if (totalBytes >= 1024 * 1024 * 1024) {
      return '${(totalBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    return '${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isCompleted => status == TaskStatus.completed;
  bool get isDownloading => status == TaskStatus.downloading;
  bool get isFailed => status == TaskStatus.failed;
}
