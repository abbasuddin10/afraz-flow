import '../../../../core/data/data_store.dart';
import '../../../../core/data/local_data_store.dart';
import '../../../../core/data/routing_data_store.dart';
import '../../../../core/models/tenant.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/json_helpers.dart';

class SettingsRepository {
  SettingsRepository(this._store, this._session);

  final DataStore _store;
  final SessionService _session;

  Future<Tenant> updateTenant(Tenant tenant) async {
    if (tenant.name.trim().isEmpty) {
      throw const AppFailure('Business name is required.');
    }
    if (tenant.taxRate < 0 || tenant.taxRate > 100) {
      throw const AppFailure('Tax rate must be between 0 and 100.');
    }
    final row = await _store.update('tenants', tenant.id, {
      'name': tenant.name.trim(),
      'business_type': tenant.businessType,
      'currency': tenant.currency,
      'currency_symbol': tenant.currencySymbol,
      'tax_rate': tenant.taxRate,
      'low_stock_threshold': tenant.lowStockThreshold,
      'phone': tenant.phone,
      'email': tenant.email,
      'address': tenant.address,
      'daily_briefing_enabled': tenant.dailyBriefingEnabled,
      'daily_briefing_time': tenant.dailyBriefingTime,
      'daily_briefing_timezone': tenant.dailyBriefingTimezone,
      'updated_at': toIso(DateTime.now()),
    });
    final updated = Tenant.fromJson(row);
    _session.updateTenant(updated);
    return updated;
  }

  Future<void> resetDemoData() async {
    var store = _store;
    if (store is RoutingDataStore) store = store.local;
    if (store is! LocalDataStore) {
      throw const AppFailure(
        'Demo data can only be reset while the demo workspace is active.',
      );
    }
    await store.resetDemoData();
  }
}
