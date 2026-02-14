import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  static _BadgeConfig _getConfig(String status) {
    switch (status) {
      case 'created':
        return _BadgeConfig('New', Colors.grey);
      case 'confirmed':
        return _BadgeConfig('Confirmed', Colors.orange.shade300);
      case 'pickup_scheduled':
        return _BadgeConfig('Scheduled', Colors.orange);
      case 'picked_up':
        return _BadgeConfig('En Route', Colors.blue);
      case 'at_partner':
        return _BadgeConfig('At Partner', Colors.amber.shade700);
      case 'weighed':
        return _BadgeConfig('Weighed', const Color(0xFF7C3AED));
      case 'in_process':
        return _BadgeConfig('In Process', Colors.blue);
      case 'ready':
        return _BadgeConfig('Ready', const Color(0xFF10B981));
      case 'out_for_delivery':
        return _BadgeConfig('Out for Delivery', Colors.indigo);
      case 'delivered':
        return _BadgeConfig('Delivered', Colors.green.shade800);
      case 'cancelled':
        return _BadgeConfig('Cancelled', Colors.red);
      default:
        return _BadgeConfig(status.replaceAll('_', ' '), Colors.grey);
    }
  }
}

class _BadgeConfig {
  final String label;
  final Color color;

  _BadgeConfig(this.label, this.color);
}

class ServiceTypeBadge extends StatelessWidget {
  final String serviceType;

  const ServiceTypeBadge({super.key, required this.serviceType});

  @override
  Widget build(BuildContext context) {
    final isExpress = serviceType == 'express';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isExpress
            ? const Color(0xFF7C3AED).withValues(alpha: 0.15)
            : Colors.grey.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isExpress ? 'Express' : 'Standard',
        style: TextStyle(
          color: isExpress ? const Color(0xFF7C3AED) : Colors.grey.shade700,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
