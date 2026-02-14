import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/earnings_provider.dart';
import '../widgets/summary_card.dart';

class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final partnerId = authState.user?.id;

    if (partnerId == null) {
      return const Center(child: Text('Not authenticated'));
    }

    final earningsState = ref.watch(earningsProvider(partnerId));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Earnings',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: earningsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(earningsProvider(partnerId).notifier).refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 8,
                      childAspectRatio: 0.85,
                      children: [
                        SummaryCard(
                          title: 'Total',
                          value:
                              '\$${earningsState.totalEarnings.toStringAsFixed(2)}',
                          color: const Color(0xFF10B981),
                          icon: Icons.account_balance_wallet,
                        ),
                        SummaryCard(
                          title: 'Pending',
                          value:
                              '\$${earningsState.pendingEarnings.toStringAsFixed(2)}',
                          color: Colors.amber.shade700,
                          icon: Icons.schedule,
                        ),
                        SummaryCard(
                          title: 'Paid',
                          value:
                              '\$${earningsState.paidEarnings.toStringAsFixed(2)}',
                          color: const Color(0xFF7C3AED),
                          icon: Icons.check_circle,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Earnings History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (earningsState.earnings.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Icon(Icons.payments_outlined,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 8),
                              Text(
                                'No earnings yet',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...earningsState.earnings.map(
                        (earning) {
                          String? formattedDate;
                          if (earning.createdAt != null) {
                            try {
                              final date =
                                  DateTime.parse(earning.createdAt!);
                              formattedDate = DateFormat('MMM d, yyyy')
                                  .format(date.toLocal());
                            } catch (_) {
                              formattedDate = earning.createdAt;
                            }
                          }

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: earning.status == 'paid'
                                          ? const Color(0xFF10B981)
                                              .withValues(alpha: 0.1)
                                          : Colors.amber
                                              .withValues(alpha: 0.1),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      earning.status == 'paid'
                                          ? Icons.check_circle
                                          : Icons.schedule,
                                      color: earning.status == 'paid'
                                          ? const Color(0xFF10B981)
                                          : Colors.amber.shade700,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatEarningType(
                                              earning.earningType),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        if (formattedDate != null)
                                          Text(
                                            formattedDate,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 12,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${(earning.amount ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Color(0xFF1F2937),
                                        ),
                                      ),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: earning.status == 'paid'
                                              ? const Color(0xFF10B981)
                                                  .withValues(alpha: 0.15)
                                              : Colors.amber
                                                  .withValues(alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          earning.status == 'paid'
                                              ? 'Paid'
                                              : 'Pending',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: earning.status == 'paid'
                                                ? const Color(0xFF10B981)
                                                : Colors.amber.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatEarningType(String? type) {
    if (type == null) return 'Earning';
    return type
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) =>
            w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }
}
