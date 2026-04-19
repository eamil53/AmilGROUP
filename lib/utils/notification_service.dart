import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> init() async {
    // 1. Request permissions (especially for iOS)
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // iOS Foreground settings
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
    }

    // 2. Local Notifications Setup
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

    // 3. FCM Foreground handling
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      debugPrint('Got a message whilst in the foreground!');
      
      // Get my current token for suppression check
      String? myToken = await _messaging.getToken();
      
      // Don't show notification if I was the sender
      if (message.data['senderId'] == myToken) {
        debugPrint('Suppressed notification from myself');
        return;
      }

      if (message.notification != null) {
        showLocalNotification(
          message.notification!.title ?? 'Bildirim',
          message.notification!.body ?? '',
        );
      }
    });

    // 4. Get FCM Token & Subscribe to Topics
    try {
      String? token = await _messaging.getToken();
      debugPrint('FCM Token: $token');
      
      // Subscribe all users to 'targets' topic for collective notifications
      await _messaging.subscribeToTopic('targets');
      debugPrint('Subscribed to targets topic');
    } catch (e) {
      debugPrint('Error getting FCM token or subscribing: $e');
    }

    // 5. Removed local Firestore listener to prevent double notifications
    // (We rely on Cloud Functions push notifications instead)
  }

  static Future<void> showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'general_channel',
      'Genel Bildirimler',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
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
