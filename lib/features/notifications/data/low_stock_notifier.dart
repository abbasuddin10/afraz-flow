import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../inventory/data/product.dart';

/// Inserts a dedicated "Low stock alert" notification into the AppBar feed
/// whenever a product drops to or below its minimum threshold.
///
/// Duplicate-spam protection: the dedupe key includes the product and the
/// day, so one alert per product per day no matter how many sales or
/// adjustments happen afterwards (the `app_notifications` table also has a
/// `unique (user_id, dedupe_key)` guard in the cloud).
///
/// In cloud mode the same row is written by the `products_low_stock_notify`
/// Postgres trigger (which also fires for the `checkout_sale`/`adjust_stock`
/// RPCs), so this helper steps aside and only powers the local demo store.
class LowStockNotifier {
  LowStockNotifier._();

  static const Uuid _uuid = Uuid();

  static Future<void> notify(
    DataStore store,
    SessionService session,
    Product product,
  ) async {
    if (store.isRemote) return;
    if (!product.isActive || !product.isLowStock) return;

    final userId = session.userId;
    final tenantId = session.tenantId;
    if (userId.isEmpty || tenantId.isEmpty) return;

    final dedupeKey =
        'low_stock:$tenantId:${product.id}:${_dateKey(DateTime.now())}';
    final existing = await store.select(
      'app_notifications',
      eq: {'user_id': userId, 'dedupe_key': dedupeKey},
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await store.insert('app_notifications', {
      'id': _uuid.v4(),
      'tenant_id': tenantId,
      'user_id': userId,
      'title': 'Low stock alert',
      'body':
          '${product.name} is running low — ${product.stockLabel} left '
          '(alert threshold: ${product.lowStockThreshold}). Reorder soon.',
      'kind': 'low_stock',
      'reference_id': product.id,
      'dedupe_key': dedupeKey,
      'read_at': null,
      'created_at': toIso(DateTime.now()),
    });
  }

  static String _dateKey(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
