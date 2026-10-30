import 'package:flutter/material.dart';
import 'add_warranty_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'warranty_details_screen.dart';
import 'notifications_screen.dart';
import '../services/notification_service.dart';
import 'login_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  late Future<List<Map<String, dynamic>>> _warrantiesFuture;

  @override
  void initState() {
    super.initState();
    NotificationService.checkPendingReminders();
    _warrantiesFuture = _loadWarranties();
  }

  Future<void> _openReceipt(String receiptPath) async {
    try {
      final supabase = Supabase.instance.client;

      final signedUrl = await supabase.storage
          .from('warranty-files')
          .createSignedUrl(receiptPath, 300);

      final uri = Uri.parse(signedUrl);

      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open receipt.');
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open receipt: $error'),
        ),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _loadWarranties() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return [];
    }

    final data = await Supabase.instance.client
        .from('warranties')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }
  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF448AFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text(
          'Madmoon',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: blue,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              color: blue,
            ),

            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Welcome to Madmoon!',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Keep your warranties and receipts in one place.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 28),

              // Warranty summary
              Row(
                children: [
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _warrantiesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _summaryCard(
                            'Total Warranties',
                            '!',
                            Icons.inventory_2_outlined,
                            blue,
                          );
                        }

                        final count = snapshot.data?.length ?? 0;

                        return _summaryCard(
                          'Total Warranties',
                          snapshot.connectionState ==
                              ConnectionState.waiting
                              ? '...'
                              : count.toString(),
                          Icons.inventory_2_outlined,
                          blue,
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _warrantiesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return _summaryCard(
                            'Expiring Soon',
                            '!',
                            Icons.access_time,
                            Colors.orange,
                          );
                        }

                        final today = DateTime.now();
                        final todayDate = DateTime(
                          today.year,
                          today.month,
                          today.day,
                        );

                        final limitDate = todayDate.add(
                          const Duration(days: 30),
                        );

                        final warranties = snapshot.data ?? [];

                        final expiringCount =
                            warranties.where((warranty) {
                              final expiry = DateTime.tryParse(
                                warranty['expiry_date']?.toString() ?? '',
                              );

                              if (expiry == null) return false;

                              return !expiry.isBefore(todayDate) &&
                                  !expiry.isAfter(limitDate);
                            }).length;

                        return _summaryCard(
                          'Expiring Soon',
                          snapshot.connectionState ==
                              ConnectionState.waiting
                              ? '...'
                              : expiringCount.toString(),
                          Icons.access_time,
                          Colors.orange,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Add warranty
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (Supabase.instance.client.auth.currentUser == null) {
                      if (!context.mounted) return;

                      await showDialog<void>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('Login Required'),
                          content: const Text(
                            'Please log in or create an account to add a warranty.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(dialogContext);
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text('Login / Sign Up'),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AddWarrantyScreen(),
                      ),
                    );
                    if (!mounted) return;

                    if (result == true) {
                      setState(() {
                        _warrantiesFuture = _loadWarranties();
                      });
                    }
                  },


                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text(
                    'Add New Warranty',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              const Text(
                'My Warranties',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Empty state

// Saved warranties
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _warrantiesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return const Center(
                      child: Text('Could not load warranties.'),
                    );
                  }

                  final warranties = snapshot.data ?? [];

                  if (warranties.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No warranties yet'),
                      ),
                    );
                  }
                  return Column(
                    children: warranties.map((warranty) {
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () async {
                            final updated = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) => WarrantyDetailsScreen(
                                  warranty: warranty,
                                ),
                              ),
                            );

                            if (updated == true && mounted) {
                              setState(() {
                                _warrantiesFuture = _loadWarranties();
                              });
                            }
                          },

                          leading: const Icon(
                            Icons.verified_outlined,
                            color: Color(0xFF448AFF),
                          ),
                          title: Text(
                            warranty['device_name']?.toString() ?? 'Product',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'Store: ${warranty['store_name'] ?? '-'}\n'
                                'Expires: ${warranty['expiry_date'] ?? '-'}',
                          ),
                          isThreeLine: true,
                          trailing: warranty['receipt_path'] != null
                              ? IconButton(
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              color: Color(0xFF448AFF),
                            ),
                            tooltip: 'View Receipt',
                            onPressed: () {
                              _openReceipt(warranty['receipt_path'].toString());
                            },
                          )
                              : null,
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(
      String title,
      String count,
      IconData icon,
      Color color,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(height: 12),
          Text(
            count,
            style: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}