class OrderEvent {
  final String id;
  final String? orderId;
  final String? eventType;
  final String? oldValue;
  final String? newValue;
  final String? changedBy;
  final String? changedByRole;
  final String? note;
  final Map<String, dynamic>? metadata;
  final String? createdAt;

  OrderEvent({
    required this.id,
    this.orderId,
    this.eventType,
    this.oldValue,
    this.newValue,
    this.changedBy,
    this.changedByRole,
    this.note,
    this.metadata,
    this.createdAt,
  });

  factory OrderEvent.fromJson(Map<String, dynamic> json) {
    return OrderEvent(
      id: json['id'] as String,
      orderId: json['order_id'] as String?,
      eventType: json['event_type'] as String?,
      oldValue: json['old_value'] as String?,
      newValue: json['new_value'] as String?,
      changedBy: json['changed_by'] as String?,
      changedByRole: json['changed_by_role'] as String?,
      note: json['note'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] as String?,
    );
  }
}
