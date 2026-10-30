import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notification_service.dart';


class EditWarrantyScreen extends StatefulWidget {
  final Map<String, dynamic> warranty;

  const EditWarrantyScreen({
    super.key,
    required this.warranty,
  });

  @override
  State<EditWarrantyScreen> createState() =>
      _EditWarrantyScreenState();
}

class _EditWarrantyScreenState extends State<EditWarrantyScreen> {
  late final TextEditingController _productController;
  late final TextEditingController _storeController;
  late final TextEditingController _categoryController;
  DateTime? _purchaseDate;
  DateTime? _expiryDate;


  @override
  void initState() {
    super.initState();

    _productController = TextEditingController(
      text: widget.warranty['device_name']?.toString() ?? '',
    );

    _storeController = TextEditingController(
      text: widget.warranty['store_name']?.toString() ?? '',
    );

    _categoryController = TextEditingController(
      text: widget.warranty['category']?.toString() ?? '',
    );

    _purchaseDate = DateTime.tryParse(
      widget.warranty['purchase_date']?.toString() ?? '',
    );

    _expiryDate = DateTime.tryParse(
      widget.warranty['expiry_date']?.toString() ?? '',
    );

  }

  Future<void> _selectDate(bool isPurchaseDate) async {
    final currentDate = isPurchaseDate
        ? _purchaseDate
        : _expiryDate;

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      if (isPurchaseDate) {
        _purchaseDate = selectedDate;
      } else {
        _expiryDate = selectedDate;
      }
    });
  }

  Future<void> _saveChanges() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return;

    if (_productController.text.trim().isEmpty ||
        _purchaseDate == null ||
        _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all required fields'),
        ),
      );
      return;
    }

    if (_expiryDate!.isBefore(_purchaseDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date must be after purchase date'),
        ),
      );
      return;
    }

    try {
      await Supabase.instance.client
          .from('warranties')
          .update({
        'device_name': _productController.text.trim(),
        'store_name': _storeController.text.trim(),
        'category': _categoryController.text.trim(),
        'purchase_date':
        _purchaseDate!.toIso8601String().split('T').first,
        'expiry_date':
        _expiryDate!.toIso8601String().split('T').first,
      })
          .eq('warranty_id', widget.warranty['warranty_id'])
          .eq('user_id', user.id)
          .select('warranty_id')
          .single();

      try {
        final warrantyId = widget.warranty['warranty_id'] as int;
        final expiryDate = _expiryDate!;

        final reminderDate = DateTime(
          expiryDate.year,
          expiryDate.month,
          expiryDate.day - 7,
          0,
          0,
        );

        await NotificationService.cancelThreeReminders(
          widget.warranty['warranty_id'] as int,
        );

        await NotificationService.scheduleThreeReminders(
          warrantyId: widget.warranty['warranty_id'] as int,
          deviceName: _productController.text.trim(),
          expiryDate: expiryDate,
        );

        await NotificationService.scheduleWarrantyReminder(
          id: warrantyId,
          deviceName: _productController.text.trim(),
          reminderDate: reminderDate,
        );
      } catch (error) {
        debugPrint('Could not update warranty reminder: $error');
      }


      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warranty updated successfully'),
        ),
      );

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating warranty: $error')),
      );
    }
  }

  @override
  void dispose() {
    _productController.dispose();
    _storeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF448AFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FF),
      appBar: AppBar(
        title: const Text('Edit Warranty'),
        backgroundColor: Colors.white,
        foregroundColor: blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _productController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _storeController,
              decoration: const InputDecoration(
                labelText: 'Store Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Product Category',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Purchase Date'),
              subtitle: Text(
                _purchaseDate == null
                    ? 'Select purchase date'
                    : _purchaseDate!.toIso8601String().split('T').first,
              ),
              trailing: const Icon(Icons.calendar_month, color: blue),
              onTap: () => _selectDate(true),
            ),

            const SizedBox(height: 16),

            ListTile(
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: const Text('Expiry Date'),
              subtitle: Text(
                _expiryDate == null
                    ? 'Select expiry date'
                    : _expiryDate!.toIso8601String().split('T').first,
              ),
              trailing: const Icon(Icons.calendar_month, color: blue),
              onTap: () => _selectDate(false),
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}