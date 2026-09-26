enum FormatType { video, audio }

class DownloadFormat {
  final String formatId;
  final String resolution;
  final String resLabel;
  final String ext;
  final String qualityBadge;
  final int? filesize;
  final bool isApprox;
  final int? fps;
  final FormatType type;
  final String? directStreamUrl;
  final String? audioStreamUrl;
  final int? audioFilesize;

  DownloadFormat({
    required this.formatId,
    required this.resolution,
    required this.resLabel,
    required this.ext,
    this.qualityBadge = '',
    this.filesize,
    this.isApprox = false,
    this.fps,
    required this.type,
    this.directStreamUrl,
    this.audioStreamUrl,
    this.audioFilesize,
  });

  String get filesizeFormatted {
    if (filesize == null || filesize! <= 0) return 'N/A';
    final bytes = filesize!;
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get isAudio => type == FormatType.audio;
  bool get needsMuxing => audioStreamUrl != null && audioStreamUrl!.isNotEmpty;
}
