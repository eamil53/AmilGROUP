import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    final DarwinInitializationSettings initializationSettingsDarwin = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // notification response handle
      },
    );
  }

  static Future<void> scheduleDailyDataEntryReminder() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Günlük Veri Giriş Hatırlatıcısı',
      channelDescription: 'Her akşam veri girişini hatırlatır',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // This is a simple periodic reminder (every day at a fixed interval if needed)
    // For specific time-of-day, more complex logic is needed with TZ, but we can do a repeated snack/notif check
    await _notificationsPlugin.show(
      999,
      'Günlük Satış Verileri Girişi',
      'Bugünkü Portal satış verilerini girmeyi unutmayın!',
      details,
    );
  }

  static Future<void> showLowStockAlert(String productName, int remainingQuantity) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'low_stock_channel',
      'Kritik Stok Uyarıları',
      channelDescription: 'Stok azaldığında bildirim gönderir',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await _notificationsPlugin.show(
      productName.hashCode,
      'Kritik Stok Uyarısı!',
      '${productName} stoğu kritik seviyeye ulaştı! Kalan: ${remainingQuantity}',
      platformChannelSpecifics,
    );
  }
}
