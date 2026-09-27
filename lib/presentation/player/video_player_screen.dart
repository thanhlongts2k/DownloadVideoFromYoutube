import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../services/player_service.dart';

class VideoPlayerScreen extends ConsumerStatefulWidget {
  final File file;
  final String title;
  final Duration? initialPosition;

  const VideoPlayerScreen({
    super.key,
    required this.file,
    required this.title,
    this.initialPosition,
  });

  static Future<void> open(
    BuildContext context, {
    required File file,
    required String title,
    Duration? initialPosition,
  }) {
    // If background player was playing something else, pause/stop it
    final playerService = PlayerService();
    if (playerService.isPlaying) {
      playerService.pause();
    }

    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerScreen(
          file: file,
          title: title,
          initialPosition: initialPosition,
        ),
      ),
    );
  }

  @override
  ConsumerState<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends ConsumerState<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  Timer? _hideTimer;
  double _playbackSpeed = 1.0;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.file(widget.file);
    try {
      await _controller.initialize();
      if (widget.initialPosition != null && widget.initialPosition! > Duration.zero) {
        await _controller.seekTo(widget.initialPosition!);
      }
      await _controller.play();
      setState(() {
        _isInitialized = true;
      });
      _startHideTimer();
      _controller.addListener(() {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('Error initializing video player: $e');
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideTimer();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _seekRelative(int seconds) {
    final current = _controller.value.position;
    final max = _controller.value.duration;
    final target = current + Duration(seconds: seconds);
    if (target < Duration.zero) {
      _controller.seekTo(Duration.zero);
    } else if (target > max) {
      _controller.seekTo(max);
    } else {
      _controller.seekTo(target);
    }
    _startHideTimer();
  }

  void _showSpeedPicker() {
    _hideTimer?.cancel();
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
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
                Text('Tốc độ phát video', style: AppTypography.titleSmall),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: speeds.map((s) {
                    final isSelected = _playbackSpeed == s;
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
                          setState(() => _playbackSpeed = s);
                          _controller.setPlaybackSpeed(s);
                          Navigator.pop(context);
                          _startHideTimer();
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

  void _switchToBackgroundMode() async {
    final currentPos = _controller.value.position;
    final playerService = ref.read(playerServiceProvider);

    await _controller.pause();

    // Play in background via PlayerService
    await playerService.playFile(widget.file, title: widget.title);
    if (currentPos > Duration.zero) {
      await playerService.seek(currentPos);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.headphones, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Đã chuyển sang chế độ nghe nền. Bạn có thể khóa màn hình!'),
            ],
          ),
          backgroundColor: AppColors.surface,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'Đang chuẩn bị video...',
                style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    }

    final pos = _controller.value.position;
    final dur = _controller.value.duration;
    final isPlaying = _controller.value.isPlaying;
    final maxSlider = dur.inMilliseconds.toDouble();
    final currentSlider = pos.inMilliseconds.toDouble().clamp(0.0, maxSlider > 0 ? maxSlider : 1.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Video view
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // Controls overlay
            AnimatedOpacity(
              opacity: _showControls ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Container(
                  color: Colors.black45,
                  child: SafeArea(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                                onPressed: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  widget.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.titleSmall.copyWith(
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              // Background audio switch button
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.85),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: _switchToBackgroundMode,
                                icon: const Icon(Icons.headphones, size: 16),
                                label: const Text(
                                  'Nghe nền',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Center play/pause & seek controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              iconSize: 44,
                              color: Colors.white,
                              icon: const Icon(Icons.replay_10_rounded),
                              onPressed: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 28),
                            Container(
                              width: 68,
                              height: 68,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary.withOpacity(0.9),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.4),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: IconButton(
                                iconSize: 40,
                                color: Colors.white,
                                icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
                                onPressed: () {
                                  if (isPlaying) {
                                    _controller.pause();
                                  } else {
                                    _controller.play();
                                    _startHideTimer();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 28),
                            IconButton(
                              iconSize: 44,
                              color: Colors.white,
                              icon: const Icon(Icons.forward_10_rounded),
                              onPressed: () => _seekRelative(10),
                            ),
                          ],
                        ),

                        // Bottom scrubber and action bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Scrubber Slider
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3.5,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: currentSlider,
                                  max: maxSlider > 0 ? maxSlider : 1.0,
                                  onChanged: (val) {
                                    _controller.seekTo(Duration(milliseconds: val.toInt()));
                                    _startHideTimer();
                                  },
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatDuration(pos),
                                      style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                                    ),
                                    Row(
                                      children: [
                                        // Speed button
                                        TextButton(
                                          onPressed: _showSpeedPicker,
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          child: Text(
                                            '${_playbackSpeed}x',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _formatDuration(dur),
                                          style: AppTypography.bodySmall.copyWith(color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
