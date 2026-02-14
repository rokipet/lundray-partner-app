class PartnerEarning {
  final String id;
  final String? partnerId;
  final String? orderId;
  final String? earningType;
  final double? amount;
  final String? status;
  final String? paidAt;
  final String? createdAt;

  PartnerEarning({
    required this.id,
    this.partnerId,
    this.orderId,
    this.earningType,
    this.amount,
    this.status,
    this.paidAt,
    this.createdAt,
  });

  factory PartnerEarning.fromJson(Map<String, dynamic> json) {
    return PartnerEarning(
      id: json['id'] as String,
      partnerId: json['partner_id'] as String?,
      orderId: json['order_id'] as String?,
      earningType: json['earning_type'] as String?,
      amount: _toDouble(json['amount']),
      status: json['status'] as String?,
      paidAt: json['paid_at'] as String?,
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
