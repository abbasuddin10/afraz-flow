import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../../routes/app_routes.dart';
import '../../assistant/views/assistant_view.dart';
import '../../briefing/views/briefing_view.dart';
import '../../courier/views/courier_view.dart';
import '../../dashboard/views/dashboard_view.dart';
import '../../inventory/views/inventory_view.dart';
import '../../ledger/views/ledger_view.dart';
import '../../notifications/widgets/notification_bell.dart';
import '../../pos/views/pos_view.dart';
import '../../settings/views/settings_view.dart';
import '../../staff/views/staff_view.dart';
import '../controllers/navigation_controller.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  NavigationController get nav => Get.find<NavigationController>();
  SessionService get session => Get.find<SessionService>();

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final width = MediaQuery.sizeOf(context).width;
      final mobile = width < 760;
      final desktop = width >= 1120;
      final current = nav.current;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        drawer: mobile ? _buildDrawer(context) : null,
        appBar: mobile ? _buildMobileAppBar(context) : null,
        bottomNavigationBar: mobile ? _buildBottomBar(context) : null,
        body: SafeArea(
          child: Row(
            children: [
              if (desktop)
                _Sidebar(nav: nav, session: session)
              else if (!mobile)
                _Rail(nav: nav, session: session),
              Expanded(
                child: Column(
                  children: [
                    if (!mobile) _buildDesktopTopBar(context, current),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: KeyedSubtree(
                          key: ValueKey(current),
                          child: _pageFor(current),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _pageFor(AppSection section) {
    return switch (section) {
      AppSection.dashboard => const DashboardView(),
      AppSection.pos => const PosView(),
      AppSection.inventory => const InventoryView(),
      AppSection.courier => const CourierView(),
      AppSection.ledger => const LedgerView(),
      AppSection.staff => const StaffView(),
      AppSection.assistant => const AssistantView(),
      AppSection.briefing => const BriefingView(),
      AppSection.settings => const SettingsView(),
      AppSection.more => const _MoreView(),
    };
  }

  PreferredSizeWidget _buildMobileAppBar(BuildContext context) {
    final tenant = session.tenant;
    return AppBar(
      leading: IconButton(
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        icon: const Icon(Icons.menu_rounded),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant?.name ?? 'Afraz Flow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  session.role.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (AppSection.assistant.canAccess(session.role))
          IconButton(
            onPressed: () => nav.go(AppSection.assistant),
            tooltip: 'Ask the AI assistant',
            icon: const Icon(Icons.auto_awesome_outlined, size: 20),
          ),
        const NotificationBell(),
        Obx(
          () => IconButton(
            onPressed: Get.find<ThemeController>().toggle,
            icon: Icon(
              Get.find<ThemeController>().isDark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              size: 20,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _ProfileButton(session: session),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildDesktopTopBar(BuildContext context, AppSection current) {
    final theme = Theme.of(context);
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(current.label, style: theme.textTheme.titleLarge),
                Text(
                  current.subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => nav.lowStockCount.value > 0
                ? _AlertChip(
                    icon: Icons.inventory_2_outlined,
                    label: '${nav.lowStockCount.value} low stock',
                    color: AppColors.amber,
                    onTap: () => nav.go(AppSection.inventory),
                  )
                : const SizedBox.shrink(),
          ),
          Obx(
            () => nav.pendingOrders.value > 0
                ? Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _AlertChip(
                      icon: Icons.local_shipping_outlined,
                      label: '${nav.pendingOrders.value} to ship',
                      color: AppColors.blue,
                      onTap: () => nav.go(AppSection.courier),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 14),
          const NotificationBell(),
          if (AppSection.assistant.canAccess(session.role) &&
              current != AppSection.assistant)
            IconButton(
              onPressed: () => nav.go(AppSection.assistant),
              tooltip: 'Ask the AI assistant',
              icon: const Icon(Icons.auto_awesome_outlined, size: 20),
            ),
          Obx(
            () => IconButton(
              onPressed: Get.find<ThemeController>().toggle,
              tooltip: 'Toggle theme',
              icon: Icon(
                Get.find<ThemeController>().isDark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (current != AppSection.pos)
            FilledButton.icon(
              onPressed: () => nav.go(AppSection.pos),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text('New sale'.tr),
            ),
          const SizedBox(width: 14),
          _ProfileButton(session: session, showName: true),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      width: 286,
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: _SidebarBody(
            nav: nav,
            session: session,
            onNavigate: (_) => Navigator.of(context).pop(),
            compactBrand: true,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    // Let the keyboard own the bottom of the screen while the user is typing.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    return _MobileBottomBar(nav: nav);
  }
}

/// A floating, rounded action bar built for thumbs: four everyday destinations
/// plus a raised gradient "Sell" button in the middle that opens the POS.
class _MobileBottomBar extends StatelessWidget {
  const _MobileBottomBar({required this.nav});

  final NavigationController nav;

  static const List<_MobileTab> _tabs = [
    _MobileTab(
      AppSection.dashboard,
      'Home',
      Icons.space_dashboard_outlined,
      Icons.space_dashboard_rounded,
    ),
    _MobileTab(
      AppSection.inventory,
      'Stock',
      Icons.inventory_2_outlined,
      Icons.inventory_2_rounded,
    ),
    _MobileTab(
      AppSection.pos,
      'Sell',
      Icons.point_of_sale_outlined,
      Icons.point_of_sale_rounded,
      primary: true,
    ),
    _MobileTab(
      AppSection.courier,
      'Courier',
      Icons.local_shipping_outlined,
      Icons.local_shipping_rounded,
    ),
    _MobileTab(
      AppSection.more,
      'More',
      Icons.grid_view_rounded,
      Icons.grid_view_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final current = nav.current;
    var selected = _tabs.indexWhere((tab) => tab.section == current);
    // Ledger, staff, assistant, briefing and settings are reached through
    // "More".
    if (selected < 0) selected = _tabs.length - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          height: 70,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.navyDeep.withValues(alpha: dark ? 0.45 : 0.14),
                blurRadius: 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            color: dark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Expanded(
                      child: _MobileTabButton(
                        tab: _tabs[i],
                        selected: i == selected,
                        badge: nav.badgeFor(_tabs[i].section),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          nav.go(_tabs[i].section);
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileTab {
  const _MobileTab(
    this.section,
    this.label,
    this.icon,
    this.selectedIcon, {
    this.primary = false,
  });

  final AppSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool primary;
}

class _MobileTabButton extends StatelessWidget {
  const _MobileTabButton({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final _MobileTab tab;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final accent = tab.primary ? AppColors.teal : theme.colorScheme.primary;
    final color = selected ? accent : muted;

    if (tab.primary) {
      return InkResponse(
        onTap: onTap,
        radius: 40,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              width: 42,
              height: 38,
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.teal.withValues(
                      alpha: selected ? 0.45 : 0.25,
                    ),
                    blurRadius: selected ? 14 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                selected ? tab.selectedIcon : tab.icon,
                size: 21,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tab.label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.1,
                letterSpacing: -0.1,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                  horizontal: selected ? 14 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? accent.withValues(alpha: 0.13)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: 21,
                  color: color,
                ),
              ),
              if (badge != null && badge! > 0)
                Positioned(top: -3, right: -6, child: _TabBadge(count: badge!)),
            ],
          ),
          const SizedBox(height: 1),
          Text(
            tab.label,
            maxLines: 1,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.1,
              letterSpacing: -0.1,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 15),
      decoration: BoxDecoration(
        color: AppColors.amber,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white, width: 1.4),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 8,
          height: 1.2,
          fontWeight: FontWeight.w800,
          color: AppColors.navyDeep,
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.nav, required this.session});

  final NavigationController nav;
  final SessionService session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 268,
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: SafeArea(
        child: _SidebarBody(nav: nav, session: session),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.nav, required this.session});

  final NavigationController nav;
  final SessionService session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 18),
            const AppLogoMark(size: 38),
            const SizedBox(height: 24),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final item in nav.destinations)
                      Obx(() {
                        final selected = nav.current == item;
                        final badge = nav.badgeFor(item);
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          child: Tooltip(
                            message: item.label,
                            child: InkWell(
                              onTap: () => nav.go(item),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                height: 48,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: selected
                                      ? Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      selected ? item.selectedIcon : item.icon,
                                      color: selected
                                          ? Colors.white
                                          : Colors.white.withValues(
                                              alpha: 0.55,
                                            ),
                                      size: 21,
                                    ),
                                    if (badge != null)
                                      Positioned(
                                        top: 9,
                                        right: 10,
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          constraints: const BoxConstraints(
                                            minWidth: 15,
                                            minHeight: 15,
                                          ),
                                          decoration: const BoxDecoration(
                                            color: AppColors.amber,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            badge > 9 ? '9+' : '$badge',
                                            textAlign: TextAlign.center,
                                            style: const TextStyle(
                                              fontSize: 8,
                                              color: AppColors.navyDeep,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Tooltip(
                message:
                    '${session.user?.fullName ?? 'Account'} · ${session.role.label}',
                child: InitialsAvatar(
                  name: session.user?.fullName ?? 'AF',
                  size: 38,
                  background: Colors.white.withValues(alpha: 0.14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarBody extends StatelessWidget {
  const _SidebarBody({
    required this.nav,
    required this.session,
    this.onNavigate,
    this.compactBrand = false,
  });

  final NavigationController nav;
  final SessionService session;
  final ValueChanged<AppSection>? onNavigate;
  final bool compactBrand;

  @override
  Widget build(BuildContext context) {
    final tenant = session.tenant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Row(
            children: [
              const AppLogoMark(size: 40),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      AppConfig.appName,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Business OS',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              InitialsAvatar(
                name: tenant?.name ?? 'AF',
                size: 34,
                background: AppColors.teal.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenant?.name ?? 'Workspace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      tenant?.businessType ?? session.role.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.verified_rounded,
                size: 15,
                color: AppColors.teal.withValues(alpha: 0.9),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Text(
            'WORKSPACE',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.32),
              fontSize: 9.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                for (final item in nav.destinations)
                  _SidebarItem(
                    item: item,
                    selected: nav.current == item,
                    badge: nav.badgeFor(item),
                    onTap: () {
                      nav.go(item);
                      onNavigate?.call(item);
                    },
                  ),
                const SizedBox(height: 16),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.teal.withValues(alpha: 0.22),
                        AppColors.teal.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 15,
                            color: AppColors.teal,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'COD to reconcile',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Obx(
                        () => Text(
                          Formats.currency(
                            nav.codPending.value,
                            symbol: session.currencySymbol,
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Colors.white12, height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 12, 16),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    nav.go(AppSection.settings);
                    onNavigate?.call(AppSection.settings);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        InitialsAvatar(
                          name: session.user?.fullName ?? 'AF',
                          size: 34,
                          background: Colors.white.withValues(alpha: 0.14),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.user?.fullName ?? 'Account',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                session.role.label,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _confirmSignOut(),
                tooltip: 'Sign out',
                icon: Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final AppSection item;
  final bool selected;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.11)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: selected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.07))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 19,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.52),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    item.shortLabel == 'Settings' ? 'Settings' : item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.6),
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      badge! > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navyDeep,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  const _AlertChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  const _ProfileButton({required this.session, this.showName = false});

  final SessionService session;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        if (value == 'settings') {
          Get.find<NavigationController>().go(AppSection.settings);
        } else if (value == 'signout') {
          _confirmSignOut();
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'account',
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(session.user?.fullName ?? 'Account'),
              Text(
                '${session.user?.email ?? ''} · ${session.role.label}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18),
              SizedBox(width: 10),
              Text('Settings'.tr),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'signout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppColors.red),
              SizedBox(width: 10),
              Text('Sign out', style: TextStyle(color: AppColors.red)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showName) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  session.user?.fullName ?? 'Account',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  session.role.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 9),
          ],
          InitialsAvatar(
            name: session.user?.fullName ?? 'AF',
            size: 36,
            background: AppColors.navy,
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmSignOut() async {
  final context = Get.context;
  if (context == null) return;
  final confirmed = await AppDialogs.confirm(
    context,
    title: 'Sign out?',
    message: 'You will need your email and password to sign back in.',
    confirmLabel: 'Sign out',
    icon: Icons.logout_rounded,
    destructive: true,
  );
  if (!confirmed) return;
  await Get.find<SessionService>().signOut();
  Get.offAllNamed(Routes.login);
}

class _MoreView extends StatelessWidget {
  const _MoreView();

  @override
  Widget build(BuildContext context) {
    final nav = Get.find<NavigationController>();
    final session = Get.find<SessionService>();
    final theme = Get.find<ThemeController>();
    final items = [
      if (AppSection.assistant.canAccess(session.role)) AppSection.assistant,
      if (AppSection.briefing.canAccess(session.role)) AppSection.briefing,
      if (AppSection.ledger.canAccess(session.role)) AppSection.ledger,
      if (AppSection.staff.canAccess(session.role)) AppSection.staff,
      AppSection.settings,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'More',
            subtitle: 'Your profile, accounts and workspace settings',
          ),
          const SizedBox(height: 20),
          AppCard(
            child: Row(
              children: [
                InitialsAvatar(
                  name: session.user?.fullName ?? 'AF',
                  size: 52,
                  background: AppColors.navy,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.user?.fullName ?? 'Account',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        session.user?.email ?? '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 5),
                      StatusPill(
                        label: session.role.label,
                        color: AppColors.teal,
                        icon: Icons.verified_user_outlined,
                        dense: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                for (final item in items)
                  ListTile(
                    leading: Icon(item.icon, size: 21),
                    title: Text(item.label),
                    subtitle: Text(item.subtitle),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => nav.go(item),
                  ),
                Obx(
                  () => SwitchListTile(
                    secondary: Icon(
                      theme.isDark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      size: 21,
                    ),
                    title: Text('Dark appearance'.tr),
                    value: theme.isDark,
                    onChanged: (_) => theme.toggle(),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.logout_rounded,
                    size: 21,
                    color: AppColors.red,
                  ),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(color: AppColors.red),
                  ),
                  onTap: _confirmSignOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            '${AppConfig.appName} v${AppConfig.version} · ${AppConfig.packageName}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
