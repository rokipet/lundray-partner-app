import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import '../config/supabase.dart';
import '../models/order.dart';
import '../models/bag.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';

class ProcessWizardScreen extends ConsumerStatefulWidget {
  final String orderId;

  const ProcessWizardScreen({super.key, required this.orderId});

  @override
  ConsumerState<ProcessWizardScreen> createState() =>
      _ProcessWizardScreenState();
}

class _ProcessWizardScreenState extends ConsumerState<ProcessWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // Step 1: Scanned bags
  final List<Bag> _scannedBags = [];
  bool _isScanning = false;
  String? _scanError;

  // Step 2: Photos
  File? _bagsPhoto;
  File? _scalePhoto;
  String? _bagsPhotoUrl;
  String? _scalePhotoUrl;
  bool _isUploadingBags = false;
  bool _isUploadingScale = false;

  // Step 3: Weight
  final TextEditingController _weightController = TextEditingController();
  double _weight = 0;

  // Step 4: Confirm
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _pageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _scanBag(Order order) async {
    setState(() {
      _isScanning = true;
      _scanError = null;
    });

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _InlineScannerPage(
          onScanned: (code) async {
            Navigator.of(context).pop();
            try {
              final data = await supabase
                  .from('bags')
                  .select()
                  .eq('bag_code', code)
                  .maybeSingle();

              if (data == null) {
                setState(() => _scanError = 'Bag not found: $code');
                return;
              }

              final bag = Bag.fromJson(data);

              if (bag.orderId != order.id) {
                setState(() =>
                    _scanError = 'Bag $code does not belong to this order');
                return;
              }

              if (_scannedBags.any((b) => b.id == bag.id)) {
                setState(() => _scanError = 'Bag $code already scanned');
                return;
              }

              setState(() {
                _scannedBags.add(bag);
                _scanError = null;
              });
            } catch (e) {
              setState(() => _scanError = 'Error scanning bag: $e');
            }
          },
        ),
      ),
    );

    setState(() => _isScanning = false);
  }

  Future<void> _takePhoto({required bool isBagsPhoto}) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      imageQuality: 80,
    );

    if (image == null) return;

    final file = File(image.path);

    if (isBagsPhoto) {
      setState(() {
        _bagsPhoto = file;
        _isUploadingBags = true;
      });
    } else {
      setState(() {
        _scalePhoto = file;
        _isUploadingScale = true;
      });
    }

    try {
      final fileName =
          '${isBagsPhoto ? 'bags' : 'scale'}_${widget.orderId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bytes = await file.readAsBytes();

      await supabase.storage.from('order-photos').uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final url =
          supabase.storage.from('order-photos').getPublicUrl(fileName);

      setState(() {
        if (isBagsPhoto) {
          _bagsPhotoUrl = url;
          _isUploadingBags = false;
        } else {
          _scalePhotoUrl = url;
          _isUploadingScale = false;
        }
      });
    } catch (e) {
      setState(() {
        if (isBagsPhoto) {
          _isUploadingBags = false;
        } else {
          _isUploadingScale = false;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    }
  }

  double _getPartnerRate() {
    final profile = ref.read(authProvider).profile;
    return profile?.partnerRatePerLb ?? 0.80;
  }

  double _getPartnerMinimumEarning() {
    final profile = ref.read(authProvider).profile;
    return profile?.partnerMinimumEarning ?? 15.0;
  }

  double _calculateEarning() {
    final rate = _getPartnerRate();
    final minimum = _getPartnerMinimumEarning();
    final earning = _weight * rate;
    return earning > minimum ? earning : minimum;
  }

  Future<void> _submit(Order order) async {
    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        setState(() {
          _submitError = 'Not authenticated';
          _isSubmitting = false;
        });
        return;
      }

      // Update order status
      final response = await http.patch(
        Uri.parse(
            '$siteUrl/api/partner/orders/${widget.orderId}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'status': 'weighed',
          'final_weight': _weight,
          'photo_url': _scalePhotoUrl,
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        setState(() {
          _submitError = body['error'] ?? 'Failed to update order';
          _isSubmitting = false;
        });
        return;
      }

      // Scan each bag via API
      final distributedWeight =
          _scannedBags.isNotEmpty ? _weight / _scannedBags.length : _weight;

      for (final bag in _scannedBags) {
        await http.post(
          Uri.parse('$siteUrl/api/bags/scan'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'bag_code': bag.bagCode,
            'action': 'receive',
            'weight': distributedWeight,
          }),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order processed successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _submitError = 'Error: $e';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(singleOrderProvider(widget.orderId));

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Process Order')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Process #${order.orderNumber ?? ''}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(4, (index) {
                final isActive = index == _currentStep;
                final isDone = index < _currentStep;
                return Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isDone
                              ? const Color(0xFF10B981)
                              : isActive
                                  ? const Color(0xFF7C3AED)
                                  : Colors.grey.shade300,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: isDone
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 16)
                              : Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                        ),
                      ),
                      if (index < 3)
                        Expanded(
                          child: Container(
                            height: 2,
                            color: isDone
                                ? const Color(0xFF10B981)
                                : Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _stepLabel('Scan', 0),
                _stepLabel('Photos', 1),
                _stepLabel('Weight', 2),
                _stepLabel('Confirm', 3),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Page content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildScanStep(order),
                _buildPhotosStep(),
                _buildWeightStep(order),
                _buildConfirmStep(order),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepLabel(String label, int index) {
    final isActive = index == _currentStep;
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        color: isActive ? const Color(0xFF7C3AED) : Colors.grey.shade500,
        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  // Step 1: Scan Bags
  Widget _buildScanStep(Order order) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Scan Bags',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Scan the QR codes on each bag for this order',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isScanning ? null : () => _scanBag(order),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Bag QR Code'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF7C3AED),
                side: const BorderSide(color: Color(0xFF7C3AED)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (_scanError != null) ...[
            const SizedBox(height: 8),
            Text(
              _scanError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
          const SizedBox(height: 16),
          if (_scannedBags.isNotEmpty) ...[
            Text(
              '${_scannedBags.length} bag(s) scanned',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._scannedBags.map(
              (bag) => ListTile(
                leading: const Icon(Icons.check_circle,
                    color: Color(0xFF10B981)),
                title: Text(bag.bagCode ?? 'Unknown'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _nextStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Skip Scanning'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _scannedBags.isNotEmpty ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Step 2: Photos
  Widget _buildPhotosStep() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Take Photos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Take photos of the bags and the scale reading',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          _photoButton(
            title: 'Take Bags Photo',
            icon: Icons.shopping_bag_outlined,
            photo: _bagsPhoto,
            isUploading: _isUploadingBags,
            uploaded: _bagsPhotoUrl != null,
            onTap: () => _takePhoto(isBagsPhoto: true),
          ),
          const SizedBox(height: 16),
          _photoButton(
            title: 'Take Scale Photo',
            icon: Icons.scale,
            photo: _scalePhoto,
            isUploading: _isUploadingScale,
            uploaded: _scalePhotoUrl != null,
            onTap: () => _takePhoto(isBagsPhoto: false),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _photoButton({
    required String title,
    required IconData icon,
    required File? photo,
    required bool isUploading,
    required bool uploaded,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: uploaded ? const Color(0xFF10B981) : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            if (photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  photo,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.grey.shade400, size: 30),
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (isUploading)
                    const Text('Uploading...',
                        style: TextStyle(color: Colors.orange, fontSize: 13))
                  else if (uploaded)
                    const Text('Uploaded',
                        style: TextStyle(
                            color: Color(0xFF10B981), fontSize: 13))
                  else
                    Text('Tap to take photo',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ),
            if (uploaded)
              const Icon(Icons.check_circle, color: Color(0xFF10B981))
            else if (isUploading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.camera_alt, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  // Step 3: Weight
  Widget _buildWeightStep(Order order) {
    final rate = _getPartnerRate();
    final minimum = _getPartnerMinimumEarning();
    final weightEarning = _weight * rate;
    final earning = _calculateEarning();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter Weight',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter the total weight from the scale',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Weight (lbs)',
              suffixText: 'lbs',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF10B981), width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _weight = double.tryParse(value) ?? 0;
              });
            },
          ),
          const SizedBox(height: 24),
          if (_weight > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Earning',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  _priceRow('Weight x Rate',
                      '${_weight.toStringAsFixed(1)} x \$${rate.toStringAsFixed(2)}/lb',
                      value: '\$${weightEarning.toStringAsFixed(2)}'),
                  _priceRow('Minimum Earning', '',
                      value: '\$${minimum.toStringAsFixed(2)}'),
                  const Divider(),
                  _priceRow('Your Earning', '',
                      value: '\$${earning.toStringAsFixed(2)}',
                      bold: true,
                      color: const Color(0xFF10B981)),
                ],
              ),
            ),
          ],
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _weight > 0 ? _nextStep : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text('Next'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String detail,
      {required String value, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                if (detail.isNotEmpty)
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Step 4: Confirm
  Widget _buildConfirmStep(Order order) {
    final earning = _calculateEarning();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Review and confirm the order details',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _summaryRow(
                        'Order', '#${order.orderNumber ?? 'N/A'}'),
                    _summaryRow('Customer', order.customerName),
                    _summaryRow(
                        'Service',
                        order.serviceType == 'express'
                            ? 'Express'
                            : 'Standard'),
                    _summaryRow(
                        'Bags Scanned', '${_scannedBags.length}'),
                    _summaryRow(
                        'Weight', '${_weight.toStringAsFixed(1)} lbs'),
                    _summaryRow(
                        'Your Earning', '\$${earning.toStringAsFixed(2)}'),
                    if (order.instructions != null &&
                        order.instructions!.isNotEmpty) ...[
                      const Divider(),
                      const Text(
                        'Instructions',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.instructions!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                    if (order.hangDry == true ||
                        order.separateColors == true ||
                        order.hypoallergenic == true) ...[
                      const Divider(),
                      const Text(
                        'Preferences',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (order.hangDry == true)
                        _preferenceChip('Hang Dry'),
                      if (order.separateColors == true)
                        _preferenceChip('Separate Colors'),
                      if (order.hypoallergenic == true)
                        _preferenceChip('Hypoallergenic'),
                    ],
                    if (_bagsPhoto != null || _scalePhoto != null) ...[
                      const Divider(),
                      const Text(
                        'Photos',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_bagsPhoto != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _bagsPhoto!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                          if (_bagsPhoto != null && _scalePhoto != null)
                            const SizedBox(width: 8),
                          if (_scalePhoto != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _scalePhoto!,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_submitError != null) ...[
            const SizedBox(height: 8),
            Text(
              _submitError!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSubmitting ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Back'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed:
                      _isSubmitting ? null : () => _submit(order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _preferenceChip(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          const Icon(Icons.check, color: Color(0xFF10B981), size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

class _InlineScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;

  const _InlineScannerPage({required this.onScanned});

  @override
  State<_InlineScannerPage> createState() => _InlineScannerPageState();
}

class _InlineScannerPageState extends State<_InlineScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan Bag QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_hasScanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                setState(() => _hasScanned = true);
                widget.onScanned(barcode!.rawValue!);
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF10B981),
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
