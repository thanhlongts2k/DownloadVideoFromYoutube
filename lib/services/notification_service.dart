import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(initSettings);
    _initialized = true;
  }

  Future<void> showDownloadProgress({
    required int id,
    required String title,
    required int progress,
    required String speedStr,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Tiến trình tải xuống',
      channelDescription: 'Thông báo tiến độ tải video và âm thanh',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
      ongoing: true,
      onlyAlertOnce: true,
    );

    final details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id,
      title,
      'Đang tải: $progress% ($speedStr)',
      details,
    );
  }

  Future<void> showDownloadComplete({
    required int id,
    required String title,
    required String filePath,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'completed_channel',
      'Tải xuống hoàn tất',
      channelDescription: 'Thông báo khi file đã tải xong',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      id,
      'Tải xuống hoàn tất 🎉',
      title,
      details,
      payload: filePath,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
