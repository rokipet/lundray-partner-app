import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../config/supabase.dart';

class ReadyScreen extends ConsumerStatefulWidget {
  const ReadyScreen({super.key});

  @override
  ConsumerState<ReadyScreen> createState() => _ReadyScreenState();
}

class _ReadyScreenState extends ConsumerState<ReadyScreen> {
  final List<_ScannedBagResult> _recentScans = [];
  bool _isProcessing = false;

  Future<void> _openScanner() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ReadyScannerPage(
          onScanned: (code) async {
            Navigator.of(context).pop();
            await _markBagReady(code);
          },
        ),
      ),
    );
  }

  Future<void> _markBagReady(String bagCode) async {
    setState(() => _isProcessing = true);

    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        _addScanResult(bagCode, false, 'Not authenticated');
        return;
      }

      final response = await http.post(
        Uri.parse('$siteUrl/api/bags/scan'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'bag_code': bagCode,
          'action': 'ready',
        }),
      );

      if (response.statusCode == 200) {
        _addScanResult(bagCode, true, 'Marked as ready');
      } else {
        final body = jsonDecode(response.body);
        _addScanResult(
            bagCode, false, body['error'] ?? 'Failed to mark ready');
      }
    } catch (e) {
      debugPrint('Ready scan error: $e');
      _addScanResult(bagCode, false, 'Something went wrong. Please try again.');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _addScanResult(String code, bool success, String message) {
    setState(() {
      _recentScans.insert(
        0,
        _ScannedBagResult(
          bagCode: code,
          success: success,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Bag $code marked as ready!' : message),
          backgroundColor: success ? const Color(0xFF10B981) : Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Mark Ready',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _openScanner,
              icon: const Icon(Icons.qr_code_scanner, size: 24),
              label: Text(
                _isProcessing ? 'Processing...' : 'Scan Bag to Mark Ready',
                style: const TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text(
                  'Recent Scans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const Spacer(),
                if (_recentScans.isNotEmpty)
                  TextButton(
                    onPressed: () => setState(() => _recentScans.clear()),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _recentScans.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'No bags scanned yet',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Scan a bag QR code to mark it as ready',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _recentScans.length,
                    itemBuilder: (context, index) {
                      final scan = _recentScans[index];
                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: ListTile(
                          leading: Icon(
                            scan.success
                                ? Icons.check_circle
                                : Icons.error,
                            color: scan.success
                                ? const Color(0xFF10B981)
                                : Colors.red,
                          ),
                          title: Text(
                            scan.bagCode,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(scan.message),
                          trailing: Text(
                            '${scan.timestamp.hour.toString().padLeft(2, '0')}:${scan.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ScannedBagResult {
  final String bagCode;
  final bool success;
  final String message;
  final DateTime timestamp;

  _ScannedBagResult({
    required this.bagCode,
    required this.success,
    required this.message,
    required this.timestamp,
  });
}

class _ReadyScannerPage extends StatefulWidget {
  final void Function(String code) onScanned;

  const _ReadyScannerPage({required this.onScanned});

  @override
  State<_ReadyScannerPage> createState() => _ReadyScannerPageState();
}

class _ReadyScannerPageState extends State<_ReadyScannerPage> {
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
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
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
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                _hasScanned
                    ? 'Code detected!'
                    : 'Point camera at bag QR code',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
