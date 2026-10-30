import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends State<NotificationsScreen> {
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _notificationsFuture = _loadNotifications();
  }

  Future<List<Map<String, dynamic>>> _loadNotifications() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return [];

    final data = await supabase
        .from('warranties')
        .select('warranty_id, device_name, expiry_date')
        .eq('user_id', user.id)
        .order('expiry_date');

    final today = DateUtils.dateOnly(DateTime.now());

    return List<Map<String, dynamic>>.from(data).where((warranty) {
      final expiry = DateTime.tryParse(
        warranty['expiry_date']?.toString() ?? '',
      );

      if (expiry == null) return false;

      final daysLeft =
          DateUtils.dateOnly(expiry).difference(today).inDays;

      return daysLeft <= 30;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF448AFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: blue,
        actions: [
          IconButton(
            tooltip: 'Test notification',
            icon: const Icon(Icons.notification_add_outlined),
            onPressed: () async {
              try {
                await NotificationService.showTestNotification();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Notification failed: $error')),
                );
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load notifications.\n${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            );
          }

          final notifications = snapshot.data ?? [];

          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_outlined,
                    size: 80,
                    color: blue,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Your warranty reminders will appear here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final today = DateUtils.dateOnly(DateTime.now());

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final warranty = notifications[index];

              final expiry = DateTime.parse(
                warranty['expiry_date'].toString(),
              );

              final daysLeft = DateUtils.dateOnly(expiry)
                  .difference(today)
                  .inDays;

              final message = daysLeft < 0
                  ? 'Warranty expired ${-daysLeft} days ago'
                  : daysLeft == 0
                  ? 'Warranty expires today!'
                  : 'Warranty expires in $daysLeft days';

              return Card(
                color: Colors.white,
                child: ListTile(
                  leading: Icon(
                    daysLeft < 0
                        ? Icons.error_outline
                        : Icons.notifications_active_outlined,
                    color: daysLeft < 0
                        ? Colors.red
                        : Colors.orange,
                  ),
                  title: Text(
                    warranty['device_name']?.toString() ??
                        'Unknown product',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(message),
                ),
              );
            },
          );
        },
      ),
    );
  }
}