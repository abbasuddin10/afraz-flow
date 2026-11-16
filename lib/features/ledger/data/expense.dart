import '../../../../core/utils/json_helpers.dart';

class Expense {
  const Expense({
    required this.id,
    required this.tenantId,
    required this.category,
    required this.description,
    required this.amount,
    required this.paymentMethod,
    required this.expenseDate,
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String category;
  final String description;
  final double amount;
  final String paymentMethod;
  final DateTime expenseDate;
  final String? reference;
  final DateTime createdAt;

  static const List<String> categories = [
    'Rent',
    'Utilities',
    'Salaries',
    'Logistics',
    'Packaging',
    'Marketing',
    'Maintenance',
    'Purchases',
    'Taxes',
    'Other',
  ];

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    category: asString(json['category'], 'Other'),
    description: asString(json['description']),
    amount: asDouble(json['amount']),
    paymentMethod: asString(json['payment_method'], 'cash'),
    expenseDate: asDate(json['expense_date']),
    reference: asNullableString(json['reference']),
    createdAt: asDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'category': category,
    'description': description.trim(),
    'amount': amount,
    'payment_method': paymentMethod,
    'expense_date': toIsoDate(expenseDate),
    'reference': reference,
    'created_at': toIso(createdAt),
  };
}
