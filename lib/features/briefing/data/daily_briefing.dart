import '../../../core/utils/json_helpers.dart';

/// One auto-reorder suggestion raised while a briefing was compiled.
class BriefingReorder {
  const BriefingReorder({
    required this.id,
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.status,
    required this.source,
  });

  final String id;
  final String productId;
  final String productName;
  final String sku;
  final double quantity;
  final String status;
  final String source;

  factory BriefingReorder.fromJson(Map<String, dynamic> json) =>
      BriefingReorder(
        id: asString(json['id']),
        productId: asString(json['product_id']),
        productName: asString(json['product_name'], 'Product'),
        sku: asString(json['sku']),
        quantity: asDouble(json['quantity']),
        status: asString(json['status'], 'pending'),
        source: asString(json['source'], 'auto'),
      );
}

class BriefingTopProduct {
  const BriefingTopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final double quantity;
  final double revenue;

  factory BriefingTopProduct.fromJson(Map<String, dynamic> json) =>
      BriefingTopProduct(
        name: asString(json['name'], 'Product'),
        quantity: asDouble(json['quantity']),
        revenue: asDouble(json['revenue']),
      );
}

class BriefingLowStock {
  const BriefingLowStock({
    required this.id,
    required this.name,
    required this.sku,
    required this.unit,
    required this.stockQty,
    required this.threshold,
  });

  final String id;
  final String name;
  final String sku;
  final String unit;
  final double stockQty;
  final int threshold;

  factory BriefingLowStock.fromJson(Map<String, dynamic> json) =>
      BriefingLowStock(
        id: asString(json['id']),
        name: asString(json['name'], 'Product'),
        sku: asString(json['sku']),
        unit: asString(json['unit'], 'pcs'),
        stockQty: asDouble(json['stock_qty']),
        threshold: asInt(json['low_stock_threshold']),
      );
}

/// The structured numeric snapshot the AI narrative is based on.
class BriefingMetrics {
  const BriefingMetrics({
    required this.businessName,
    required this.currency,
    required this.currencySymbol,
    required this.salesCount,
    required this.revenue,
    required this.costOfGoods,
    required this.grossProfit,
    required this.expenses,
    required this.netProfit,
    required this.cashCollected,
    required this.newCredit,
    required this.receivables,
    required this.payables,
    required this.reorderCount,
    required this.topProducts,
    required this.lowStock,
    required this.reorders,
    required this.previousRevenue,
    required this.previousNetProfit,
  });

  final String businessName;
  final String currency;
  final String currencySymbol;
  final int salesCount;
  final double revenue;
  final double costOfGoods;
  final double grossProfit;
  final double expenses;
  final double netProfit;
  final double cashCollected;
  final double newCredit;
  final double receivables;
  final double payables;
  final int reorderCount;
  final List<BriefingTopProduct> topProducts;
  final List<BriefingLowStock> lowStock;
  final List<BriefingReorder> reorders;
  final double previousRevenue;
  final double previousNetProfit;

  static const BriefingMetrics empty = BriefingMetrics(
    businessName: '',
    currency: '',
    currencySymbol: 'Rs',
    salesCount: 0,
    revenue: 0,
    costOfGoods: 0,
    grossProfit: 0,
    expenses: 0,
    netProfit: 0,
    cashCollected: 0,
    newCredit: 0,
    receivables: 0,
    payables: 0,
    reorderCount: 0,
    topProducts: [],
    lowStock: [],
    reorders: [],
    previousRevenue: 0,
    previousNetProfit: 0,
  );

  factory BriefingMetrics.fromJson(Map<String, dynamic> json) {
    final sales = _map(json['sales']);
    final expenses = _map(json['expenses']);
    final previous = _map(json['previous']);

    return BriefingMetrics(
      businessName: asString(json['business_name']),
      currency: asString(json['currency']),
      currencySymbol: asString(json['currency_symbol'], 'Rs'),
      salesCount: asInt(sales['count']),
      revenue: asDouble(sales['revenue']),
      costOfGoods: asDouble(sales['cost_of_goods']),
      grossProfit: asDouble(sales['gross_profit']),
      expenses: asDouble(expenses['total']),
      netProfit: asDouble(json['net_profit']),
      cashCollected: asDouble(json['cash_collected']),
      newCredit: asDouble(json['new_credit']),
      receivables: asDouble(json['receivables']),
      payables: asDouble(json['payables']),
      reorderCount: asInt(json['reorder_count']),
      topProducts: _objects(json['top_products'])
          .map(BriefingTopProduct.fromJson)
          .toList(growable: false),
      lowStock: _objects(json['low_stock'])
          .map(BriefingLowStock.fromJson)
          .toList(growable: false),
      reorders: _objects(json['reorders'])
          .map(BriefingReorder.fromJson)
          .toList(growable: false),
      previousRevenue: asDouble(previous['revenue']),
      previousNetProfit: asDouble(previous['net_profit']),
    );
  }

