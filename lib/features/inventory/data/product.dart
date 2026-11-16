import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';

class Product {
  const Product({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.sku,
    this.barcode,
    required this.category,
    required this.unit,
    required this.costPrice,
    required this.salePrice,
    required this.stockQty,
    required this.lowStockThreshold,
    required this.isActive,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String name;
  final String sku;
  final String? barcode;
  final String category;
  final String unit;
  final double costPrice;
  final double salePrice;
  final double stockQty;
  final int lowStockThreshold;
  final bool isActive;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    name: asString(json['name'], 'Untitled product'),
    sku: asString(json['sku']),
    barcode: asNullableString(json['barcode']),
    category: asString(json['category'], 'Uncategorised'),
    unit: asString(json['unit'], 'pcs'),
    costPrice: asDouble(json['cost_price']),
    salePrice: asDouble(json['sale_price']),
    stockQty: asDouble(json['stock_qty']),
    lowStockThreshold: asInt(json['low_stock_threshold'], 5),
    isActive: asBool(json['is_active'], true),
    imageUrl: asNullableString(json['image_url']),
    createdAt: asDate(json['created_at']),
    updatedAt: asDate(json['updated_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'name': name.trim(),
    'sku': sku.trim().toUpperCase(),
    'barcode': barcode,
    'category': category.trim(),
    'unit': unit,
    'cost_price': costPrice,
    'sale_price': salePrice,
    'stock_qty': stockQty,
    'low_stock_threshold': lowStockThreshold,
    'is_active': isActive,
    'image_url': imageUrl,
    'created_at': toIso(createdAt),
    'updated_at': toIso(updatedAt),
  };

  Product copyWith({
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? unit,
    double? costPrice,
    double? salePrice,
    double? stockQty,
    int? lowStockThreshold,
    bool? isActive,
    String? imageUrl,
  }) => Product(
    id: id,
    tenantId: tenantId,
    name: name ?? this.name,
    sku: sku ?? this.sku,
    barcode: barcode ?? this.barcode,
    category: category ?? this.category,
    unit: unit ?? this.unit,
    costPrice: costPrice ?? this.costPrice,
    salePrice: salePrice ?? this.salePrice,
    stockQty: stockQty ?? this.stockQty,
    lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
    isActive: isActive ?? this.isActive,
    imageUrl: imageUrl ?? this.imageUrl,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  bool get isLowStock => stockQty <= lowStockThreshold;
  bool get isOutOfStock => stockQty <= 0;
  double get stockValue => stockQty * costPrice;
  double get margin {
    if (salePrice <= 0) return 0;
    return ((salePrice - costPrice) / salePrice) * 100;
  }

  String get initials => Formats.initials(name);
  String get stockLabel =>
      '${Formats.number(stockQty, decimals: stockQty % 1 == 0 ? 0 : 2)} $unit';
}

enum StockMovementType {
  inbound,
  outbound,
  adjustment;

  static StockMovementType fromValue(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'in':
        return StockMovementType.inbound;
      case 'out':
        return StockMovementType.outbound;
      default:
        return StockMovementType.adjustment;
    }
  }

  String get value => switch (this) {
    StockMovementType.inbound => 'in',
    StockMovementType.outbound => 'out',
    StockMovementType.adjustment => 'adjustment',
  };

  String get label => switch (this) {
    StockMovementType.inbound => 'Stock in',
    StockMovementType.outbound => 'Stock out',
    StockMovementType.adjustment => 'Adjustment',
  };
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.tenantId,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    this.note = '',
    this.reference,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String productId;
  final String productName;
  final StockMovementType type;
  final double quantity;
  final String note;
  final String? reference;
  final DateTime createdAt;

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    productId: asString(json['product_id']),
    productName: asString(json['product_name']),
    type: StockMovementType.fromValue(json['movement_type']),
    quantity: asDouble(json['quantity']),
    note: asString(json['note']),
    reference: asNullableString(json['reference']),
    createdAt: asDate(json['created_at']),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'product_id': productId,
    'product_name': productName,
    'movement_type': type.value,
    'quantity': quantity,
    'note': note.trim(),
    'reference': reference,
    'created_at': toIso(createdAt),
  };

  bool get increasesStock => type != StockMovementType.outbound;
}
