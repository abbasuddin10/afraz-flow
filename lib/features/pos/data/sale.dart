import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';

class SaleItem {
  const SaleItem({
    required this.id,
    required this.saleId,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitPrice,
    required this.costPrice,
    required this.lineTotal,
  });

  final String id;
  final String saleId;
  final String productId;
  final String productName;
  final String sku;
  final double quantity;
  final double unitPrice;
  final double costPrice;
  final double lineTotal;

  factory SaleItem.fromJson(Map<String, dynamic> json) => SaleItem(
    id: asString(json['id']),
    saleId: asString(json['sale_id']),
    productId: asString(json['product_id']),
    productName: asString(json['product_name']),
    sku: asString(json['sku']),
    quantity: asDouble(json['quantity']),
    unitPrice: asDouble(json['unit_price']),
    costPrice: asDouble(json['cost_price']),
    lineTotal: asDouble(json['line_total']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'sale_id': saleId,
    'product_id': productId,
    'product_name': productName,
    'sku': sku,
    'quantity': quantity,
    'unit_price': unitPrice,
    'cost_price': costPrice,
    'line_total': lineTotal,
  };

  double get margin => lineTotal - (costPrice * quantity);
  String get quantityLabel => Formats.number(
    quantity,
    decimals: quantity % 1 == 0 ? 0 : 2,
  );
}

enum PaymentMethod {
  cash,
  card,
  bank,
  credit;

  static PaymentMethod fromValue(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'card':
        return PaymentMethod.card;
      case 'bank':
        return PaymentMethod.bank;
      case 'credit':
        return PaymentMethod.credit;
      default:
        return PaymentMethod.cash;
    }
  }

  String get value => name;
  String get label => switch (this) {
    PaymentMethod.cash => 'Cash',
    PaymentMethod.card => 'Card',
    PaymentMethod.bank => 'Bank transfer',
    PaymentMethod.credit => 'Credit (Khata)',
  };
}

enum SaleStatus {
  completed,
  refunded,
  voided;

  static SaleStatus fromValue(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'refunded':
        return SaleStatus.refunded;
      case 'voided':
        return SaleStatus.voided;
      default:
        return SaleStatus.completed;
    }
  }

  String get value => switch (this) {
    SaleStatus.completed => 'completed',
    SaleStatus.refunded => 'refunded',
    SaleStatus.voided => 'voided',
  };

  String get label => switch (this) {
    SaleStatus.completed => 'Completed',
    SaleStatus.refunded => 'Refunded',
    SaleStatus.voided => 'Voided',
  };
}

class Sale {
  const Sale({
    required this.id,
    required this.tenantId,
    required this.invoiceNo,
    this.accountId,
    required this.customerName,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.total,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    required this.status,
    this.note,
    required this.createdAt,
    this.items = const [],
  });

  final String id;
  final String tenantId;
  final String invoiceNo;
  final String? accountId;
  final String customerName;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final double paidAmount;
  final double dueAmount;
  final PaymentMethod paymentMethod;
  final SaleStatus status;
  final String? note;
  final DateTime createdAt;
  final List<SaleItem> items;

  factory Sale.fromJson(
    Map<String, dynamic> json, {
    List<SaleItem> items = const [],
  }) {
    final rawItems = json['sale_items'];
    final nested = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((row) => SaleItem.fromJson(Map<String, dynamic>.from(row)))
              .toList()
        : <SaleItem>[];
    return Sale(
      id: asString(json['id']),
      tenantId: asString(json['tenant_id']),
      invoiceNo: asString(json['invoice_no']),
      accountId: asNullableString(json['account_id']),
      customerName: asString(json['customer_name'], 'Walk-in customer'),
      subtotal: asDouble(json['subtotal']),
      discount: asDouble(json['discount']),
      tax: asDouble(json['tax']),
      total: asDouble(json['total']),
      paidAmount: asDouble(json['paid_amount']),
      dueAmount: asDouble(json['due_amount']),
      paymentMethod: PaymentMethod.fromValue(json['payment_method']),
      status: SaleStatus.fromValue(json['status']),
      note: asNullableString(json['note']),
      createdAt: asDate(json['created_at']),
      items: items.isNotEmpty ? items : nested,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'invoice_no': invoiceNo,
    'account_id': accountId,
    'customer_name': customerName,
    'subtotal': subtotal,
    'discount': discount,
    'tax': tax,
    'total': total,
    'paid_amount': paidAmount,
    'due_amount': dueAmount,
    'payment_method': paymentMethod.value,
    'status': status.value,
    'note': note,
    'created_at': toIso(createdAt),
    'updated_at': toIso(createdAt),
  };

  Sale copyWith({List<SaleItem>? items, SaleStatus? status}) => Sale(
    id: id,
    tenantId: tenantId,
    invoiceNo: invoiceNo,
    accountId: accountId,
    customerName: customerName,
    subtotal: subtotal,
    discount: discount,
    tax: tax,
    total: total,
    paidAmount: paidAmount,
    dueAmount: dueAmount,
    paymentMethod: paymentMethod,
    status: status ?? this.status,
    note: note,
    createdAt: createdAt,
    items: items ?? this.items,
  );

  double get totalCost =>
      items.fold(0, (total, item) => total + (item.costPrice * item.quantity));
  double get profit => total - tax - totalCost;
  int get itemCount => items.fold(0, (total, item) => total + item.quantity.round());
  bool get hasDue => dueAmount > 0.009;
}

/// A mutable line in the POS cart.
class CartLine {
  const CartLine({
    required this.productId,
    required this.name,
    required this.sku,
    required this.unitPrice,
    required this.costPrice,
    required this.quantity,
    required this.availableStock,
    required this.unit,
  });

  final String productId;
  final String name;
  final String sku;
  final double unitPrice;
  final double costPrice;
  final double quantity;
  final double availableStock;
  final String unit;

  double get lineTotal => unitPrice * quantity;

  CartLine copyWith({double? quantity, double? unitPrice}) => CartLine(
    productId: productId,
    name: name,
    sku: sku,
    unitPrice: unitPrice ?? this.unitPrice,
    costPrice: costPrice,
    quantity: quantity ?? this.quantity,
    availableStock: availableStock,
    unit: unit,
  );
}
