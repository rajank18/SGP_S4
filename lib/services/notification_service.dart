import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Plugin instance for managing notifications
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  // Initialize the notification service
  static Future<void> init() async {
    print('Initializing notification service...');
    tz.initializeTimeZones();

    // Request notification permission
    final status = await Permission.notification.request();
    print('Notification permission status: $status');

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialization = await _notifications.initialize(initSettings);
    print('Notification initialization result: $initialization');

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'expense_reminder_channel',
      'Expense Reminders',
      description: 'Daily reminders to track your expenses',
      importance: Importance.high,
    );

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidImplementation != null) {
      await androidImplementation.createNotificationChannel(channel);
      print('Android notification channel created');
    }
  }

  // Method to show the expense reminder notification
  static Future<void> showExpenseNotification() async {
    print('Attempting to show expense notification...');
    
    const androidDetails = AndroidNotificationDetails(
      'expense_reminder_channel',
      'Expense Reminders',
      channelDescription: 'Daily reminders to track your expenses',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: false,
      showProgress: false,
      onlyAlertOnce: false,
      autoCancel: true,
      ongoing: false,
      styleInformation: DefaultStyleInformation(true, true),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      threadIdentifier: 'expense_reminder',
    );

    try {
      await _notifications.show(
        1,
        'MoneyLog 💰',
        'Don\'t forget to add your expense.',
        const NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
      print('Notification shown successfully');
    } catch (e) {
      print('Error showing notification: $e');
    }
  }
}
