class Profile {
  final String id;
  final String? role;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final String? businessName;
  final String? businessAddress;
  final String? businessPhone;
  final double? partnerRatePerLb;
  final double? partnerMinimumEarning;
  final String? createdAt;
  final String? updatedAt;

  Profile({
    required this.id,
    this.role,
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.businessName,
    this.businessAddress,
    this.businessPhone,
    this.partnerRatePerLb,
    this.partnerMinimumEarning,
    this.createdAt,
    this.updatedAt,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      role: json['role'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      businessName: json['business_name'] as String?,
      businessAddress: json['business_address'] as String?,
      businessPhone: json['business_phone'] as String?,
      partnerRatePerLb: _toDouble(json['partner_rate_per_lb']),
      partnerMinimumEarning: _toDouble(json['partner_minimum_earning']),
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

  String get fullName {
    final first = firstName ?? '';
    final last = lastName ?? '';
    if (first.isEmpty && last.isEmpty) return 'Partner';
    return '$first $last'.trim();
  }
}
