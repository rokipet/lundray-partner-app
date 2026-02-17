import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../widgets/status_badge.dart';

class ReceiveScreen extends ConsumerWidget {
  const ReceiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final partnerId = authState.user?.id;

    if (partnerId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final ordersState = ref.watch(ordersProvider(partnerId));
    final toProcess = ordersState.byStatus(['at_partner']);
    final recentlyProcessed = ordersState.byStatus(['weighed']);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Receive & Process',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ordersState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(ordersProvider(partnerId).notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'To Process',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (toProcess.isEmpty)
                      _emptyState('No orders to process', Icons.inbox_outlined)
                    else
                      ...toProcess.map(
                        (order) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                    CategoryBadge(
                                        category: order.serviceCategory),
                                    if (order.serviceType != null) ...[
                                      const SizedBox(width: 6),
                                      ServiceTypeBadge(
                                          serviceType: order.serviceType!),
                                    ],
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
                                if (order.estimatedWeight != null)
                                  Text(
                                    'Est. weight: ~${order.estimatedWeight!.toStringAsFixed(1)} lbs',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 13,
                                    ),
                                  ),
                                // Items summary for non-wash orders
                                if (!order.isWash &&
                                    order.items.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '${order.items.length} item${order.items.length != 1 ? 's' : ''}: ${order.items.map((i) => '${i.quantity}x ${i.name}').join(', ')}',
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 13,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () =>
                                        context.push('/process/${order.id}'),
                                    icon: const Icon(Icons.play_arrow, size: 20),
                                    label: const Text('Process'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF10B981),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Recently Processed',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (recentlyProcessed.isEmpty)
                      _emptyState(
                          'No recently processed orders', Icons.history)
                    else
                      ...recentlyProcessed.map(
                        (order) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            onTap: () => context.push('/order/${order.id}'),
                            leading: const Icon(Icons.check_circle,
                                color: Color(0xFF7C3AED)),
                            title: Row(
                              children: [
                                Text('#${order.orderNumber ?? 'N/A'}'),
                                const SizedBox(width: 6),
                                CategoryBadge(
                                    category: order.serviceCategory),
                              ],
                            ),
                            subtitle: Text(order.customerName),
                            trailing: order.finalWeight != null
                                ? Text(
                                    '${order.finalWeight!.toStringAsFixed(1)} lbs',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _emptyState(String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
