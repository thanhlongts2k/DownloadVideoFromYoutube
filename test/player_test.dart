import 'package:flutter_test/flutter_test.dart';
import 'package:ytdownloader/services/player_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerService & PlayableItem tests', () {
    test('PlayableItem correctly identifies video files', () {
      final item = PlayableItem(
        id: '/path/video.mp4',
        filePath: '/path/video.mp4',
        title: 'Amazing Song',
        isVideo: true,
      );

      expect(item.isVideo, isTrue);
      expect(item.artist, equals('TubeX Offline'));
      final mediaItem = item.toMediaItem();
      expect(mediaItem.title, equals('Amazing Song'));
      expect(mediaItem.album, equals('TubeX Offline Library'));
    });

    test('PlayableItem correctly identifies audio files', () {
      final item = PlayableItem(
        id: '/path/audio.mp3',
        filePath: '/path/audio.mp3',
        title: 'Acoustic Guitar',
        artist: 'Artist Name',
        isVideo: false,
      );

      expect(item.isVideo, isFalse);
      expect(item.artist, equals('Artist Name'));
    });

    test('PlayerService sleep timer calculate end time and cancel', () {
      final player = PlayerService();
      player.setSleepTimer(const Duration(minutes: 30));
      expect(player.sleepTimerEndTime, isNotNull);
      expect(
        player.sleepTimerEndTime!.difference(DateTime.now()).inMinutes,
        greaterThanOrEqualTo(29),
      );

      player.cancelSleepTimer();
      expect(player.sleepTimerEndTime, isNull);
    });

    test('PlayerService sleep timer end of track flag', () {
      final player = PlayerService();
      player.setSleepTimerEndOfTrack();
      expect(player.sleepTimerEndTime, isNull);
      player.cancelSleepTimer();
      expect(player.sleepTimerEndTime, isNull);
    });
  });
}
