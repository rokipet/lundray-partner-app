class Order {
  final String id;
  final String? orderNumber;
  final String? userId;
  final String? driverId;
  final String? partnerId;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? phone;
  final String? preferredContact;
  final String? streetAddress;
  final String? aptUnit;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? pickupDate;
  final String? pickupTimeWindow;
  final String? serviceType;
  final double? estimatedWeight;
  final double? finalWeight;
  final double? estimatedPrice;
  final double? total;
  final double? pricePerLb;
  final double? minimumCharge;
  final double? expressFee;
  final double? subtotal;
  final String? status;
  final String? paymentStatus;
  final int? bagCount;
  final String? weightPhotoUrl;
  final String? deliveryPhotoUrl;
  final String? instructions;
  final bool? hangDry;
  final bool? separateColors;
  final bool? hypoallergenic;
  final String? deliveryMethod;
  final String? routeId;
  final String? zoneName;
  final String? locale;
  final String? source;
  final String? createdAt;
  final String? updatedAt;

  Order({
    required this.id,
    this.orderNumber,
    this.userId,
    this.driverId,
    this.partnerId,
    this.firstName,
    this.lastName,
    this.email,
    this.phone,
    this.preferredContact,
    this.streetAddress,
    this.aptUnit,
    this.city,
    this.state,
    this.zipCode,
    this.pickupDate,
    this.pickupTimeWindow,
    this.serviceType,
    this.estimatedWeight,
    this.finalWeight,
    this.estimatedPrice,
    this.total,
    this.pricePerLb,
    this.minimumCharge,
    this.expressFee,
    this.subtotal,
    this.status,
    this.paymentStatus,
    this.bagCount,
    this.weightPhotoUrl,
    this.deliveryPhotoUrl,
    this.instructions,
    this.hangDry,
    this.separateColors,
    this.hypoallergenic,
    this.deliveryMethod,
    this.routeId,
    this.zoneName,
    this.locale,
    this.source,
    this.createdAt,
    this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String?,
      userId: json['user_id'] as String?,
      driverId: json['driver_id'] as String?,
      partnerId: json['partner_id'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      preferredContact: json['preferred_contact'] as String?,
      streetAddress: json['street_address'] as String?,
      aptUnit: json['apt_unit'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      zipCode: json['zip_code'] as String?,
      pickupDate: json['pickup_date'] as String?,
      pickupTimeWindow: json['pickup_time_window'] as String?,
      serviceType: json['service_type'] as String?,
      estimatedWeight: _toDouble(json['estimated_weight']),
      finalWeight: _toDouble(json['final_weight']),
      estimatedPrice: _toDouble(json['estimated_price']),
      total: _toDouble(json['total']),
      pricePerLb: _toDouble(json['price_per_lb']),
      minimumCharge: _toDouble(json['minimum_charge']),
      expressFee: _toDouble(json['express_fee']),
      subtotal: _toDouble(json['subtotal']),
      status: json['status'] as String?,
      paymentStatus: json['payment_status'] as String?,
      bagCount: json['bag_count'] as int?,
      weightPhotoUrl: json['weight_photo_url'] as String?,
      deliveryPhotoUrl: json['delivery_photo_url'] as String?,
      instructions: json['instructions'] as String?,
      hangDry: json['hang_dry'] as bool?,
      separateColors: json['separate_colors'] as bool?,
      hypoallergenic: json['hypoallergenic'] as bool?,
      deliveryMethod: json['delivery_method'] as String?,
      routeId: json['route_id'] as String?,
      zoneName: json['zone_name'] as String?,
      locale: json['locale'] as String?,
      source: json['source'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String get customerName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    if (first.isEmpty && last.isEmpty) return 'Unknown';
    return '$first $last'.trim();
  }
}
