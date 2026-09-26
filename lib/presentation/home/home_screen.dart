import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../services/update_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/liquid_glass_card.dart';
import '../../core/widgets/glass_button.dart';
import '../../core/utils/url_cleaner.dart';
import '../../services/youtube_direct_service.dart';
import '../../services/server_api_service.dart';
import 'widgets/format_selector_sheet.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onNavigateToDownloads;
  final bool autoCheckUpdate;

  const HomeScreen({
    super.key,
    required this.onNavigateToDownloads,
    this.autoCheckUpdate = true,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final YoutubeDirectService _directService = YoutubeDirectService();
  final ServerApiService _serverService = ServerApiService();

  bool _isLoading = false;
  bool _useServerEngine = false;

  @override
  void initState() {
    super.initState();
    _checkClipboard();
    if (widget.autoCheckUpdate && !Platform.environment.containsKey('FLUTTER_TEST')) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final prefs = await SharedPreferences.getInstance();
        final autoUpdate = prefs.getBool('auto_update_enabled') ?? true;
        if (autoUpdate && mounted) {
          UpdateService.checkAndPromptUpdate(context, silent: true);
        }
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _directService.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      final text = clipboardData?.text?.trim() ?? '';
      if (UrlCleaner.isValidYoutubeUrl(text)) {
        setState(() {
          _urlController.text = text;
        });
      }
    } catch (_) {}
  }

  Future<void> _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      setState(() {
        _urlController.text = text;
      });
      _analyzeUrl();
    }
  }

  Future<void> _analyzeUrl() async {
    final rawUrl = _urlController.text.trim();
    if (!UrlCleaner.isValidYoutubeUrl(rawUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập link YouTube hợp lệ!'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_useServerEngine) {
        final result = await _serverService.fetchInfo(rawUrl);
        if (result != null && mounted) {
          _showFormatSheet(result['metadata'], result['formats']);
        } else {
          _fallbackToDirect(rawUrl);
        }
      } else {
        final metadata = await _directService.fetchMetadata(rawUrl);
        final formats = await _directService.fetchFormats(rawUrl);

        if (metadata != null && formats.isNotEmpty && mounted) {
          _showFormatSheet(metadata, formats);
        } else {
          throw Exception('Không thể lấy thông tin video');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString().replaceAll("Exception: ", "")}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fallbackToDirect(String rawUrl) async {
    final metadata = await _directService.fetchMetadata(rawUrl);
    final formats = await _directService.fetchFormats(rawUrl);
    if (metadata != null && formats.isNotEmpty && mounted) {
      _showFormatSheet(metadata, formats);
    }
  }

  void _showFormatSheet(dynamic metadata, dynamic formats) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: FormatSelectorSheet(
            metadata: metadata,
            formats: formats,
            onDownloadStarted: widget.onNavigateToDownloads,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppColors.redGradient,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('YouTubex', style: AppTypography.titleLarge),
                          Text('YouTube Media Downloader', style: AppTypography.bodySmall),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SettingsScreen()),
                          );
                        },
                        tooltip: 'Cài đặt',
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _useServerEngine = !_useServerEngine;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _useServerEngine ? AppColors.secondary.withOpacity(0.2) : Colors.white10,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _useServerEngine ? AppColors.secondary : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _useServerEngine ? Icons.cloud_done : Icons.smartphone,
                                color: _useServerEngine ? AppColors.secondary : Colors.white70,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _useServerEngine ? 'Server Mode' : 'Direct Mode',
                                style: AppTypography.badgeText.copyWith(
                                  color: _useServerEngine ? AppColors.secondary : Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // Hero Prompt Card
              LiquidGlassCard(
                padding: const EdgeInsets.all(20),
                borderRadius: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tải Video & Nhạc YouTube', style: AppTypography.titleMedium),
                    const SizedBox(height: 6),
                    Text(
                      'Dán link video, Shorts hoặc nhạc YouTube để tải xuống định dạng Full HD, 4K hoặc MP3 chất lượng cao.',
                      style: AppTypography.bodyMedium,
                    ),
                    const SizedBox(height: 18),

                    // Input field
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.glassBorder),
                      ),
                      child: TextField(
                        controller: _urlController,
                        style: AppTypography.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Dán đường dẫn YouTube tại đây...',
                          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.link, color: AppColors.primary),
                          suffixIcon: _urlController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.white38),
                                  onPressed: () {
                                    setState(() => _urlController.clear());
                                  },
                                )
                              : IconButton(
                                  icon: const Icon(Icons.paste_rounded, color: AppColors.secondary),
                                  onPressed: _pasteFromClipboard,
                                  tooltip: 'Dán link từ bộ nhớ tạm',
                                ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                        onSubmitted: (_) => _analyzeUrl(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: GlassButton(
                            label: 'Lấy Định Dạng Tải',
                            icon: Icons.search_rounded,
                            isLoading: _isLoading,
                            onPressed: _analyzeUrl,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Feature Highlights Grid
              Text('Tính Năng Vượt Trội', style: AppTypography.titleSmall),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      icon: Icons.high_quality_rounded,
                      color: AppColors.primary,
                      title: '1080p & 4K UHD',
                      desc: 'Hình ảnh sắc nét chuẩn nén gốc',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      icon: Icons.audiotrack_rounded,
                      color: AppColors.secondary,
                      title: 'MP3 HQ 192k',
                      desc: 'Tách riêng file nhạc cực chuẩn',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFeatureCard(
                      icon: Icons.offline_bolt_rounded,
                      color: AppColors.success,
                      title: 'Chạy Độc Lập',
                      desc: 'Không bắt buộc máy chủ ngoài',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildFeatureCard(
                      icon: Icons.cleaning_services_rounded,
                      color: AppColors.warning,
                      title: 'Lọc Link Rác',
                      desc: 'Tự bỏ query playlist vô tận',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color color,
    required String title,
    required String desc,
  }) {
    return LiquidGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(title, style: AppTypography.titleSmall.copyWith(fontSize: 14)),
          const SizedBox(height: 4),
          Text(desc, style: AppTypography.bodySmall, maxLines: 2),
        ],
      ),
    );
  }
}
