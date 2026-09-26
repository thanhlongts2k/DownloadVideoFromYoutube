import 'package:dio/dio.dart';
import '../models/video_metadata.dart';
import '../models/download_format.dart';
import '../core/utils/url_cleaner.dart';

class ServerApiService {
  String baseUrl;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));

  ServerApiService({this.baseUrl = 'http://10.0.2.2:5000'});

  Future<Map<String, dynamic>?> fetchInfo(String url) async {
    try {
      final cleanUrl = UrlCleaner.cleanUrl(url);
      final response = await _dio.get(
        '$baseUrl/api/info',
        queryParameters: {'url': cleanUrl},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;
        final durationSec = data['duration'] as int? ?? 0;

        final metadata = VideoMetadata(
          id: UrlCleaner.extractVideoId(cleanUrl) ?? 'unknown',
          title: data['title'] ?? 'Video',
          author: data['uploader'] ?? 'YouTube',
          thumbnailUrl: data['thumbnail'] ?? '',
          duration: Duration(seconds: durationSec),
          viewCount: data['view_count'] ?? 0,
          originalUrl: cleanUrl,
        );

        final formatsList = <DownloadFormat>[];
        final rawFormats = data['formats'] as List? ?? [];
        for (final f in rawFormats) {
          final isAudio = f['type'] == 'audio';
          formatsList.add(DownloadFormat(
            formatId: f['format_id']?.toString() ?? '',
            resolution: f['resolution'] ?? '',
            resLabel: f['res_label'] ?? f['resolution'] ?? '',
            ext: f['ext'] ?? (isAudio ? 'mp3' : 'mp4'),
            qualityBadge: f['quality_badge'] ?? '',
            filesize: f['filesize'],
            isApprox: f['is_approx'] ?? false,
            fps: f['fps'],
            type: isAudio ? FormatType.audio : FormatType.video,
            directStreamUrl: '$baseUrl/api/download?url=${Uri.encodeComponent(cleanUrl)}&format_id=${f['format_id']}&type=${f['type']}&ext=${f['ext']}',
          ));
        }

        return {
          'metadata': metadata,
          'formats': formatsList,
        };
      }
    } catch (_) {}
    return null;
  }
}
