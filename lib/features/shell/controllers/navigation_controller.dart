import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/app_user.dart';
import '../../../core/services/app_services.dart';
import '../../briefing/controllers/briefing_controller.dart';
import '../../courier/controllers/courier_controller.dart';
import '../../dashboard/controllers/dashboard_controller.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../inventory/controllers/inventory_controller.dart';
import '../../ledger/controllers/ledger_controller.dart';
import '../../notifications/controllers/notification_controller.dart';
import '../../pos/controllers/pos_controller.dart';
import '../../staff/controllers/staff_controller.dart';

enum AppSection {
  dashboard,
  pos,
  inventory,
  courier,
  ledger,
  staff,
  assistant,
  briefing,
  settings,
  more;

  String get label => switch (this) {
    AppSection.dashboard => 'Dashboard',
    AppSection.pos => 'Point of Sale',
    AppSection.inventory => 'Inventory',
    AppSection.courier => 'Courier',
    AppSection.ledger => 'Accounts & Ledger',
    AppSection.staff => 'Staff & Roles',
    AppSection.assistant => 'AI Assistant',
    AppSection.briefing => 'Daily AI Briefing',
    AppSection.settings => 'Settings',
    AppSection.more => 'More',
  };

  String get shortLabel => switch (this) {
    AppSection.dashboard => 'Dashboard',
    AppSection.pos => 'POS',
    AppSection.inventory => 'Stock',
    AppSection.courier => 'Courier',
    AppSection.ledger => 'Ledger',
    AppSection.staff => 'Staff',
    AppSection.assistant => 'Assistant',
    AppSection.briefing => 'Briefing',
    AppSection.settings => 'Settings',
    AppSection.more => 'More',
  };

  String get subtitle => switch (this) {
    AppSection.dashboard => 'A live pulse of your business',
    AppSection.pos => 'Scan, bill and print in seconds',
    AppSection.inventory => 'Products, stock levels and movements',
    AppSection.courier => 'Deliveries, tracking and COD reconciliation',
    AppSection.ledger => 'Cash book, expenses and Khata accounts',
    AppSection.staff => 'Team access and role permissions',
    AppSection.assistant =>
      'Ask your business data anything, in English or Bangla',
    AppSection.briefing => 'Your daily executive summary, written for you',
    AppSection.settings => 'Business profile and preferences',
    AppSection.more => 'Everything else in your workspace',
  };

  IconData get icon => switch (this) {
    AppSection.dashboard => Icons.space_dashboard_outlined,
    AppSection.pos => Icons.point_of_sale_outlined,
    AppSection.inventory => Icons.inventory_2_outlined,
    AppSection.courier => Icons.local_shipping_outlined,
    AppSection.ledger => Icons.account_balance_wallet_outlined,
    AppSection.staff => Icons.groups_2_outlined,
    AppSection.assistant => Icons.auto_awesome_outlined,
    AppSection.briefing => Icons.insights_outlined,
    AppSection.settings => Icons.settings_outlined,
    AppSection.more => Icons.grid_view_rounded,
  };

  IconData get selectedIcon => switch (this) {
    AppSection.dashboard => Icons.space_dashboard_rounded,
    AppSection.pos => Icons.point_of_sale_rounded,
    AppSection.inventory => Icons.inventory_2_rounded,
    AppSection.courier => Icons.local_shipping_rounded,
    AppSection.ledger => Icons.account_balance_wallet_rounded,
    AppSection.staff => Icons.groups_2_rounded,
    AppSection.assistant => Icons.auto_awesome_rounded,
    AppSection.briefing => Icons.insights_rounded,
    AppSection.settings => Icons.settings_rounded,
    AppSection.more => Icons.grid_view_rounded,
  };

  bool canAccess(MemberRole role) => switch (this) {
    AppSection.ledger => role != MemberRole.cashier,
    AppSection.staff => role == MemberRole.admin,
    AppSection.assistant => role == MemberRole.admin,
    AppSection.briefing => role == MemberRole.admin,
    _ => true,
  };
}

class NavigationController extends GetxController {
  final SessionService _session = Get.find<SessionService>();

  final Rx<AppSection> section = AppSection.dashboard.obs;
  final RxBool drawerOpen = false.obs;
  final RxInt lowStockCount = 0.obs;
  final RxInt pendingOrders = 0.obs;
  final RxDouble codPending = 0.0.obs;

