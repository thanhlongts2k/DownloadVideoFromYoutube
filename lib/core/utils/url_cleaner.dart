class UrlCleaner {
  static final RegExp _ytRegex = RegExp(
    r'(?:youtube\.com\/(?:watch\?.*v=|shorts\/)|youtu\.be\/)([\w-]{11})',
    caseSensitive: false,
  );

  static String? extractVideoId(String url) {
    if (url.trim().isEmpty) return null;
    final match = _ytRegex.firstMatch(url.trim());
    return match?.group(1);
  }

  static String cleanUrl(String url) {
    final videoId = extractVideoId(url);
    if (videoId != null) {
      return 'https://www.youtube.com/watch?v=$videoId';
    }
    return url.trim();
  }

  static bool isValidYoutubeUrl(String url) {
    return extractVideoId(url) != null;
  }
}
