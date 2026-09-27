import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

class PlayableItem {
  final String id;
  final String filePath;
  final String title;
  final String artist;
  final bool isVideo;
  final String? artUri;

  PlayableItem({
    required this.id,
    required this.filePath,
    required this.title,
    this.artist = 'TubeX Offline',
    required this.isVideo,
    this.artUri,
  });

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      album: 'TubeX Offline Library',
      title: title,
      artist: artist,
      artUri: artUri != null ? Uri.tryParse(artUri!) : null,
    );
  }
}

class PlayerService extends ChangeNotifier {
  static final PlayerService _instance = PlayerService._internal();
  factory PlayerService() => _instance;

  final AudioPlayer _audioPlayer = AudioPlayer();
  AudioPlayer get player => _audioPlayer;

  PlayableItem? _currentTrack;
  PlayableItem? get currentTrack => _currentTrack;

  List<PlayableItem> _queue = [];
  List<PlayableItem> get queue => List.unmodifiable(_queue);
  int _currentIndex = -1;
  int get currentIndex => _currentIndex;

  Timer? _sleepTimer;
  DateTime? _sleepTimerEndTime;
  DateTime? get sleepTimerEndTime => _sleepTimerEndTime;

  PlayerService._internal() {
    _initListeners();
  }

  void _initListeners() {
    _audioPlayer.playerStateStream.listen((state) {
      notifyListeners();
    });

    _audioPlayer.positionStream.listen((pos) {
      notifyListeners();
    });

    _audioPlayer.durationStream.listen((dur) {
      notifyListeners();
    });

    _audioPlayer.currentIndexStream.listen((idx) {
      if (idx != null && idx >= 0 && idx < _queue.length) {
        _currentIndex = idx;
        _currentTrack = _queue[idx];
        notifyListeners();
      }
    });

    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (_sleepTimer != null && _isSleepTimerEndOfTrack) {
          pause();
          cancelSleepTimer();
        }
      }
    });
  }

  bool _isSleepTimerEndOfTrack = false;

  bool get isPlaying => _audioPlayer.playing;
  ProcessingState get processingState => _audioPlayer.processingState;
  Duration get position => _audioPlayer.position;
  Duration get duration => _audioPlayer.duration ?? Duration.zero;
  double get speed => _audioPlayer.speed;
  LoopMode get loopMode => _audioPlayer.loopMode;

  Future<void> playFile(
    File file, {
    String? title,
    String? artist,
    String? artUri,
  }) async {
    final fileName = title ?? file.uri.pathSegments.last;
    final isVideo = fileName.toLowerCase().endsWith('.mp4') ||
        fileName.toLowerCase().endsWith('.mkv') ||
        fileName.toLowerCase().endsWith('.webm');

    final item = PlayableItem(
      id: file.path,
      filePath: file.path,
      title: _cleanTitle(fileName),
      artist: artist ?? (isVideo ? 'Video Sound • TubeX' : 'Audio Track • TubeX'),
      isVideo: isVideo,
      artUri: artUri,
    );

    _queue = [item];
    _currentIndex = 0;
    _currentTrack = item;

    try {
      final audioSource = AudioSource.file(
        file.path,
        tag: item.toMediaItem(),
      );

      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing file in PlayerService: $e');
    }
  }

  Future<void> playQueue(List<File> files, {int initialIndex = 0}) async {
    if (files.isEmpty) return;

    _queue = files.map((file) {
      final name = file.uri.pathSegments.last;
      final isVideo = name.toLowerCase().endsWith('.mp4') ||
          name.toLowerCase().endsWith('.mkv');
      return PlayableItem(
        id: file.path,
        filePath: file.path,
        title: _cleanTitle(name),
        artist: isVideo ? 'Video Sound • TubeX' : 'Audio Track • TubeX',
        isVideo: isVideo,
      );
    }).toList();

    _currentIndex = initialIndex.clamp(0, _queue.length - 1);
    _currentTrack = _queue[_currentIndex];

    try {
      final playlist = ConcatenatingAudioSource(
        children: _queue.map((item) {
          return AudioSource.file(
            item.filePath,
            tag: item.toMediaItem(),
          );
        }).toList(),
      );

      await _audioPlayer.setAudioSource(
        playlist,
        initialIndex: _currentIndex,
      );
      await _audioPlayer.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing queue in PlayerService: $e');
    }
  }

  Future<void> togglePlay() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
    notifyListeners();
  }

  Future<void> play() async => await _audioPlayer.play();
  Future<void> pause() async => await _audioPlayer.pause();

  Future<void> stop() async {
    await _audioPlayer.stop();
    _currentTrack = null;
    notifyListeners();
  }

  Future<void> seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> seekForward({int seconds = 10}) async {
    final target = _audioPlayer.position + Duration(seconds: seconds);
    final max = _audioPlayer.duration ?? target;
    await _audioPlayer.seek(target < max ? target : max);
  }

  Future<void> seekBackward({int seconds = 10}) async {
    final target = _audioPlayer.position - Duration(seconds: seconds);
    await _audioPlayer.seek(target > Duration.zero ? target : Duration.zero);
  }

  Future<void> next() async {
    if (_audioPlayer.hasNext) {
      await _audioPlayer.seekToNext();
    }
  }

  Future<void> previous() async {
    if (_audioPlayer.hasPrevious) {
      await _audioPlayer.seekToPrevious();
    } else {
      await _audioPlayer.seek(Duration.zero);
    }
  }

  Future<void> setSpeed(double newSpeed) async {
    await _audioPlayer.setSpeed(newSpeed);
    notifyListeners();
  }

  Future<void> toggleLoopMode() async {
    final nextMode = switch (_audioPlayer.loopMode) {
      LoopMode.off => LoopMode.all,
      LoopMode.all => LoopMode.one,
      LoopMode.one => LoopMode.off,
    };
    await _audioPlayer.setLoopMode(nextMode);
    notifyListeners();
  }

  // --- Sleep Timer ---
  void setSleepTimer(Duration duration) {
    cancelSleepTimer();
    _isSleepTimerEndOfTrack = false;
    _sleepTimerEndTime = DateTime.now().add(duration);
    _sleepTimer = Timer(duration, () {
      pause();
      cancelSleepTimer();
    });
    notifyListeners();
  }

  void setSleepTimerEndOfTrack() {
    cancelSleepTimer();
    _isSleepTimerEndOfTrack = true;
    _sleepTimerEndTime = null;
    notifyListeners();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEndTime = null;
    _isSleepTimerEndOfTrack = false;
    notifyListeners();
  }

  String _cleanTitle(String raw) {
    return raw
        .replaceAll(RegExp(r'\.(mp4|m4a|mp3|webm|mkv)$', caseSensitive: false), '')
        .replaceAll('_', ' ')
        .trim();
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }
}

// --- Riverpod Provider ---
final playerServiceProvider = ChangeNotifierProvider<PlayerService>((ref) {
  return PlayerService();
});
