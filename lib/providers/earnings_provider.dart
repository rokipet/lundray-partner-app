import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/supabase.dart';
import '../models/earning.dart';

class EarningsState {
  final List<PartnerEarning> earnings;
  final bool isLoading;
  final String? error;

  EarningsState({
    this.earnings = const [],
    this.isLoading = false,
    this.error,
  });

  double get totalEarnings =>
      earnings.fold(0.0, (sum, e) => sum + (e.amount ?? 0));

  double get pendingEarnings => earnings
      .where((e) => e.status == 'pending')
      .fold(0.0, (sum, e) => sum + (e.amount ?? 0));

  double get paidEarnings => earnings
      .where((e) => e.status == 'paid')
      .fold(0.0, (sum, e) => sum + (e.amount ?? 0));
}

class EarningsNotifier extends StateNotifier<EarningsState> {
  EarningsNotifier(this._partnerId) : super(EarningsState(isLoading: true)) {
    _fetchEarnings();
  }

  final String _partnerId;

  Future<void> _fetchEarnings() async {
    try {
      final data = await supabase
          .from('partner_earnings')
          .select()
          .eq('partner_id', _partnerId)
          .order('created_at', ascending: false);

      final earnings =
          (data as List).map((e) => PartnerEarning.fromJson(e)).toList();

      if (mounted) {
        state = EarningsState(earnings: earnings);
      }
    } catch (e) {
      if (mounted) {
        state = EarningsState(error: 'Failed to load earnings: $e');
      }
    }
  }

  Future<void> refresh() async {
    state = EarningsState(earnings: state.earnings, isLoading: true);
    await _fetchEarnings();
  }
}

final earningsProvider =
    StateNotifierProvider.family<EarningsNotifier, EarningsState, String>(
  (ref, partnerId) => EarningsNotifier(partnerId),
);
