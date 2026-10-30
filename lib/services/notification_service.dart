import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';



class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static int reminderId(int warrantyId, int daysBefore) {
    final reminderIndex = switch (daysBefore) {
      30 => 0,
      7 => 1,
      1 => 2,
      _ => throw ArgumentError('Invalid reminder day'),
    };

    return warrantyId * 3 + reminderIndex;
  }

  static Future<void> initialize() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Riyadh'));


    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const settings = InitializationSettings(
      android: androidSettings,
    );

    await _notifications.initialize(settings: settings);
  }

  static Future<bool> requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    return await android?.requestNotificationsPermission() ?? false;
  }
  static Future<void> showTestNotification() async {
    const androidDetails = AndroidNotificationDetails(
      'warranty_reminders',
      'Warranty Reminders',
      channelDescription: 'Notifications about warranty expiry dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    const details = NotificationDetails(
      android: androidDetails,
    );

    await _notifications.show(
      id: 1,
      title: 'Madmoon Reminder',
      body: 'Your warranty notifications are working!',
      notificationDetails: details,
    );
  }

  static Future<void> scheduleThreeReminders({
    required int warrantyId,
    required String deviceName,
    required DateTime expiryDate,
  }) async {
    await _notifications.cancel(id: warrantyId);
    for (final daysBefore in [30, 7, 1]) {
      final reminderDate = DateTime(
        expiryDate.year,
        expiryDate.month,
        expiryDate.day - daysBefore,
        0,
        0,
      );

      await scheduleWarrantyReminder(
        id: reminderId(warrantyId, daysBefore),
        deviceName: deviceName,
        reminderDate: reminderDate,
      );
    }
  }

  static Future<void> scheduleWarrantyReminder({
    required int id,
    required String deviceName,
    required DateTime reminderDate,
  }) async {

    final scheduledDate = tz.TZDateTime(
      tz.local,
      reminderDate.year,
      reminderDate.month,
      reminderDate.day,
      reminderDate.hour,
      reminderDate.minute,
    );


    if (!scheduledDate.isAfter(tz.TZDateTime.now(tz.local))) {
      debugPrint('Reminder skipped: scheduled date is in the past');
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'warranty_reminders',
      'Warranty Reminders',
      channelDescription: 'Notifications about warranty expiry dates',
      importance: Importance.high,
      priority: Priority.high,
    );

    await _notifications.zonedSchedule(
      id: id,
      title: 'Madmoon Warranty Reminder',
      body: 'The warranty for $deviceName is expiring soon.',
      scheduledDate: scheduledDate,
      notificationDetails: const NotificationDetails(
        android: androidDetails,
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    debugPrint('Warranty reminder scheduled: $deviceName at $scheduledDate');
  }
  static Future<void> cancelWarrantyReminder(int id) async {
    await _notifications.cancel(id: id);
    debugPrint('Warranty reminder cancelled: $id');
  }
  

  static Future<void> checkPendingReminders() async {
    final pending =
    await _notifications.pendingNotificationRequests();

    for (final notification in pending) {
      debugPrint(
        'Pending reminder: ${notification.id} - ${notification.title}',
      );
    }

    debugPrint('Total pending reminders: ${pending.length}');
  }

  static Future<void> cancelThreeReminders(int warrantyId) async {
    for (final daysBefore in [30, 7, 1]) {
      await _notifications.cancel(
        id: reminderId(warrantyId, daysBefore),
      );
    }

    // إلغاء التذكير القديم الذي استخدم رقم الضمان مباشرة
    await _notifications.cancel(id: warrantyId);

    debugPrint('Three warranty reminders cancelled: $warrantyId');
  }
  static Future<void> cancelAllReminders() async {
    await _notifications.cancelAll();
    debugPrint('All local reminders cancelled');
  }

  static Future<void> restoreUserReminders() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final warranties = await Supabase.instance.client
        .from('warranties')
        .select('warranty_id, device_name, expiry_date')
        .eq('user_id', user.id);

    for (final warranty in warranties) {
      await scheduleThreeReminders(
        warrantyId: warranty['warranty_id'] as int,
        deviceName: warranty['device_name'] as String,
        expiryDate: DateTime.parse(warranty['expiry_date'] as String),
      );
    }

    debugPrint('User warranty reminders restored');
  }
}