import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart' as fp;
import '../services/notification_service.dart';


class AddWarrantyScreen extends StatefulWidget {
  const AddWarrantyScreen({super.key});

  @override
  State<AddWarrantyScreen> createState() =>
      _AddWarrantyScreenState();
}

class _AddWarrantyScreenState extends State<AddWarrantyScreen> {
  final _formKey = GlobalKey<FormState>();

  final _productController = TextEditingController();
  final _storeController = TextEditingController();
  final _categoryController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  XFile? _receiptFile;


  DateTime? _purchaseDate;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _productController.dispose();
    _storeController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _selectDate({required bool isPurchase}) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        if (isPurchase) {
          _purchaseDate = selectedDate;
        } else {
          _expiryDate = selectedDate;
        }
      });
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date';

    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }


  Future<void> _pickReceiptFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      if (!mounted) return;

      setState(() {
        _receiptFile = image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt image selected successfully!'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select image: $error'),
        ),
      );
    }
  }

  Future<void> _takeReceiptPhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (image == null) return;
      if (!mounted) return;

      setState(() {
        _receiptFile = image;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt photo captured successfully!'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not take photo: $error'),
        ),
      );
    }
  }


  Future<void> _pickReceiptPdf() async {
    try {
      final files = await fp.FilePicker.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (files.isEmpty) return;

      final file = files.first;

      if (file.path == null) {
        throw Exception('Could not access the selected PDF.');
      }

      if (!mounted) return;

      setState(() {
        _receiptFile = XFile(
          file.path!,
          name: file.name,
          mimeType: 'application/pdf',
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF receipt selected successfully!'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not select PDF: $error'),
        ),
      );
    }
  }

  Future<String?> _uploadReceipt(String userId) async {
    if (_receiptFile == null) return null;

    final file = _receiptFile!;
    final bytes = await file.readAsBytes();

    final extension = file.name.split('.').last.toLowerCase();

    final contentType = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    final fileName =
        '${DateTime.now().microsecondsSinceEpoch}.$extension';

    final filePath = '$userId/receipts/$fileName';

    await Supabase.instance.client.storage
        .from('warranty-files')
        .uploadBinary(
      filePath,
      bytes,
      fileOptions: FileOptions(
        contentType: contentType,
      ),
    );

    return filePath;
  }

  Future<void> _saveWarranty() async {
    if (!_formKey.currentState!.validate()) return;

    if (_purchaseDate == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select both dates.'),
        ),
      );
      return;
    }

    if (_expiryDate!.isBefore(_purchaseDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expiry date cannot be before purchase date.'),
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in first.'),
        ),
      );
      return;
    }

    try {
      final receiptPath = await _uploadReceipt(user.id);


      final savedWarranty = await supabase.from('warranties').insert({


        'user_id': user.id,
        'device_name': _productController.text.trim(),
        'category': _categoryController.text.trim(),
        'store_name': _storeController.text.trim(),
        'purchase_date': _formatDate(_purchaseDate),
        'expiry_date': _formatDate(_expiryDate),
        'receipt_path': receiptPath,
      }).select('warranty_id').single();

      try {
        final expiryDate = _expiryDate;
        if (expiryDate == null) {
          throw StateError('Warranty expiry date is missing');
        }

        await NotificationService.scheduleThreeReminders(
          warrantyId: savedWarranty['warranty_id'] as int,
          deviceName: _productController.text.trim(),
          expiryDate: expiryDate,
        );

      } catch (error) {
        debugPrint('Could not schedule warranty reminder: $error');
      }


      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Warranty saved successfully!'),
        ),
      );

      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Database error: ${error.message}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save warranty: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF448AFF);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        title: const Text('Add New Warranty'),
        backgroundColor: Colors.white,
        foregroundColor: blue,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Warranty Details',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter your product warranty information.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 25),

              TextFormField(
                controller: _productController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the product name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 18),

              TextFormField(
                controller: _storeController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  prefixIcon: Icon(Icons.store_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the store name';
                  }
                  return null;
                },
              ),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Product Category',
                  prefixIcon: Icon(Icons.category_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the product category';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 22),

              _dateField(
                title: 'Purchase Date',
                date: _purchaseDate,
                onTap: () => _selectDate(isPurchase: true),
              ),

              const SizedBox(height: 18),

              _dateField(
                title: 'Warranty Expiry Date',
                date: _expiryDate,
                onTap: () => _selectDate(isPurchase: false),
              ),
              const SizedBox(height: 25),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.attach_file, color: blue),
                        SizedBox(width: 10),
                        Text(
                          'Attach Receipt',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickReceiptPdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('PDF'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickReceiptFromGallery,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Gallery'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _takeReceiptPhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Camera'),
                        ),
                      ],
                    ),
                    if (_receiptFile != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selected: ${_receiptFile!.name}',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _saveWarranty,
                  icon: const Icon(
                    Icons.save_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Save Warranty',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String title,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          prefixIcon: const Icon(Icons.calendar_month_outlined),
          border: const OutlineInputBorder(),
        ),
        child: Text(_formatDate(date)),
      ),
    );
  }
}