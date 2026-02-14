class Bag {
  final String id;
  final String? bagCode;
  final String? orderId;
  final String? routeId;
  final String? status;
  final double? weight;
  final String? receivedBy;
  final String? receivedAt;
  final String? readyBy;
  final String? readyAt;
  final String? createdAt;

  Bag({
    required this.id,
    this.bagCode,
    this.orderId,
    this.routeId,
    this.status,
    this.weight,
    this.receivedBy,
    this.receivedAt,
    this.readyBy,
    this.readyAt,
    this.createdAt,
  });

  factory Bag.fromJson(Map<String, dynamic> json) {
    return Bag(
      id: json['id'] as String,
      bagCode: json['bag_code'] as String?,
      orderId: json['order_id'] as String?,
      routeId: json['route_id'] as String?,
      status: json['status'] as String?,
      weight: _toDouble(json['weight']),
      receivedBy: json['received_by'] as String?,
      receivedAt: json['received_at'] as String?,
      readyBy: json['ready_by'] as String?,
      readyAt: json['ready_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
