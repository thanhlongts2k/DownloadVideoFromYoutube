import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

class QualityBadge extends StatelessWidget {
  final String label;
  final bool isAudio;

  const QualityBadge({
    super.key,
    required this.label,
    this.isAudio = false,
  });

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();

    Color bgColor;
    Color textColor = Colors.white;

    if (label.contains('4K')) {
      bgColor = const Color(0xFFD946EF);
    } else if (label.contains('Full HD') || label.contains('2K')) {
      bgColor = const Color(0xFFFF0033);
    } else if (label.contains('HD')) {
      bgColor = const Color(0xFF0284C7);
    } else if (label.contains('HQ MP3')) {
      bgColor = const Color(0xFF00B4D8);
    } else {
      bgColor = const Color(0xFF10B981);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: bgColor.withOpacity(0.6), width: 1),
      ),
      child: Text(
        label,
        style: AppTypography.badgeText.copyWith(color: textColor, fontSize: 10),
      ),
    );
  }
}
