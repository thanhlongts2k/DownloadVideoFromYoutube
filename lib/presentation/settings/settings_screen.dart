import '../../services/update_service.dart';
import '../../core/constants/app_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/liquid_glass_card.dart';
import '../../core/widgets/glass_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _serverController = TextEditingController();
  bool _useServerEngine = false;
  bool _autoUpdateEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverController.text =
          prefs.getString('server_url') ?? 'http://192.168.1.100:5000';
      _useServerEngine = prefs.getBool('use_server_engine') ?? false;
      _autoUpdateEnabled = prefs.getBool('auto_update_enabled') ?? true;
    });
  }


  Future<void> _toggleAutoUpdate(bool val) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_update_enabled', val);
    setState(() => _autoUpdateEnabled = val);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('server_url', _serverController.text.trim());
    await prefs.setBool('use_server_engine', _useServerEngine);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu cấu hình thành công!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Cài Đặt', style: AppTypography.titleMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Máy Chủ Xử Lý (Server Mode)', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kết nối tới máy tính chạy server Flask để thực hiện gộp video 1080p và nén MP3 bằng FFmpeg.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: TextField(
                      controller: _serverController,
                      style: AppTypography.bodyMedium,
                      decoration: const InputDecoration(
                        hintText: 'http://192.168.1.x:5000',
                        prefixIcon: Icon(Icons.dns_rounded, color: AppColors.secondary, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bật Server Mode mặc định', style: AppTypography.bodyMedium),
                      Switch(
                        value: _useServerEngine,
                        onChanged: (val) => setState(() => _useServerEngine = val),
                        activeColor: AppColors.secondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  GlassButton(
                    label: 'Lưu Cấu Hình',
                    icon: Icons.save_rounded,
                    isSecondary: true,
                    onPressed: _saveSettings,
                    height: 44,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text('Bản Cập Nhật Ứng Dụng', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.autorenew_rounded, color: AppColors.primary),
                    ),
                    title: Text('Tự động kiểm tra cập nhật', style: AppTypography.titleSmall),
                    subtitle: Text(
                      'Tự động thông báo khi có phiên bản mới lúc khởi động ứng dụng',
                      style: AppTypography.bodySmall,
                    ),
                    value: _autoUpdateEnabled,
                    activeColor: AppColors.primary,
                    onChanged: _toggleAutoUpdate,
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.system_update_rounded, color: AppColors.secondary),
                    ),
                    title: Text('Kiểm tra bản cập nhật ngay', style: AppTypography.titleSmall),
                    subtitle: Text('Phiên bản hiện tại: v${AppConfig.appVersion}', style: AppTypography.bodySmall),
                    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
                    onTap: () => UpdateService.checkAndPromptUpdate(context, silent: false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Text('Thông Tin Ứng Dụng', style: AppTypography.titleSmall),
            const SizedBox(height: 8),
            LiquidGlassCard(
              padding: const EdgeInsets.all(16),
              borderRadius: 16,
              child: Column(
                children: [
                  _buildInfoRow('Tên ứng dụng', 'YouTubex Mobile'),
                  const Divider(color: Colors.white10, height: 20),
                  _buildInfoRow('Phiên bản', 'v${AppConfig.appVersion} (Release)'),
                  const Divider(color: Colors.white10, height: 20),
                  _buildInfoRow('Giao diện', 'Liquid Glass & Dark Neon'),
                  const Divider(color: Colors.white10, height: 20),
                  _buildInfoRow('Nền tảng', 'Flutter 3.24+ / Android SDK 34'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.bodyMedium),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
