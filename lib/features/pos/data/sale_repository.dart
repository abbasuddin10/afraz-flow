import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/models/account.dart';
import '../../../../core/models/ledger_entry.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../inventory/data/product.dart';
import '../data/sale.dart';

class SaleRepository {
  SaleRepository(this._store, this._session);

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;

  /// Creates a sale, its line items, stock movements and (for unpaid balances)
  /// a ledger charge. On Supabase the whole operation is a single database
  /// function so a network failure cannot leave stock partially updated.
  Future<Sale> checkout({
    required List<CartLine> lines,
    required PaymentMethod method,
    required double discount,
    required double taxRate,
    required String? accountId,
    required String customerName,
    required double paidAmount,
    String? note,
  }) async {
    if (lines.isEmpty) {
      throw const AppFailure('Add at least one product to the cart.');
    }
    final tenantId = _session.requireTenantId();
    final now = DateTime.now();
    final saleId = _uuid.v4();
    final invoiceNo = Formats.invoiceNumber(now);
    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotal);
    final safeDiscount = discount.clamp(0, subtotal).toDouble();
    final tax = double.parse(
      ((subtotal - safeDiscount) * (taxRate / 100)).toStringAsFixed(2),
    );
    final total = double.parse(
      (subtotal - safeDiscount + tax).toStringAsFixed(2),
    );
    final paid = paidAmount.clamp(0, total).toDouble();
    final due = double.parse((total - paid).toStringAsFixed(2));

    if (due > 0.009 && (accountId == null || accountId.isEmpty)) {
      throw const AppFailure(
        'Select a customer account to record the outstanding balance.',
      );
    }
    if (method == PaymentMethod.credit &&
        (accountId == null || accountId.isEmpty)) {
      throw const AppFailure('Credit sales require a customer account.');
    }

    final sale = Sale(
      id: saleId,
      tenantId: tenantId,
      invoiceNo: invoiceNo,
      accountId: accountId,
      customerName: customerName.trim().isEmpty
          ? 'Walk-in customer'
          : customerName.trim(),
      subtotal: subtotal,
      discount: safeDiscount,
      tax: tax,
      total: total,
      paidAmount: paid,
      dueAmount: due,
      paymentMethod: method,
      status: SaleStatus.completed,
      note: note?.trim().isEmpty == true ? null : note?.trim(),
      createdAt: now,
    );

    final items = <SaleItem>[];
    var index = 0;
    for (final line in lines) {
      index++;
      items.add(
        SaleItem(
          id: '${saleId}_$index',
          saleId: saleId,
          productId: line.productId,
          productName: line.name,
          sku: line.sku,
          quantity: line.quantity,
          unitPrice: line.unitPrice,
          costPrice: line.costPrice,
          lineTotal: line.lineTotal,
        ),
      );
    }

    if (_store.isRemote) {
      await _store.rpc('checkout_sale', {
        'p_tenant_id': tenantId,
        'p_sale_id': saleId,
        'p_invoice_no': invoiceNo,
        'p_account_id': accountId,
        'p_customer_name': sale.customerName,
        'p_subtotal': subtotal,
        'p_discount': safeDiscount,
        'p_tax': tax,
        'p_total': total,
        'p_paid_amount': paid,
        'p_payment_method': method.value,
        'p_note': sale.note,
        'p_items': items.map((item) => item.toJson()).toList(),
      });
      final hydrated = await byId(saleId);
      return hydrated ?? sale.copyWith(items: items);
    }

    // Local backend: emulate the database function with ordered writes.
    // Validate every line before writing so a rejected checkout never leaves a
    // partially recorded sale behind.
    final stockBefore = <String, Product>{};
    for (final line in lines) {
      final productRows = await _store.select(
        'products',
        eq: {'id': line.productId, 'tenant_id': tenantId},
        limit: 1,
      );
      if (productRows.isEmpty) {
        throw AppFailure('Product ${line.name} no longer exists.');
      }
      final product = Product.fromJson(productRows.first);
      if (product.stockQty < line.quantity) {
        throw AppFailure('Not enough stock for ${product.name}.');
      }
      stockBefore[product.id] = product;
    }

    await _store.insert('sales', sale.toJson());
    for (final item in items) {
      await _store.insert('sale_items', item.toJson());
      final product = stockBefore[item.productId]!;
      await _store.update('products', product.id, {
        'stock_qty': product.stockQty - item.quantity,
        'updated_at': toIso(now),
      });
      await _store.insert(
        'stock_movements',
        StockMovement(
          id: _uuid.v4(),
          tenantId: tenantId,
          productId: product.id,
          productName: product.name,
          type: StockMovementType.outbound,
          quantity: item.quantity,
          note: 'Sold on $invoiceNo',
          reference: invoiceNo,
          createdAt: now,
        ).toJson(),
      );
    }

    if (accountId != null && due > 0.009) {
      final accountRows = await _store.select(
        'ledger_accounts',
        eq: {'id': accountId, 'tenant_id': tenantId},
        limit: 1,
      );
      if (accountRows.isEmpty) {
        throw const AppFailure('Customer account could not be found.');
      }
      final account = Account.fromJson(accountRows.first);
      await _store.update('ledger_accounts', account.id, {
        'balance': account.balance + due,
        'updated_at': toIso(now),
      });
      await _store.insert(
        'ledger_entries',
        LedgerEntry(
          id: _uuid.v4(),
          tenantId: tenantId,
          accountId: account.id,
          type: LedgerEntryType.charge,
          amount: due,
          description: 'Credit sale — $invoiceNo',
          reference: invoiceNo,
          entryDate: now,
          createdAt: now,
        ).toJson(),
      );
    }

    return sale.copyWith(items: items);
  }

  Future<List<Sale>> recent({int limit = 50}) async {
    final rows = await _store.select(
      'sales',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'created_at',
      limit: limit,
    );
    return _hydrate(rows);
  }

  Future<List<Sale>> all({int limit = 500}) async {
    final rows = await _store.select(
      'sales',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'created_at',
      limit: limit,
    );
    return _hydrate(rows);
  }

  Future<Sale?> byId(String id) async {
    final row = await _store.findById('sales', id);
    if (row == null) return null;
    final items = await _itemsFor([id]);
    return Sale.fromJson(row, items: items[id] ?? []);
  }

  Future<List<Sale>> between(DateTime from, DateTime to) async {
    final rows = await _store.select(
      'sales',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'created_at',
      limit: 1000,
    );
    final filtered = rows.where((row) {
      final date = asDate(row['created_at']);
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList();
    return _hydrate(filtered);
  }

  Future<Map<String, List<SaleItem>>> _itemsFor(List<String> saleIds) async {
    if (saleIds.isEmpty) return {};
    final rows = await _store.select(
      'sale_items',
      eq: {'tenant_id': _session.requireTenantId()},
      inFilter: {'sale_id': saleIds.cast<Object?>()},
      limit: 2000,
    );
    final map = <String, List<SaleItem>>{};
    for (final row in rows) {
      final item = SaleItem.fromJson(row);
      map.putIfAbsent(item.saleId, () => []).add(item);
    }
    return map;
  }

  Future<List<Sale>> _hydrate(List<Row> rows) async {
    if (rows.isEmpty) return [];
    final items = await _itemsFor(
      rows.map((row) => asString(row['id'])).toList(),
    );
    return rows.map((row) {
      final id = asString(row['id']);
      return Sale.fromJson(row, items: items[id] ?? []);
    }).toList();
  }
}
