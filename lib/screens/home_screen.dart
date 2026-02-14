import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/order.dart';
import '../providers/auth_provider.dart';
import '../providers/orders_provider.dart';
import '../widgets/summary_card.dart';
import '../widgets/order_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final partnerId = authState.user?.id;

    if (partnerId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final ordersState = ref.watch(ordersProvider(partnerId));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            Text(
              'Welcome, ${authState.profile?.firstName ?? 'Partner'}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
          ],
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
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        SummaryCard(
                          title: 'Incoming',
                          value: ordersState
                              .countByStatus(['created', 'confirmed', 'pickup_scheduled', 'picked_up']).toString(),
                          color: Colors.blue,
                          icon: Icons.local_shipping,
                        ),
                        SummaryCard(
                          title: 'In Queue',
                          value: ordersState
                              .countByStatus(['at_partner']).toString(),
                          color: Colors.amber.shade700,
                          icon: Icons.inbox,
                        ),
                        SummaryCard(
                          title: 'In Process',
                          value: ordersState
                              .countByStatus(
                                  ['weighed', 'in_process']).toString(),
                          color: const Color(0xFF7C3AED),
                          icon: Icons.local_laundry_service,
                        ),
                        SummaryCard(
                          title: 'Ready',
                          value:
                              ordersState.countByStatus(['ready']).toString(),
                          color: const Color(0xFF10B981),
                          icon: Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildOrderSection(
                      context,
                      'Incoming Orders',
                      ordersState.byStatus(['created', 'confirmed', 'pickup_scheduled', 'picked_up']),
                    ),
                    _buildOrderSection(
                      context,
                      'In Queue',
                      ordersState.byStatus(['at_partner']),
                    ),
                    _buildOrderSection(
                      context,
                      'Processing',
                      ordersState.byStatus(['weighed', 'in_process']),
                    ),
                    _buildOrderSection(
                      context,
                      'Ready for Pickup',
                      ordersState.byStatus(['ready']),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderSection(
      BuildContext context, String title, List<Order> orders) {
    if (orders.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 8),
        ...orders.map(
          (order) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OrderCard(
              order: order,
              onTap: () => context.push('/order/${order.id}'),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
