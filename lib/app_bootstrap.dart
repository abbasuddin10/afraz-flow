import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/app_config.dart';
import 'core/data/backend_mode.dart';
import 'core/data/cache/data_cache.dart';
import 'core/data/data_store.dart';
import 'core/data/local_data_store.dart';
import 'core/data/routing_data_store.dart';
import 'core/data/supabase_data_store.dart';
import 'core/platform/desktop_window.dart';
import 'core/services/app_services.dart';
import 'core/services/push_notification_service.dart';
import 'features/assistant/data/assistant_repository.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/briefing/data/briefing_repository.dart';
import 'features/courier/data/courier_repository.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/inventory/data/product_repository.dart';
import 'features/ledger/data/account_repository.dart';
import 'features/notifications/data/notification_repository.dart';
import 'features/pos/data/sale_repository.dart';
import 'features/settings/data/settings_repository.dart';
import 'features/staff/data/staff_repository.dart';

/// Initialises storage/cloud backends and registers the dependency graph.
class AppBootstrap {
  const AppBootstrap._();

  static late final DataStore store;
  static late final SharedPreferences prefs;
  static late final BackendMode backendMode;
  static String? cloudError;
  static bool get isRemote => store.isRemote;

  static Future<void> initialize() async {
    // main() ensures binding and applies an overall timeout, but keep this
    // safe to call directly as well.
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await configureDesktopWindow();
    } catch (error) {
      debugPrint('Desktop window setup failed: $error');
    }
    try {
      await initializeDateFormatting('en_US');
    } catch (error) {
      debugPrint('Date formatting init failed: $error');
    }
    prefs = await SharedPreferences.getInstance();

    final localStore = LocalDataStore(prefs);
    SupabaseClient? client;
    String? initError;
    if (AppConfig.hasSupabase) {
      try {
        await Supabase.initialize(
          url: AppConfig.supabaseUrl,
          publishableKey: AppConfig.supabaseAnonKey,
          debug: kDebugMode,
        );
        client = Supabase.instance.client;
      } catch (error) {
        debugPrint('Supabase initialisation failed: $error');
        initError = error.toString();
      }
    }

    final mode = BackendMode(
      prefs: prefs,
      cloudAvailable: client != null,
      cloudError: initError,
    );
    // Smart local cache: cloud reads are served from a persistent on-device
    // cache (Hive) and only re-fetched when data changes or the user pulls
    // to refresh, keeping Supabase free-tier reads low.
    final dataCache = await DataCache.create();
    final routingStore = RoutingDataStore(
      cloud: client == null
          ? null
          : CachedDataStore(SupabaseDataStore(client), cache: dataCache),
      local: localStore,
      mode: mode,
    );
    store = routingStore;
    backendMode = mode;
    cloudError = initError;

    final preferences = PreferencesService(prefs);
    try {
      await initializeDateFormatting(
        preferences.locale.toString().replaceAll('-', '_'),
      );
    } catch (error) {
      debugPrint('Date formatting init failed: $error');
    }
    final auth = AuthRepository(
      store: routingStore,
      prefs: prefs,
      client: client,
      mode: mode,
    );
    final session = SessionService(auth, mode: mode);

    Get.put<DataStore>(routingStore, permanent: true);
    Get.put<DataCache>(dataCache, permanent: true);
    Get.put<BackendMode>(mode, permanent: true);
    Get.put<LocalDataStore>(localStore, permanent: true);
    Get.put<PreferencesService>(preferences, permanent: true);
    Get.put<ThemeController>(ThemeController(preferences), permanent: true);
    Get.put<LanguageController>(
      LanguageController(preferences),
      permanent: true,
    );
    Get.put<AuthRepository>(auth, permanent: true);
    Get.put<SessionService>(session, permanent: true);

    final products = ProductRepository(store, session);
    final sales = SaleRepository(store, session);
    final accounts = AccountRepository(store, session);
    final expenses = ExpenseRepository(store, session);
    final couriers = CourierRepository(store, session);

    Get.put<ProductRepository>(products, permanent: true);
    Get.put<SaleRepository>(sales, permanent: true);
    Get.put<AccountRepository>(accounts, permanent: true);
    Get.put<ExpenseRepository>(expenses, permanent: true);
    Get.put<CourierRepository>(couriers, permanent: true);
    Get.put<CashBookRepository>(
      CashBookRepository(sales, expenses, accounts),
      permanent: true,
    );
    Get.put<StaffRepository>(
      StaffRepository(store, session, client: client),
      permanent: true,
    );
    Get.put<AssistantRepository>(
      AssistantRepository(session, client: client),
      permanent: true,
    );
    Get.put<DashboardRepository>(
      DashboardRepository(
        sales: sales,
        products: products,
        accounts: accounts,
        expenses: expenses,
        couriers: couriers,
      ),
      permanent: true,
    );
    Get.put<SettingsRepository>(
      SettingsRepository(store, session),
      permanent: true,
    );
    Get.put<BriefingRepository>(
      BriefingRepository(store, session, client: client),
      permanent: true,
    );
    Get.put<NotificationRepository>(
      NotificationRepository(store, session, client: client),
      permanent: true,
    );
    // Real-time mobile push notifications (FCM). Initialisation is
    // non-blocking so a slow network never delays the first frame.
    final push = PushNotificationService(routingStore, session);
    Get.put<PushNotificationService>(push, permanent: true);
    unawaited(push.initialize());
  }
}
