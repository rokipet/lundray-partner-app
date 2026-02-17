import 'package:flutter/material.dart';
import '../models/order.dart';
import 'status_badge.dart';

class OrderCard extends StatelessWidget {
  final Order order;
  final VoidCallback? onTap;

  const OrderCard({super.key, required this.order, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '#${order.orderNumber ?? 'N/A'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  if (order.status != null) StatusBadge(status: order.status!),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.customerName,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  CategoryBadge(category: order.serviceCategory),
                  const SizedBox(width: 6),
                  if (order.serviceType != null)
                    ServiceTypeBadge(serviceType: order.serviceType!),
                  const SizedBox(width: 8),
                  if (order.estimatedWeight != null)
                    Text(
                      '~${order.estimatedWeight!.toStringAsFixed(1)} lbs',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  if (order.finalWeight != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${order.finalWeight!.toStringAsFixed(1)} lbs',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