  Map<String, dynamic> toJson() => {
    'business_name': businessName,
    'currency': currency,
    'currency_symbol': currencySymbol,
    'sales': {
      'count': salesCount,
      'revenue': revenue,
      'cost_of_goods': costOfGoods,
      'gross_profit': grossProfit,
    },
    'expenses': {
      'total': expenses,
    },
    'net_profit': netProfit,
    'cash_collected': cashCollected,
    'new_credit': newCredit,
    'receivables': receivables,
    'payables': payables,
    'reorder_count': reorderCount,
    'top_products': [
      for (final product in topProducts)
        {
          'name': product.name,
          'quantity': product.quantity,
          'revenue': product.revenue,
        },
    ],
    'low_stock': [
      for (final product in lowStock)
        {
          'id': product.id,
          'name': product.name,
          'sku': product.sku,
          'unit': product.unit,
          'stock_qty': product.stockQty,
          'low_stock_threshold': product.threshold,
        },
    ],
    'reorders': [
      for (final reorder in reorders)
        {
          'id': reorder.id,
          'product_id': reorder.productId,
          'product_name': reorder.productName,
          'sku': reorder.sku,
          'quantity': reorder.quantity,
          'status': reorder.status,
          'source': reorder.source,
        },
    ],
    'previous': {
      'revenue': previousRevenue,
      'net_profit': previousNetProfit,
    },
  };

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static List<Map<String, dynamic>> _objects(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

/// A stored daily executive briefing: the deterministic snapshot plus the
/// narrative (AI-written in cloud mode, locally drafted in the demo).
class DailyBriefing {
  const DailyBriefing({
    required this.id,
    required this.tenantId,
    required this.date,
    required this.timezone,
    required this.headline,
    required this.summary,
    required this.highlights,
    required this.recommendations,
    required this.metrics,
    required this.source,
    this.model,
    required this.isManual,
    required this.generatedAt,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final DateTime date;
  final String timezone;
  final String headline;
  final String summary;
  final List<String> highlights;
  final List<String> recommendations;
  final BriefingMetrics metrics;

  /// `gemini`, `fallback` or `local`.
  final String source;
  final String? model;
  final bool isManual;
  final DateTime generatedAt;
  final DateTime createdAt;

  factory DailyBriefing.fromJson(Map<String, dynamic> json) => DailyBriefing(
    id: asString(json['id']),
    tenantId: asString(json['tenant_id']),
    date: asDate(json['summary_date']),
    timezone: asString(json['timezone'], 'UTC'),
    headline: asString(json['headline']),
    summary: asString(json['summary']),
    highlights: _strings(json['highlights']),
    recommendations: _strings(json['recommendations']),
    metrics: BriefingMetrics.fromJson(_map(json['metrics'])),
    source: asString(json['source'], 'local'),
    model: asNullableString(json['model']),
    isManual: asBool(json['is_manual']),
    generatedAt: asDate(json['generated_at']),
    createdAt: asDate(json['created_at']),
  );

  Map<String, dynamic> toJson({String? id}) => {
    if (id != null) 'id': id,
    'tenant_id': tenantId,
    'summary_date': toIsoDate(date),
    'timezone': timezone,
    'headline': headline,
    'summary': summary,
    'highlights': highlights,
    'recommendations': recommendations,
    'metrics': metrics.toJson(),
    'source': source,
    'model': model,
    'is_manual': isManual,
    'generated_at': toIso(generatedAt),
    'created_at': toIso(createdAt),
  };

  String get sourceLabel => switch (source) {
    'gemini' => 'AI written',
    'fallback' => 'AI fallback',
    'local' => 'Demo draft',
    _ => source,
  };

  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String get dateKey => toIsoDate(date);

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => asString(item).trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}
