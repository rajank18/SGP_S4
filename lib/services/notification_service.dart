import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  // Plugin instance for managing notifications
  static final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize the notification service
  static Future<void> init() async {
    // Request notification permission
    await Permission.notification.request();

    // Android initialization settings
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Use your app icon

    // General initialization settings
    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    // Initialize the plugin
    await notificationsPlugin.initialize(settings);

    // Create notification channel for expense reminders
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'expense_reminder', // Channel ID (unique)
      'Expense Reminder', // Channel name visible to the user
      description: 'Channel for expense reminder notifications', // Channel description
      importance: Importance.high, // Importance level
    );

    // Create the channel on the device
    await notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);
  }

  // Method to show the expense reminder notification
  static Future<void> showExpenseNotification() async {
    print("Showing expense reminder notification..."); // Log for debugging

    // Android notification details
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'expense_reminder', // Must match the channel ID
      'Expense Reminder', // Must match the channel name
      importance: Importance.high,
      priority: Priority.high,
      channelDescription: 'Channel for expense reminder notifications',
    );

    // General notification details
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Show the notification
    await notificationsPlugin.show(
      0, // Notification ID (unique for each notification)
      'MoneyLog 💰', // Notification title
      'Don\'t forget to add your expense.', // Notification body
      details,
    );
  }
}
