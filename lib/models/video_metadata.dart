class VideoMetadata {
  final String id;
  final String title;
  final String author;
  final String channelUrl;
  final String thumbnailUrl;
  final Duration duration;
  final int viewCount;
  final DateTime? uploadDate;
  final String originalUrl;

  VideoMetadata({
    required this.id,
    required this.title,
    required this.author,
    this.channelUrl = '',
    required this.thumbnailUrl,
    required this.duration,
    this.viewCount = 0,
    this.uploadDate,
    required this.originalUrl,
  });

  String get durationFormatted {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get viewsFormatted {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M lượt xem';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(1)}K lượt xem';
    }
    return '$viewCount lượt xem';
  }
}
