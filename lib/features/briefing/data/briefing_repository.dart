import 'dart:convert';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/data/data_store.dart';
import '../../../core/models/account.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/json_helpers.dart';
import '../../inventory/data/product.dart';
import '../../ledger/data/expense.dart';
import '../../pos/data/sale.dart';
import 'daily_briefing.dart';

/// Reads and generates daily executive briefings.
///
/// In cloud mode the heavy lifting happens in the `daily-briefing` Edge
/// Function: it raises reorders, compiles the snapshot, calls Gemini and stores
/// the result. The local demo mirrors the same pipeline with deterministic
/// numbers and an offline narrative so the feature can be evaluated without
/// credentials.
class BriefingRepository {
  BriefingRepository(this._store, this._session, {SupabaseClient? client})
    : _client = client;

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;
  final SupabaseClient? _client;

  bool get isRemote => _store.isRemote && _client != null;

  Future<List<DailyBriefing>> history({int limit = 90}) async {
    final rows = await _store.select(
      'daily_summaries',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'summary_date',
      limit: limit,
    );
    return rows.map(DailyBriefing.fromJson).toList(growable: false);
  }

  Future<DailyBriefing?> latest() async {
    final rows = await history(limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Generates today's briefing (or [date] when supplied).
  Future<DailyBriefing> generate({DateTime? date}) async {
    final tenantId = _session.requireTenantId();
    final tenant = _session.tenant;
    final timezone = tenant?.dailyBriefingTimezone.trim().isNotEmpty == true
        ? tenant!.dailyBriefingTimezone
        : 'UTC';
    final day = date == null ? null : _dayOnly(date);

    if (isRemote) {
      return _generateRemote(
        tenantId: tenantId,
        timezone: timezone,
        date: day,
      );
    }
    return _generateLocal(
      tenantId: tenantId,
      timezone: timezone,
      date: day ?? _dayOnly(DateTime.now()),
    );
  }

  // ---------------------------------------------------------------------------
  // Cloud mode
  // ---------------------------------------------------------------------------

  Future<DailyBriefing> _generateRemote({
    required String tenantId,
    required String timezone,
    required DateTime? date,
  }) async {
    final client = _client!;
    try {
      final response = await client.functions.invoke(
        'daily-briefing',
        body: {
          'tenant_id': tenantId,
          'timezone': timezone,
          if (date != null) 'summary_date': toIsoDate(date),
          'locale': Formats.locale.toLanguageTag(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw AppFailure(_functionError(response.data, response.status));
      }

      final data = _decode(response.data);
      if (data['error'] != null) {
        throw AppFailure(_functionError(data, response.status));
      }
      return DailyBriefing.fromJson(data);
    } on FunctionException catch (error) {
      throw AppFailure(_functionError(error.details, error.status));
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  Map<String, dynamic> _decode(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const AppFailure('The briefing service returned an unexpected response.');
  }

  String _functionError(dynamic details, int status) {
    dynamic data = details;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        // Keep the raw string below.
      }
    }
    if (data is Map) {
      final error = data['error']?.toString().trim() ?? '';
      final detail = data['detail']?.toString().trim() ?? '';
      if (error.isNotEmpty) {
        return detail.isEmpty ? error : '$error\n$detail';
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return 'The daily briefing could not be generated ($status). '
        'Make sure the daily-briefing Edge Function is deployed.';
  }

  // ---------------------------------------------------------------------------
  // Local demo mode
  // ---------------------------------------------------------------------------

  Future<DailyBriefing> _generateLocal({
    required String tenantId,
    required String timezone,
    required DateTime date,
  }) async {
    final tenant = _session.tenant;
    final createdAt = DateTime.now();
    final dateKey = toIsoDate(date);

    await _raiseLocalReorders(tenantId: tenantId, dateKey: dateKey);

    final metrics = await _localMetrics(
      tenantId: tenantId,
      date: date,
      dateKey: dateKey,
      businessName: tenant?.name ?? 'Your business',
      currency: tenant?.currency ?? 'PKR',
      currencySymbol: tenant?.currencySymbol ?? 'Rs',
    );
    final narrative = _localNarrative(metrics);

    final existing = await _store.select(
      'daily_summaries',
      eq: {'tenant_id': tenantId, 'summary_date': dateKey},
      limit: 1,
    );

    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'summary_date': dateKey,
      'timezone': timezone,
      'headline': narrative.headline,
      'summary': narrative.summary,
      'highlights': narrative.highlights,
      'recommendations': narrative.recommendations,
      'metrics': metrics.toJson(),
      'source': 'local',
      'model': null,
      'is_manual': true,
      'generated_at': toIso(createdAt),
      'created_by': _session.userId.isEmpty ? null : _session.userId,
      'updated_at': toIso(createdAt),
    };

    final row = existing.isEmpty
        ? await _store.insert('daily_summaries', {
            ...payload,
            'id': _uuid.v4(),
            'created_at': toIso(createdAt),
          })
        : await _store.update('daily_summaries', existing.first['id'] as String, payload);

    final briefing = DailyBriefing.fromJson(row);
    await _notifyLocally(briefing);
    return briefing;
  }

  Future<void> _raiseLocalReorders({
    required String tenantId,
    required String dateKey,
  }) async {
    final rows = await _store.select(
      'products',
      eq: {'tenant_id': tenantId},
    );
    final products = rows.map(Product.fromJson);

    for (final product in products) {
      if (!product.isActive || !product.isLowStock) continue;
      final existing = await _store.select(
        'inventory_reorders',
        eq: {
          'tenant_id': tenantId,
          'product_id': product.id,
          'reorder_date': dateKey,
        },
        limit: 1,
      );
      if (existing.isNotEmpty) continue;

      final quantity = math.max(
        ((product.lowStockThreshold * 2) - product.stockQty).ceilToDouble(),
        1,
      );
      await _store.insert('inventory_reorders', {
        'id': _uuid.v4(),
        'tenant_id': tenantId,
        'product_id': product.id,
        'product_name': product.name,
        'sku': product.sku,
        'quantity': quantity,
        'status': 'pending',
        'source': 'auto',
        'note': 'Auto-reorder: stock is at or below the alert threshold',
        'reorder_date': dateKey,
        'created_at': toIso(DateTime.now()),
        'updated_at': toIso(DateTime.now()),
      });
    }
  }

  Future<BriefingMetrics> _localMetrics({
    required String tenantId,
    required DateTime date,
    required String dateKey,
    required String businessName,
    required String currency,
    required String currencySymbol,
  }) async {
    final start = _dayOnly(date);
    final end = start.add(const Duration(days: 1));
    final previousStart = start.subtract(const Duration(days: 1));
    final previousKey = toIsoDate(previousStart);

    final salesRows = await _store.select(
      'sales',
      eq: {'tenant_id': tenantId},
      orderBy: 'created_at',
      limit: 2000,
    );
    final itemRows = await _store.select(
      'sale_items',
      eq: {'tenant_id': tenantId},
      limit: 5000,
    );
    final expenseRows = await _store.select(
      'expenses',
      eq: {'tenant_id': tenantId},
      limit: 2000,
    );
    final accountRows = await _store.select(
      'ledger_accounts',
      eq: {'tenant_id': tenantId},
    );
    final ledgerRows = await _store.select(
      'ledger_entries',
      eq: {'tenant_id': tenantId},
      limit: 5000,
    );
    final productRows = await _store.select(
      'products',
      eq: {'tenant_id': tenantId},
    );
    final reorderRows = await _store.select(
      'inventory_reorders',
      eq: {'tenant_id': tenantId, 'reorder_date': dateKey},
      orderBy: 'created_at',
      ascending: true,
    );

    bool inWindow(DateTime value, DateTime from, DateTime to) =>
        !value.isBefore(from) && value.isBefore(to);

    final itemsBySale = <String, List<SaleItem>>{};
    for (final row in itemRows) {
      final item = SaleItem.fromJson(row);
      itemsBySale.putIfAbsent(item.saleId, () => []).add(item);
    }

    final daySales = salesRows
        .map((row) => Sale.fromJson(row, items: itemsBySale[asString(row['id'])] ?? const []))
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              inWindow(sale.createdAt, start, end),
        )
        .toList();

    final previousSales = salesRows
        .map((row) => Sale.fromJson(row, items: itemsBySale[asString(row['id'])] ?? const []))
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              inWindow(sale.createdAt, previousStart, start),
        )
        .toList();

    final expenses = expenseRows.map(Expense.fromJson).toList();
    final dayExpenses = expenses
        .where((expense) => toIsoDate(expense.expenseDate) == dateKey)
        .fold<double>(0, (sum, expense) => sum + expense.amount);
    final previousExpenses = expenses
        .where((expense) => toIsoDate(expense.expenseDate) == previousKey)
        .fold<double>(0, (sum, expense) => sum + expense.amount);

    final ledger = ledgerRows.map(LedgerEntry.fromJson).toList();
    final ledgerCollected = ledger
        .where(
          (entry) =>
              entry.type == LedgerEntryType.payment &&
              inWindow(entry.createdAt, start, end),
        )
        .fold<double>(0, (sum, entry) => sum + entry.amount);

    final accounts = accountRows.map(Account.fromJson).toList();
    final receivables = accounts
        .where((account) => account.type == AccountType.customer)
        .fold<double>(0, (sum, account) => sum + account.balance);
    final payables = accounts
        .where((account) => account.type == AccountType.supplier)
        .fold<double>(0, (sum, account) => sum + account.balance);

    final revenue = daySales.fold<double>(0, (sum, sale) => sum + sale.total);
    final costOfGoods = daySales.fold<double>(0, (sum, sale) => sum + sale.totalCost);
    final paid = daySales.fold<double>(0, (sum, sale) => sum + sale.paidAmount);
    final newCredit = daySales.fold<double>(0, (sum, sale) => sum + sale.dueAmount);

    final previousRevenue = previousSales.fold<double>(
      0,
      (sum, sale) => sum + sale.total,
    );
    final previousCost = previousSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalCost,
    );

    final topStats = <String, BriefingTopProduct>{};
    for (final sale in daySales) {
      for (final item in sale.items) {
        final key = item.productId.isEmpty ? item.productName : item.productId;
        final existing = topStats[key];
        topStats[key] = BriefingTopProduct(
          name: item.productName,
          quantity: (existing?.quantity ?? 0) + item.quantity,
          revenue: (existing?.revenue ?? 0) + item.lineTotal,
        );
      }
    }
    final topProducts = topStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final lowStock = productRows
        .map(Product.fromJson)
        .where((product) => product.isActive && product.isLowStock)
        .toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

    final reorders = reorderRows.map(BriefingReorder.fromJson).toList();

    return BriefingMetrics(
      businessName: businessName,
      currency: currency,
      currencySymbol: currencySymbol,
      salesCount: daySales.length,
      revenue: revenue,
      costOfGoods: costOfGoods,
      grossProfit: revenue - costOfGoods,
      expenses: dayExpenses,
      netProfit: revenue - costOfGoods - dayExpenses,
      cashCollected: paid + ledgerCollected,
      newCredit: newCredit,
      receivables: receivables,
      payables: payables,
      reorderCount: reorders.length,
      topProducts: topProducts.take(5).toList(growable: false),
      lowStock: lowStock
          .take(20)
          .map(
            (product) => BriefingLowStock(
              id: product.id,
              name: product.name,
              sku: product.sku,
              unit: product.unit,
              stockQty: product.stockQty,
              threshold: product.lowStockThreshold,
            ),
          )
          .toList(growable: false),
      reorders: reorders,
      previousRevenue: previousRevenue,
      previousNetProfit: previousRevenue - previousCost - previousExpenses,
    );
  }

  _LocalNarrative _localNarrative(BriefingMetrics metrics) {
    final symbol = metrics.currencySymbol;
    String money(num value) => Formats.currency(value, symbol: symbol);
    final count = metrics.salesCount;
    final plural = count == 1 ? '' : 's';

    final summary = count == 0
        ? 'No completed sales were recorded for this business day. '
              'Expenses were ${money(metrics.expenses)}, leaving a net result '
              'of ${money(metrics.netProfit)}.'
        : 'You completed $count sale$plural for ${money(metrics.revenue)} in '
              'revenue. After ${money(metrics.expenses)} in expenses, net '
              'profit was ${money(metrics.netProfit)}.';

    final highlights = <String>[
      '$count sale$plural · ${money(metrics.revenue)} revenue',
      'Cash collected ${money(metrics.cashCollected)} · '
          'new credit ${money(metrics.newCredit)}',
      '${metrics.lowStock.length} product'
          '${metrics.lowStock.length == 1 ? '' : 's'} low on stock'
          '${metrics.reorders.isEmpty ? '' : ' · ${metrics.reorders.length} '
                    'reorder${metrics.reorders.length == 1 ? '' : 's'} created'}',
    ];
    if (metrics.topProducts.isNotEmpty) {
      highlights.add(
        'Best sellers: ${metrics.topProducts.take(3).map((product) => product.name).join(', ')}',
      );
    }
    if (metrics.previousRevenue > 0) {
      highlights.add(
        'Previous day: ${money(metrics.previousRevenue)} revenue · '
        '${money(metrics.previousNetProfit)} net profit',
      );
    }

    final recommendations = <String>[];
    if (metrics.lowStock.isNotEmpty) {
      recommendations.add('Confirm the auto-reorders for low-stock products.');
    }
    if (metrics.receivables > 0) {
      recommendations.add(
        'Collect part of the ${money(metrics.receivables)} outstanding from customers.',
      );
    }
    if (metrics.payables > 0) {
      recommendations.add(
        'Plan for ${money(metrics.payables)} payable to suppliers.',
      );
    }
    if (metrics.expenses > metrics.revenue && count > 0) {
      recommendations.add(
        'Expenses exceeded revenue — review the largest expense lines.',
      );
    }
    if (recommendations.isEmpty) {
      recommendations.add("Keep the momentum going and prepare tomorrow's stock.");
    }

    return _LocalNarrative(
      headline: count == 0
          ? 'A quiet day with no sales'
          : '${money(metrics.netProfit)} net profit for the day',
      summary: summary,
      highlights: highlights,
      recommendations: recommendations,
    );
  }

  Future<void> _notifyLocally(DailyBriefing briefing) async {
    final userId = _session.userId;
    if (userId.isEmpty) return;
    final dedupeKey = 'daily_briefing:${briefing.tenantId}:${briefing.dateKey}';
    final existing = await _store.select(
      'app_notifications',
      eq: {'user_id': userId, 'dedupe_key': dedupeKey},
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    final body =
        'Your Daily Business Briefing for ${_dateLabel(briefing.date)} is '
        'ready. Tap to view.';
    await _store.insert('app_notifications', {
      'id': _uuid.v4(),
      'tenant_id': briefing.tenantId,
      'user_id': userId,
      'title': 'Daily AI Briefing',
      'body': body,
      'kind': 'daily_briefing',
      'reference_id': briefing.id,
      'dedupe_key': dedupeKey,
      'read_at': null,
      'created_at': toIso(DateTime.now()),
    });
  }

  static DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateLabel(DateTime value) =>
      DateFormat('EEEE, d MMMM yyyy').format(value);
}

class _LocalNarrative {
  const _LocalNarrative({
    required this.headline,
    required this.summary,
    required this.highlights,
    required this.recommendations,
  });

  final String headline;
  final String summary;
  final List<String> highlights;
  final List<String> recommendations;
}
