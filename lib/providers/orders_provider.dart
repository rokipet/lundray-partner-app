import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:realtime_client/realtime_client.dart';
import '../config/supabase.dart';
import '../models/order.dart';

class OrdersState {
  final List<Order> orders;
  final bool isLoading;
  final String? error;

  OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  List<Order> byStatus(List<String> statuses) {
    return orders.where((o) => statuses.contains(o.status)).toList();
  }

  int countByStatus(List<String> statuses) {
    return orders.where((o) => statuses.contains(o.status)).length;
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier(this._partnerId) : super(OrdersState(isLoading: true)) {
    _fetchOrders();
    _setupRealtime();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _fetchOrders();
    });
  }

  final String _partnerId;
  RealtimeChannel? _channel;
  Timer? _pollTimer;

  Future<void> _fetchOrders() async {
    try {
      final data = await supabase
          .from('orders')
          .select()
          .eq('partner_id', _partnerId)
          .order('created_at', ascending: false);

      final orders = (data as List).map((e) => Order.fromJson(e)).toList();

      if (mounted) {
        state = OrdersState(orders: orders);
      }
    } catch (e) {
      if (mounted) {
        state = OrdersState(error: 'Failed to load orders: $e');
      }
    }
  }

  void _setupRealtime() {
    _channel = supabase.channel('partner_orders_$_partnerId');
    _channel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'partner_id',
            value: _partnerId,
          ),
          callback: (payload) {
            _fetchOrders();
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    state = OrdersState(orders: state.orders, isLoading: true);
    await _fetchOrders();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    if (_channel != null) {
      supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
}

final ordersProvider =
    StateNotifierProvider.family<OrdersNotifier, OrdersState, String>(
  (ref, partnerId) => OrdersNotifier(partnerId),
);

class SingleOrderNotifier extends StateNotifier<Order?> {
  SingleOrderNotifier(this._orderId) : super(null) {
    _fetch();
    _subscribe();
  }

  final String _orderId;
  StreamSubscription? _subscription;

  Future<void> _fetch() async {
    try {
      final data =
          await supabase.from('orders').select().eq('id', _orderId).single();
      if (mounted) {
        state = Order.fromJson(data);
      }
    } catch (_) {}
  }

  void _subscribe() {
    _subscription = supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('id', _orderId)
        .listen((data) {
      if (data.isNotEmpty && mounted) {
        state = Order.fromJson(data.first);
      }
    });
  }

  Future<void> refresh() async {
    await _fetch();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final singleOrderProvider =
    StateNotifierProvider.family<SingleOrderNotifier, Order?, String>(
  (ref, orderId) => SingleOrderNotifier(orderId),
);