  List<AppSection> get destinations => [
    AppSection.dashboard,
    AppSection.pos,
    AppSection.inventory,
    AppSection.courier,
    if (AppSection.ledger.canAccess(_session.role)) AppSection.ledger,
    if (AppSection.staff.canAccess(_session.role)) AppSection.staff,
    if (AppSection.assistant.canAccess(_session.role)) AppSection.assistant,
    if (AppSection.briefing.canAccess(_session.role)) AppSection.briefing,
    AppSection.settings,
  ];

  AppSection get current => section.value;

  IconData iconFor(AppSection item) => item.icon;

  /// Prevents a burst of lifecycle events (for example a resume triggered by a
  /// permission dialog) from firing several full refreshes back to back.
  static const Duration _fullRefreshDebounce = Duration(seconds: 2);
  DateTime? _lastFullRefresh;

  void go(AppSection value) {
    if (!value.canAccess(_session.role)) return;
    section.value = value;
    drawerOpen.value = false;
    unawaited(refreshBadges(silent: true));
    // Reload the section being opened. Controllers that have not been created
    // yet load themselves from `onInit`, so this only refreshes pages whose
    // data may be stale from an earlier visit.
    unawaited(refreshSection(value));
  }

  /// Returns true when a controller has already been created and is alive.
  ///
  /// `Get.isRegistered` is also true for lazy factories that have never been
  /// instantiated, so the `isInit` flag is checked as well. This avoids
  /// creating a controller (and triggering a second load) just to refresh it.
  bool _isLive<T>() {
    final info = GetInstance().getInstanceInfo<T>();
    return info.isRegistered && info.isInit == true;
  }

  /// Sections whose data is currently being reloaded.
  ///
  /// A quick tab switch or a resume event can ask for the same refresh twice;
  /// the second request is skipped instead of stacking another network call.
  final Set<AppSection> _refreshing = <AppSection>{};

  /// Reloads the data behind [value] from the backend.
  ///
  /// Only controllers that already exist are refreshed. Errors are swallowed
  /// because a failed background refresh must never block navigation.
  Future<void> refreshSection(AppSection value, {bool silent = true}) async {
    if (!_refreshing.add(value)) return;
    try {
      switch (value) {
        case AppSection.dashboard:
          if (_isLive<DashboardController>()) {
            await Get.find<DashboardController>().load(silent: silent);
          }
        case AppSection.pos:
          if (_isLive<PosController>()) {
            await Get.find<PosController>().load(silent: silent);
          }
        case AppSection.inventory:
          if (_isLive<InventoryController>()) {
            await Get.find<InventoryController>().load(silent: silent);
          }
        case AppSection.courier:
          if (_isLive<CourierController>()) {
            await Get.find<CourierController>().load(silent: silent);
          }
        case AppSection.ledger:
          if (_isLive<LedgerController>()) {
            await Get.find<LedgerController>().load(silent: silent);
          }
        case AppSection.staff:
          if (_isLive<StaffController>()) {
            await Get.find<StaffController>().load(silent: silent);
          }
        case AppSection.briefing:
          if (_isLive<BriefingController>()) {
            await Get.find<BriefingController>().load(silent: silent);
          }
        case AppSection.assistant:
        case AppSection.settings:
        case AppSection.more:
          break;
      }
    } catch (_) {
      // A background refresh failure should not surface as a crash. Screens
      // keep showing the last successfully loaded data.
    } finally {
      _refreshing.remove(value);
    }
  }

  /// Refreshes every section that has already been opened, plus the sidebar
  /// badges and notifications. Called when the app returns to the foreground.
  Future<void> refreshAll({bool silent = true, bool force = false}) async {
    final now = DateTime.now();
    final last = _lastFullRefresh;
    if (!force && last != null && now.difference(last) < _fullRefreshDebounce) {
      return;
    }
    _lastFullRefresh = now;

    await Future.wait([
      for (final section in AppSection.values)
        refreshSection(section, silent: silent),
    ]);
    unawaited(refreshBadges(silent: true));

    if (_isLive<NotificationController>()) {
      try {
        await Get.find<NotificationController>().refresh();
      } catch (_) {
        // Notifications are best-effort; ignore transient failures.
      }
    }
  }

  Future<void> refreshBadges({bool silent = false}) async {
    try {
      final repo = Get.find<DashboardRepository>();
      final badges = await repo.badges();
      lowStockCount.value = badges.lowStock;
      pendingOrders.value = badges.pending;
      codPending.value = badges.cod;
    } catch (_) {
      // Badges are decorative; ignore transient failures.
    }
  }

  int? badgeFor(AppSection item) => switch (item) {
    AppSection.inventory =>
      lowStockCount.value > 0 ? lowStockCount.value : null,
    AppSection.courier => pendingOrders.value > 0 ? pendingOrders.value : null,
    _ => null,
  };
}
