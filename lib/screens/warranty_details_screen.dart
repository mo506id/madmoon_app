import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'edit_warranty_screen.dart';
import '../services/notification_service.dart';


class WarrantyDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> warranty;

  const WarrantyDetailsScreen({
    super.key,
    required this.warranty,
  });

  Future<void> _openReceipt(BuildContext context) async {
    final receiptPath = warranty['receipt_path']?.toString();

    if (receiptPath == null || receiptPath.isEmpty) return;

    try {
      final signedUrl = await Supabase.instance.client.storage
          .from('warranty-files')
          .createSignedUrl(receiptPath, 300);

      final opened = await launchUrl(
        Uri.parse(signedUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw Exception('Could not open receipt.');
      }
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open receipt: $error'),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Warranty'),
        content: const Text(
          'Are you sure you want to delete this warranty?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;


    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) return;

      final receiptPath = warranty['receipt_path']?.toString();

      bool receiptUsedByAnotherWarranty = false;

      if (receiptPath != null && receiptPath.isNotEmpty) {
        final otherWarranties = await Supabase.instance.client
            .from('warranties')
            .select('warranty_id')
            .eq('user_id', user.id)
            .eq('receipt_path', receiptPath)
            .neq('warranty_id', warranty['warranty_id']);

        receiptUsedByAnotherWarranty = otherWarranties.isNotEmpty;
      }

      await Supabase.instance.client
          .from('warranties')
          .delete()
          .eq('warranty_id', warranty['warranty_id'])
          .eq('user_id', user.id)
          .select('warranty_id')
          .single();
      await NotificationService.cancelThreeReminders(
        warranty['warranty_id'] as int,
      );

      if (receiptPath != null &&
          receiptPath.isNotEmpty &&
          !receiptUsedByAnotherWarranty) {
        try {
          final deletedFiles = await Supabase.instance.client.storage
              .from('warranty-files')
              .remove([receiptPath]);

          debugPrint('Requested receipt deletion: $receiptPath');
          debugPrint('Storage deletion result: $deletedFiles');

        } catch (storageError) {
          debugPrint('Could not remove receipt: $storageError');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Receipt deletion failed: $storageError'),
              ),
            );
          }
        }
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warranty deleted successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete warranty: $error'),
        ),
      );
    }

  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF448AFF);

    Future<void> openEditScreen() async {
      final updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => EditWarrantyScreen(
            warranty: warranty,
          ),
        ),
      );

      if (updated == true && context.mounted) {
        Navigator.pop(context, true);
      }
    }

    final deviceName =
        warranty['device_name']?.toString() ?? 'Product';
    final category =
        warranty['category']?.toString() ?? '-';
    final storeName =
        warranty['store_name']?.toString() ?? '-';
    final purchaseDate =
        warranty['purchase_date']?.toString() ?? '-';
    final expiryDate =
        warranty['expiry_date']?.toString() ?? '-';
    final today = DateUtils.dateOnly(DateTime.now());
    final expiry = DateTime.tryParse(expiryDate);

    String warrantyStatus = 'Unknown';
    Color statusColor = Colors.grey;

    if (expiry != null) {
      final daysLeft = DateUtils.dateOnly(expiry)
          .difference(today)
          .inDays;

      if (daysLeft < 0) {
        warrantyStatus = 'Expired';
        statusColor = Colors.red;
      } else if (daysLeft <= 30) {
        warrantyStatus = 'Expiring Soon';
        statusColor = Colors.orange;
      } else {
        warrantyStatus = 'Active';
        statusColor = Colors.green;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Warranty Details'),
        backgroundColor: Colors.white,
        foregroundColor: blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 70,
              color: blue,
            ),
            const SizedBox(height: 16),

            Text(
              deviceName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  warrantyStatus,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailRow('Category', category),
                    const Divider(),
                    _detailRow('Store', storeName),
                    const Divider(),
                    _detailRow('Purchase Date', purchaseDate),
                    const Divider(),
                    _detailRow('Expiry Date', expiryDate),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: openEditScreen,
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit Warranty'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: blue,
                          side: const BorderSide(color: blue),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDelete(context),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Delete Warranty'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                    if (warranty['receipt_path'] != null &&
                        warranty['receipt_path'].toString().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _openReceipt(context),
                          icon: const Icon(Icons.receipt_long_outlined),
                          label: const Text('View Receipt'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}