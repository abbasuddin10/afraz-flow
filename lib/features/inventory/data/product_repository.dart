import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../notifications/data/low_stock_notifier.dart';
import 'product.dart';

class ProductRepository {
  ProductRepository(this._store, this._session);

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;

  Future<List<Product>> all({bool includeInactive = false}) async {
    final rows = await _store.select(
      'products',
      eq: {
        'tenant_id': _session.requireTenantId(),
        if (!includeInactive) 'is_active': true,
      },
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(Product.fromJson).toList();
  }

  Future<List<Product>> lowStock() async {
    final products = await all();
    return products.where((product) => product.isLowStock).toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));
  }

  Future<Product?> findByBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final byBarcode = await _store.select(
      'products',
      eq: {
        'tenant_id': _session.requireTenantId(),
        'barcode': trimmed,
        'is_active': true,
      },
      limit: 1,
    );
    if (byBarcode.isNotEmpty) return Product.fromJson(byBarcode.first);
    final bySku = await _store.select(
      'products',
      eq: {
        'tenant_id': _session.requireTenantId(),
        'sku': trimmed.toUpperCase(),
        'is_active': true,
      },
      limit: 1,
    );
    return bySku.isEmpty ? null : Product.fromJson(bySku.first);
  }

  Future<String> nextSku(String name) async {
    final count = await _store.select(
      'products',
      eq: {'tenant_id': _session.requireTenantId()},
    );
    return Formats.sku(name, count.length + 1);
  }

  Future<Product> create(Product product) async {
    final tenantId = _session.requireTenantId();
    if (product.name.trim().isEmpty) {
      throw const AppFailure('Product name is required.');
    }
    if (product.salePrice < 0 || product.costPrice < 0) {
      throw const AppFailure('Prices cannot be negative.');
    }
    final duplicate = await _store.select(
      'products',
      eq: {'tenant_id': tenantId, 'sku': product.sku.toUpperCase()},
      limit: 1,
    );
    if (duplicate.isNotEmpty) {
      throw const AppFailure('A product with this SKU already exists.');
    }
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final barcodeExists = await _store.select(
        'products',
        eq: {'tenant_id': tenantId, 'barcode': product.barcode},
        limit: 1,
      );
      if (barcodeExists.isNotEmpty) {
        throw const AppFailure('This barcode is already assigned.');
      }
    }
    final row = await _store.insert('products', product.toJson());
    final created = Product.fromJson(row);
    await LowStockNotifier.notify(_store, _session, created);
    return created;
  }

  Future<Product> update(Product product) async {
    final duplicate = await _store.select(
      'products',
      eq: {
        'tenant_id': _session.requireTenantId(),
        'sku': product.sku.toUpperCase(),
      },
      limit: 2,
    );
    if (duplicate.any((row) => asString(row['id']) != product.id)) {
      throw const AppFailure('A product with this SKU already exists.');
    }
    final row = await _store.update('products', product.id, product.toJson());
    final updated = Product.fromJson(row);
    await LowStockNotifier.notify(_store, _session, updated);
    return updated;
  }

  Future<void> archive(Product product) async {
    await _store.update('products', product.id, {
      'is_active': false,
      'updated_at': toIso(DateTime.now()),
    });
  }

  Future<Product> adjustStock({
    required Product product,
    required double quantity,
    required StockMovementType type,
    String note = '',
    String? reference,
  }) async {
    if (quantity <= 0) {
      throw const AppFailure('Enter a quantity greater than zero.');
    }
    final delta = type == StockMovementType.outbound ? -quantity : quantity;
    final newStock = type == StockMovementType.adjustment
        ? quantity
        : product.stockQty + delta;
    if (newStock < 0) {
      throw const AppFailure('This would reduce stock below zero.');
    }

    if (_store.isRemote) {
      final result = await _store.rpc('adjust_stock', {
        'p_tenant_id': _session.requireTenantId(),
        'p_product_id': product.id,
        'p_quantity': type == StockMovementType.adjustment
            ? newStock
            : quantity,
        'p_type': type.value,
        'p_note': note,
        'p_reference': reference,
      });
      final updated = await _store.findById('products', product.id);
      if (updated == null) {
        throw const AppFailure('Product could not be reloaded.');
      }
      if (result == null) return Product.fromJson(updated);
      return Product.fromJson(updated);
    }

    final updated = product.copyWith(stockQty: newStock);
    await _store.update('products', product.id, updated.toJson());
    await _store.insert(
      'stock_movements',
      StockMovement(
        id: _uuid.v4(),
        tenantId: _session.requireTenantId(),
        productId: product.id,
        productName: product.name,
        type: type,
        quantity: quantity,
        note: note,
        reference: reference,
        createdAt: DateTime.now(),
      ).toJson(),
    );
    await LowStockNotifier.notify(_store, _session, updated);
    return updated;
  }

  Future<List<StockMovement>> movements({String? productId, int? limit}) async {
    final rows = await _store.select(
      'stock_movements',
      eq: {
        'tenant_id': _session.requireTenantId(),
        if (productId != null) 'product_id': productId,
      },
      orderBy: 'created_at',
      limit: limit ?? 100,
    );
    return rows.map(StockMovement.fromJson).toList();
  }

  Future<List<String>> categories() async {
    final products = await all();
    final values = products
        .map((product) => product.category.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return values;
  }
}
