import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/supabase.dart';
import '../models/order_event.dart';
import '../providers/orders_provider.dart';
import '../widgets/status_badge.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  List<OrderEvent> _events = [];
  bool _loadingEvents = true;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final data = await supabase
          .from('order_events')
          .select()
          .eq('order_id', widget.orderId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _events = (data as List).map((e) => OrderEvent.fromJson(e)).toList();
          _loadingEvents = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingEvents = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdating = true);

    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) {
        _showError('Not authenticated');
        return;
      }

      final response = await http.patch(
        Uri.parse('$siteUrl/api/partner/orders/${widget.orderId}/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        ref.read(singleOrderProvider(widget.orderId).notifier).refresh();
        _fetchEvents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Status updated to ${newStatus.replaceAll('_', ' ')}'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        final body = jsonDecode(response.body);
        _showError(body['error'] ?? 'Failed to update status');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  int _stepIndex(String? status) {
    switch (status) {
      case 'pickup_scheduled':
      case 'picked_up':
        return 0;
      case 'at_partner':
      case 'weighed':
        return 1;
      case 'in_process':
      case 'ready':
        return 2;
      case 'out_for_delivery':
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(singleOrderProvider(widget.orderId));

    if (order == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Order Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentStepIndex = _stepIndex(order.status);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('#${order.orderNumber ?? 'Order'}'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (order.status != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(child: StatusBadge(status: order.status!)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress tracker
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Progress',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressTracker(currentStepIndex),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Order details
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Details',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailRow('Customer', order.customerName),
                    _detailRow(
                        'Service',
                        order.serviceType == 'express'
                            ? 'Express'
                            : 'Standard'),
                    if (order.estimatedWeight != null)
                      _detailRow('Est. Weight',
                          '${order.estimatedWeight!.toStringAsFixed(1)} lbs'),
                    if (order.finalWeight != null)
                      _detailRow('Final Weight',
                          '${order.finalWeight!.toStringAsFixed(1)} lbs'),
                    if (order.total != null)
                      _detailRow(
                          'Total', '\$${order.total!.toStringAsFixed(2)}'),
                    if (order.streetAddress != null)
                      _detailRow('Address',
                          '${order.streetAddress}${order.aptUnit != null ? ', ${order.aptUnit}' : ''}\n${order.city ?? ''}, ${order.state ?? ''} ${order.zipCode ?? ''}'),
                    if (order.instructions != null &&
                        order.instructions!.isNotEmpty)
                      _detailRow('Instructions', order.instructions!),
                    if (order.hangDry == true ||
                        order.separateColors == true ||
                        order.hypoallergenic == true) ...[
                      const Divider(),
                      const Text(
                        'Preferences',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (order.hangDry == true)
                            _chip('Hang Dry'),
                          if (order.separateColors == true)
                            _chip('Separate Colors'),
                          if (order.hypoallergenic == true)
                            _chip('Hypoallergenic'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            if (order.status == 'at_partner')
              _actionButton(
                'Process Order',
                Icons.play_arrow,
                const Color(0xFF10B981),
                () => context.push('/process/${order.id}'),
              ),
            if (order.status == 'weighed')
              _actionButton(
                'Start Processing',
                Icons.local_laundry_service,
                const Color(0xFF7C3AED),
                () => _updateStatus('in_process'),
              ),
            if (order.status == 'in_process')
              _actionButton(
                'Mark Ready',
                Icons.check_circle,
                const Color(0xFF10B981),
                () => _updateStatus('ready'),
              ),

            const SizedBox(height: 16),

            // Activity log
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Activity Log',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_loadingEvents)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            'No activity yet',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ),
                      )
                    else
                      ..._events.map((event) => _buildEventTile(event)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressTracker(int currentStep) {
    final steps = [
      'Picked up',
      'Washing & drying',
      'Folding',
      'Out for delivery',
    ];

    return Row(
      children: List.generate(steps.length, (index) {
        final isCompleted = index <= currentStep;
        final isActive = index == currentStep;
        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  if (index > 0)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index <= currentStep
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade300,
                      ),
                    ),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981)
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
                      border: isActive
                          ? Border.all(
                              color: const Color(0xFF10B981), width: 3)
                          : null,
                    ),
                    child: isCompleted
                        ? const Icon(Icons.check,
                            color: Colors.white, size: 14)
                        : null,
                  ),
                  if (index < steps.length - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: index < currentStep
                            ? const Color(0xFF10B981)
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                steps[index],
                style: TextStyle(
                  fontSize: 10,
                  color: isCompleted
                      ? const Color(0xFF1F2937)
                      : Colors.grey.shade500,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
      side: BorderSide.none,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _actionButton(
      String label, IconData icon, Color color, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isUpdating ? null : onPressed,
        icon: _isUpdating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildEventTile(OrderEvent event) {
    String? formattedDate;
    if (event.createdAt != null) {
      try {
        final date = DateTime.parse(event.createdAt!);
        formattedDate = DateFormat('MMM d, h:mm a').format(date.toLocal());
      } catch (_) {
        formattedDate = event.createdAt;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF7C3AED),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatEventType(event.eventType ?? ''),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
                if (event.note != null && event.note!.isNotEmpty)
                  Text(
                    event.note!,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                if (formattedDate != null)
                  Text(
                    formattedDate,
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatEventType(String eventType) {
    return eventType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty
            ? '${w[0].toUpperCase()}${w.substring(1)}'
            : w)
        .join(' ');
  }
}
