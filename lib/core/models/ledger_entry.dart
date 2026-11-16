import '../utils/json_helpers.dart';

enum LedgerEntryType {
  charge,
  payment;

  static LedgerEntryType fromValue(dynamic value) =>
      value?.toString().toLowerCase() == 'payment'
      ? LedgerEntryType.payment
      : LedgerEntryType.charge;

  String get value => name;
  String get label => this == LedgerEntryType.charge ? 'Charge' : 'Payment';

  /// A charge increases what the contact owes, a payment reduces it.
  double apply(double balance, double amount) => this == LedgerEntryType.charge
      ? balance + amount
      : balance - amount;
}

class LedgerEntry {
  const LedgerEntry({
    required this.id,
    required this.tenantId,
    required this.accountId,
    required this.type,
    required this.amount,
    required this.entryDate,
    this.description = '',
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String accountId;
  final LedgerEntryType type;
  final double amount;
  final DateTime entryDate;
  final String description;
  final String? reference;
  final DateTime createdAt;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) => LedgerEntry(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    accountId: asString(json['account_id']),
    type: LedgerEntryType.fromValue(json['entry_type'] ?? json['type']),
    amount: asDouble(json['amount']),
    entryDate: asDate(json['entry_date']),
    description: asString(json['description']),
    reference: asNullableString(json['reference']),
    createdAt: asDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'account_id': accountId,
    'entry_type': type.value,
    'amount': amount,
    'entry_date': toIsoDate(entryDate),
    'description': description.trim(),
    'reference': reference,
    'created_at': toIso(createdAt),
  };
}
