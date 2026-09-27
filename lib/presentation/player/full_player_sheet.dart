import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/player_service.dart';

class FullPlayerSheet extends ConsumerStatefulWidget {
  const FullPlayerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const FullPlayerSheet(),
    );
  }

  @override
  ConsumerState<FullPlayerSheet> createState() => _FullPlayerSheetState();
}

class _FullPlayerSheetState extends ConsumerState<FullPlayerSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _discController;

  @override
  void initState() {
    super.initState();
    _discController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    );
  }

  @override
  void dispose() {
    _discController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _showSpeedPicker(PlayerService playerService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tốc độ phát', style: AppTypography.titleSmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: speeds.map((s) {
                    final isSelected = playerService.speed == s;
                    return ChoiceChip(
                      label: Text('${s}x'),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      onSelected: (val) {
                        if (val) {
                          playerService.setSpeed(s);
                          Navigator.pop(context);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSleepTimerPicker(PlayerService playerService) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hẹn giờ tắt nhạc', style: AppTypography.titleSmall),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.timer_off_outlined, color: Colors.white70),
                  title: const Text('Tắt hẹn giờ', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.cancelSleepTimer();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('15 phút', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.setSleepTimer(const Duration(minutes: 15));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('30 phút', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.setSleepTimer(const Duration(minutes: 30));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('45 phút', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.setSleepTimer(const Duration(minutes: 45));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('60 phút (1 tiếng)', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.setSleepTimer(const Duration(minutes: 60));
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.music_note_outlined, color: AppColors.secondary),
                  title: const Text('Hết bài hát hiện tại', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    playerService.setSleepTimerEndOfTrack();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final playerService = ref.watch(playerServiceProvider);
    final track = playerService.currentTrack;

    if (track == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return const SizedBox.shrink();
    }

    if (playerService.isPlaying) {
      if (!_discController.isAnimating) {
        _discController.repeat();
      }
    } else {
      if (_discController.isAnimating) {
        _discController.stop();
      }
    }

    final pos = playerService.position;
    final dur = playerService.duration;
    final maxSlider = dur.inMilliseconds.toDouble();
    final currentSlider = pos.inMilliseconds.toDouble().clamp(0.0, maxSlider > 0 ? maxSlider : 1.0);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.96),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.12),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle & top bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        track.isVideo ? Icons.videocam : Icons.headphones,
                        color: AppColors.primary,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Phát Trong Nền',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white70),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Animated Rotating Disc Artwork
                  Center(
                    child: AnimatedBuilder(
                      animation: _discController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _discController.value * 2 * math.pi,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const RadialGradient(
                            colors: [
                              Color(0xFF2A2A38),
                              Color(0xFF151520),
                              Color(0xFF0A0A10),
                            ],
                            stops: [0.3, 0.7, 1.0],
                          ),
                          border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.25),
                              blurRadius: 35,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: AppColors.secondary.withOpacity(0.15),
                              blurRadius: 45,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Vinyl grooves
                            Container(
                              width: 190,
                              height: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white10, width: 1.5),
                              ),
                            ),
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12, width: 1.5),
                              ),
                            ),
                            // Center label
                            Container(
                              width: 80,
                              height: 80,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [AppColors.primary, AppColors.secondary],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  track.isVideo ? Icons.movie_filter : Icons.music_note,
                                  color: Colors.white,
                                  size: 34,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Title & Artist info
                  Column(
                    children: [
                      Text(
                        track.title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.titleLarge.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        track.artist,
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),

                  // Progress Scrubber
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 4,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: Colors.white12,
                          thumbColor: Colors.white,
                          overlayColor: AppColors.primary.withOpacity(0.2),
                        ),
                        child: Slider(
                          value: currentSlider,
                          max: maxSlider > 0 ? maxSlider : 1.0,
                          onChanged: (val) {
                            playerService.seek(Duration(milliseconds: val.toInt()));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(pos),
                              style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                            ),
                            Text(
                              _formatDuration(dur),
                              style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Controls: Loop, Prev, Play/Pause, Next, Speed/Timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: Icon(
                          switch (playerService.loopMode) {
                            LoopMode.off => Icons.repeat,
                            LoopMode.all => Icons.repeat,
                            LoopMode.one => Icons.repeat_one,
                          },
                          color: playerService.loopMode == LoopMode.off
                              ? Colors.white38
                              : AppColors.primary,
                        ),
                        onPressed: playerService.toggleLoopMode,
                      ),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.replay_10_rounded, color: Colors.white),
                        onPressed: () => playerService.seekBackward(seconds: 10),
                      ),
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryGradientEnd],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          iconSize: 38,
                          color: Colors.black,
                          icon: Icon(
                            playerService.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          ),
                          onPressed: playerService.togglePlay,
                        ),
                      ),
                      IconButton(
                        iconSize: 36,
                        icon: const Icon(Icons.forward_10_rounded, color: Colors.white),
                        onPressed: () => playerService.seekForward(seconds: 10),
                      ),
                      IconButton(
                        icon: const Icon(Icons.speed, color: Colors.white70),
                        onPressed: () => _showSpeedPicker(playerService),
                      ),
                    ],
                  ),

                  // Sleep timer status banner if active
                  if (playerService.sleepTimerEndTime != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bedtime, size: 14, color: AppColors.secondary),
                          const SizedBox(width: 6),
                          Text(
                            'Hẹn giờ tắt: ${_formatDuration(playerService.sleepTimerEndTime!.difference(DateTime.now()))}',
                            style: AppTypography.bodySmall.copyWith(color: AppColors.secondary),
                          ),
                        ],
                      ),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => _showSleepTimerPicker(playerService),
                      icon: const Icon(Icons.timer_outlined, size: 16, color: Colors.white54),
                      label: Text(
                        'Hẹn giờ ngủ',
                        style: AppTypography.bodySmall.copyWith(color: Colors.white54),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
