import '../utils/formatters.dart';
import '../utils/json_helpers.dart';

enum AccountType {
  customer,
  supplier;

  static AccountType fromValue(dynamic value) =>
      value?.toString().toLowerCase() == 'supplier'
      ? AccountType.supplier
      : AccountType.customer;

  String get value => name;
  String get label => this == AccountType.customer ? 'Customer' : 'Supplier';
  String get chargeLabel => this == AccountType.customer
      ? 'Credit sale'
      : 'Credit purchase';
  String get paymentLabel => this == AccountType.customer
      ? 'Payment received'
      : 'Payment made';
}

/// A customer or supplier account for the Khata/ledger module.
class Account {
  const Account({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.balance,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final AccountType type;
  final double openingBalance;

  /// Positive means the customer owes the business (receivable) or the
  /// business owes the supplier (payable).
  final double balance;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Account.fromJson(Map<String, dynamic> json) => Account(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    name: asString(json['name'], 'Account'),
    type: AccountType.fromValue(json['account_type'] ?? json['type']),
    openingBalance: asDouble(json['opening_balance']),
    balance: asDouble(json['balance']),
    phone: asNullableString(json['phone']),
    email: asNullableString(json['email']),
    address: asNullableString(json['address']),
    createdAt: asDate(json['created_at']),
    updatedAt: asDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name.trim(),
    'account_type': type.value,
    'opening_balance': openingBalance,
    'balance': balance,
    'phone': phone,
    'email': email,
    'address': address,
    'created_at': toIso(createdAt),
    'updated_at': toIso(updatedAt),
  };

  Account copyWith({
    String? name,
    AccountType? type,
    double? openingBalance,
    double? balance,
    String? phone,
    String? email,
    String? address,
  }) => Account(
    id: id,
    tenantId: tenantId,
    name: name ?? this.name,
    type: type ?? this.type,
    openingBalance: openingBalance ?? this.openingBalance,
    balance: balance ?? this.balance,
    phone: phone ?? this.phone,
    email: email ?? this.email,
    address: address ?? this.address,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  String get initials => Formats.initials(name);
  bool get hasDue => balance > 0.009;
}
