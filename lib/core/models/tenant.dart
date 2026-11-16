import '../utils/formatters.dart';
import '../utils/json_helpers.dart';

/// A tenant is one business organisation. Every business-owned row in the
/// database carries `tenant_id` and is protected by RLS.
class Tenant {
  const Tenant({
    required this.id,
    required this.name,
    required this.businessType,
    required this.currency,
    required this.currencySymbol,
    required this.taxRate,
    required this.lowStockThreshold,
    this.phone,
    this.email,
    this.address,
    this.logoUrl,
    required this.createdAt,
    this.dailyBriefingEnabled = true,
    this.dailyBriefingTime = '22:00',
    this.dailyBriefingTimezone = 'Asia/Karachi',
  });

  final String id;
  final String name;
  final String businessType;
  final String currency;
  final String currencySymbol;
  final double taxRate;
  final int lowStockThreshold;
  final String? phone;
  final String? email;
  final String? address;
  final String? logoUrl;
  final DateTime createdAt;

  /// Whether the scheduled daily executive briefing is enabled.
  final bool dailyBriefingEnabled;

  /// Local time of day in `HH:mm` (24-hour), in [dailyBriefingTimezone].
  final String dailyBriefingTime;

  /// IANA timezone used to decide when the business day ends.
  final String dailyBriefingTimezone;

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
    id: asString(json['id']),
    name: asString(json['name'], 'My Business'),
    businessType: asString(json['business_type'], 'Retail & General Store'),
    currency: asString(json['currency'], 'PKR'),
    currencySymbol: asString(json['currency_symbol'], 'Rs'),
    taxRate: asDouble(json['tax_rate']),
    lowStockThreshold: asInt(json['low_stock_threshold'], 5),
    phone: asNullableString(json['phone']),
    email: asNullableString(json['email']),
    address: asNullableString(json['address']),
    logoUrl: asNullableString(json['logo_url']),
    createdAt: asDate(json['created_at']),
    dailyBriefingEnabled: asBool(json['daily_briefing_enabled'], true),
    dailyBriefingTime: _normalizeTime(json['daily_briefing_time']),
    dailyBriefingTimezone: asString(
      json['daily_briefing_timezone'],
      'Asia/Karachi',
    ),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name.trim(),
    'business_type': businessType,
    'currency': currency,
    'currency_symbol': currencySymbol,
    'tax_rate': taxRate,
    'low_stock_threshold': lowStockThreshold,
    'phone': phone,
    'email': email,
    'address': address,
    'logo_url': logoUrl,
    'created_at': toIso(createdAt),
    'daily_briefing_enabled': dailyBriefingEnabled,
    'daily_briefing_time': dailyBriefingTime,
    'daily_briefing_timezone': dailyBriefingTimezone,
  };

  Tenant copyWith({
    String? name,
    String? businessType,
    String? currency,
    String? currencySymbol,
    double? taxRate,
    int? lowStockThreshold,
    String? phone,
    String? email,
    String? address,
    String? logoUrl,
    bool? dailyBriefingEnabled,
    String? dailyBriefingTime,
    String? dailyBriefingTimezone,
  }) => Tenant(
    id: id,
    name: name ?? this.name,
    businessType: businessType ?? this.businessType,
    currency: currency ?? this.currency,
    currencySymbol: currencySymbol ?? this.currencySymbol,
    taxRate: taxRate ?? this.taxRate,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    logoUrl: logoUrl ?? this.logoUrl,
    createdAt: createdAt,
    dailyBriefingEnabled:
        dailyBriefingEnabled ?? this.dailyBriefingEnabled,
    dailyBriefingTime: dailyBriefingTime ?? this.dailyBriefingTime,
    dailyBriefingTimezone:
        dailyBriefingTimezone ?? this.dailyBriefingTimezone,
  );

  String get initials => Formats.initials(name);
  String get currencyLabel => '$currency · $currencySymbol';

  static String _normalizeTime(dynamic value) {
    final text = asString(value, '22:00').trim();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return '22:00';
    final hour = int.tryParse(match.group(1)!) ?? 22;
    final minute = int.tryParse(match.group(2)!) ?? 0;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return '22:00';
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }
}
