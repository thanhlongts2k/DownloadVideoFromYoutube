import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/video_metadata.dart';
import '../models/download_format.dart';
import '../core/utils/url_cleaner.dart';

class YoutubeDirectService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<VideoMetadata?> fetchMetadata(String url) async {
    try {
      final videoId = UrlCleaner.extractVideoId(url);
      if (videoId == null) return null;

      final video = await _yt.videos.get(videoId);
      return VideoMetadata(
        id: video.id.value,
        title: video.title,
        author: video.author,
        channelUrl: video.channelId.value,
        thumbnailUrl: video.thumbnails.highResUrl.isNotEmpty
            ? video.thumbnails.highResUrl
            : video.thumbnails.mediumResUrl,
        duration: video.duration ?? Duration.zero,
        viewCount: video.engagement.viewCount,
        uploadDate: video.uploadDate,
        originalUrl: url,
      );
    } catch (e) {
      return null;
    }
  }

  Future<List<DownloadFormat>> fetchFormats(String url) async {
    final formats = <DownloadFormat>[];
    try {
      final videoId = UrlCleaner.extractVideoId(url);
      if (videoId == null) return formats;

      final manifest = await _yt.videos.streamsClient.getManifest(videoId);

      // Best MP4 audio stream (itag 140 / AAC) for muxing with video
      final audioStreams = manifest.audioOnly.sortByBitrate();
      final mp4Audios =
          audioStreams.where((a) => a.container.name == 'mp4').toList();
      final bestAudioStream = mp4Audios.isNotEmpty
          ? mp4Audios.first
          : (audioStreams.isNotEmpty ? audioStreams.first : null);
      final bestAudioUrl = bestAudioStream?.url.toString();
      final bestAudioSize = bestAudioStream?.size.totalBytes ?? 0;
      final bestAudioTag = bestAudioStream?.tag;

      // 1. Video Streams (Muxed & Video-only)
      final seenResolutions = <int>{};

      // Muxed streams (Video + Audio sẵn có trên YouTube, ví dụ 360p hoặc 720p)
      for (final s in manifest.muxed.sortByVideoQuality()) {
        final height = s.videoResolution.height;
        if (!seenResolutions.contains(height)) {
          seenResolutions.add(height);
          String badge = '⚡ Siêu Tốc';
          if (height >= 1080) {
            badge = '⚡ Full HD';
          } else if (height >= 720) {
            badge = '⚡ HD Siêu Tốc';
          }

          formats.add(DownloadFormat(
            formatId: s.tag.toString(),
            resolution: '${height}p',
            resLabel: '${height}p (⚡ Tải Siêu Tốc - Có Sẵn Âm Thanh)',
            ext: 'mp4',
            qualityBadge: badge,
            filesize: s.size.totalBytes,
            fps: s.framerate.framesPerSecond.round(),
            type: FormatType.video,
            directStreamUrl: s.url.toString(),
            audioStreamUrl: null,
            videoId: videoId,
            videoTag: s.tag,
            audioTag: null,
          ));
        }
      }

      // Video only streams (1080p, 1440p, 2160p, 720p...) - Cần ghép với audio MP4
      final allVideoOnly = manifest.videoOnly.sortByVideoQuality();
      final mp4VideoOnly =
          allVideoOnly.where((s) => s.container.name == 'mp4').toList();
      final candidateVideos =
          mp4VideoOnly.isNotEmpty ? mp4VideoOnly : allVideoOnly;

      for (final s in candidateVideos) {
        final height = s.videoResolution.height;
        if (!seenResolutions.contains(height)) {
          seenResolutions.add(height);
          String badge = '';
          if (height >= 2160) {
            badge = '4K Ultra HD';
          } else if (height >= 1440) {
            badge = '2K QHD';
          } else if (height >= 1080) {
            badge = 'Full HD';
          } else if (height >= 720) {
            badge = 'HD';
          }

          formats.add(DownloadFormat(
            formatId: s.tag.toString(),
            resolution: '${height}p',
            resLabel: '${height}p (Kèm Âm thanh)',
            qualityBadge: badge,
            ext: 'mp4',
            filesize: s.size.totalBytes + bestAudioSize,
            fps: s.framerate.framesPerSecond.round(),
            type: FormatType.video,
            directStreamUrl: s.url.toString(),
            audioStreamUrl: bestAudioUrl,
            audioFilesize: bestAudioSize,
            videoId: videoId,
            videoTag: s.tag,
            audioTag: bestAudioTag,
          ));
        }
      }

      // 2. Audio Streams
      if (audioStreams.isNotEmpty) {
        final bestAudio = audioStreams.first;
        final m4aAudio = mp4Audios.isNotEmpty ? mp4Audios.first : bestAudio;

        // HQ MP3
        formats.add(DownloadFormat(
          formatId: bestAudio.tag.toString(),
          resolution: 'Audio (MP3)',
          resLabel: 'Chỉ Âm thanh (Audio MP3 - 192kbps)',
          ext: 'mp3',
          qualityBadge: 'HQ MP3',
          filesize: bestAudio.size.totalBytes,
          type: FormatType.audio,
          directStreamUrl: bestAudio.url.toString(),
          videoId: videoId,
          videoTag: null,
          audioTag: bestAudio.tag,
        ));

        // Fast M4A (nguyên bản AAC từ YouTube)
        formats.add(DownloadFormat(
          formatId: m4aAudio.tag.toString(),
          resolution: 'Audio (M4A)',
          resLabel: 'Âm thanh Gốc YouTube (M4A - Tải Siêu Tốc)',
          ext: 'm4a',
          qualityBadge: 'Fast M4A',
          filesize: m4aAudio.size.totalBytes,
          type: FormatType.audio,
          directStreamUrl: m4aAudio.url.toString(),
          videoId: videoId,
          videoTag: null,
          audioTag: m4aAudio.tag,
        ));
      }

      formats.sort((a, b) {
        if (a.isAudio && !b.isAudio) return 1;
        if (!a.isAudio && b.isAudio) return -1;
        final resA = int.tryParse(a.resolution.replaceAll('p', '')) ?? 0;
        final resB = int.tryParse(b.resolution.replaceAll('p', '')) ?? 0;
        return resB.compareTo(resA);
      });
    } catch (_) {}
    return formats;
  }

  void dispose() {
    _yt.close();
  }
}
