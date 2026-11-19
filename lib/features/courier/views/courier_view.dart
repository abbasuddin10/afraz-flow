import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/data/cache/data_cache.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../../routes/app_routes.dart';
import '../controllers/courier_controller.dart';
import '../data/courier_order.dart';
import 'courier_dialogs.dart';

class CourierView extends StatefulWidget {
  const CourierView({super.key});

  @override
  State<CourierView> createState() => _CourierViewState();
}

class _CourierViewState extends State<CourierView> {
  final CourierController controller = Get.find<CourierController>();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'New delivery',
      subtitle: 'Book a parcel, capture COD and hand it to a courier.',
      child: const CourierFormDialog(),
    );
  }

  Future<void> _openDetail(CourierOrder order) async {
    await Get.toNamed<void>(Routes.courierDetail, arguments: order);
    await controller.load(silent: true);
  }

  Future<void> _changeStatus(CourierOrder order, CourierStatus status) async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Update delivery',
      subtitle: 'Keep the timeline accurate for the team and the customer.',
      child: CourierStatusDialog(
        order: order,
        status: status,
        onSubmit: (note) => controller.changeStatus(order, status, note: note),
      ),
    );
  }

  Future<void> _editTracking(CourierOrder order) async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Tracking details',
      subtitle: 'Update the courier partner or tracking number.',
      child: CourierTrackingDialog(
        order: order,
        onSubmit: (partner, tracking) => controller.updateTracking(
          order,
          courierPartner: partner,
          trackingNumber: tracking,
        ),
      ),
    );
  }

  Future<void> _collectCod(CourierOrder order) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reconcile COD?',
      message:
          '${Formats.currency(order.codAmount, symbol: controller.currency)} was '
          'collected for ${order.orderNo}. This will be recorded in the cash book.',
      confirmLabel: 'Reconcile',
      icon: Icons.payments_outlined,
    );
    if (confirmed) await controller.collectCod(order);
  }

  Future<void> _delete(CourierOrder order) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete ${order.orderNo}?',
      message:
          'The delivery and its tracking history will be permanently removed.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) await controller.deleteOrder(order);
  }

  Future<void> _handleAction(String action, CourierOrder order) async {
    switch (action) {
      case 'detail':
        await _openDetail(order);
      case 'advance':
        final next = order.status.next;
        if (next != null) await _changeStatus(order, next);
      case 'tracking':
        await _editTracking(order);
      case 'collect':
        await _collectCod(order);
      case 'delete':
        await _delete(order);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Padding(
      padding: EdgeInsets.all(wide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Logistics',
            title: 'Courier Tracking',
            subtitle:
                'Dispatch parcels, follow every status change and reconcile cash on delivery.',
            actions: [
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text('New delivery'.tr),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const AppCard(
                  child: LoadingState(label: 'Loading deliveries…'),
                );
              }
              if (controller.error.value != null) {
                return AppCard(
                  child: ErrorState(
                    message: controller.error.value!,
                    onRetry: controller.load,
                  ),
                );
              }
              return _buildContent(context, wide);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool wide) {
    return RefreshIndicator(
      onRefresh: () async {
        // Pull-to-refresh always re-fetches from Supabase.
        Get.find<DataCache>().expireAll();
        await controller.load(silent: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        ResponsiveGrid(
          minItemWidth: MediaQuery.sizeOf(context).width < 720 ? 120 : 180,
          maxColumns: MediaQuery.sizeOf(context).width < 720 ? 2 : 4,
          children: [
            _StatTile(
              label: 'Pending',
              value: '${controller.countFor(CourierStatus.pending)}',
              hint: 'Waiting for pickup',
              icon: Icons.schedule_rounded,
              color: AppColors.amber,
            ),
            _StatTile(
              label: 'In transit',
              value: '${controller.countFor(CourierStatus.shipped)}',
              hint: 'With the courier',
              icon: Icons.local_shipping_rounded,
              color: AppColors.blue,
            ),
            _StatTile(
              label: 'Delivered',
              value: '${controller.countFor(CourierStatus.delivered)}',
              hint: 'Completed deliveries',
              icon: Icons.check_circle_rounded,
              color: AppColors.green,
            ),
            _StatTile(
              label: 'COD to reconcile',
              value: Formats.currency(
                controller.codPending,
                symbol: controller.currency,
              ),
              hint:
                  '${Formats.currency(controller.codCollected, symbol: controller.currency)} collected',
              icon: Icons.payments_outlined,
              color: AppColors.teal,
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppSearchField(
                  width: narrow ? constraints.maxWidth : 320,
                  hint: 'Search order, customer, phone or tracking',
                  controller: _search,
                  onChanged: controller.setSearch,
                ),
                Obx(
                  () => Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      ChoiceChip(
                        label: Text("All (${controller.orders.length})"),
                        selected: controller.statusFilter.value == null,
                        onSelected: (_) => controller.setStatusFilter(null),
                      ),
                      for (final status in CourierStatus.values)
                        ChoiceChip(
                          label: Text(
                            '${status.label} (${controller.countFor(status)})',
                          ),
                          selected: controller.statusFilter.value == status,
                          onSelected: (_) =>
                              controller.setStatusFilter(status),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Obx(() {
          final orders = controller.filteredOrders;
          if (orders.isEmpty) {
            return AppCard(
              child: EmptyState(
                icon: Icons.local_shipping_outlined,
                title: controller.orders.isEmpty
                    ? 'No deliveries yet'
                    : 'No deliveries match this view',
                message: controller.orders.isEmpty
                    ? 'Create your first delivery to start tracking parcels '
                          'and cash on delivery.'
                    : 'Clear the status filter or try another search.',
                action: controller.orders.isEmpty
                    ? FilledButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('New delivery'.tr),
                      )
                    : null,
              ),
            );
          }
          return wide
              ? _buildTable(context, orders)
              : _buildCards(context, orders);
        }),
      ],
    ),
  ),
  );
}

  Widget _buildTable(BuildContext context, List<CourierOrder> orders) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              columnSpacing: 24,
              columns: [
                DataColumn(label: Text('ORDER'.tr)),
                DataColumn(label: Text('CUSTOMER'.tr)),
                DataColumn(label: Text('COURIER'.tr)),
                DataColumn(label: Text('STATUS'.tr)),
                DataColumn(label: Text('COD'.tr)),
                DataColumn(label: Text(''.tr)),
              ],
              rows: [
                for (final order in orders)
                  DataRow(
                    onSelectChanged: (_) => _openDetail(order),
                    cells: [
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNo,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            Text(
                              Formats.shortDate(order.createdAt),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 190),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.customerName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                order.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                      fontSize: 9.5,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.courierPartner,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Text(
                              order.trackingNumber ?? 'No tracking',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontSize: 9.5,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      DataCell(
                        StatusPill(
                          label: order.status.label,
                          color: order.status.color,
                          icon: order.status.icon,
                          dense: true,
                        ),
                      ),
                      DataCell(
                        order.hasCod
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    Formats.currency(
                                      order.codAmount,
                                      symbol: controller.currency,
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  Text(
                                    order.codCollected
                                        ? 'Reconciled'
                                        : 'Pending',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: order.codCollected
                                              ? AppColors.green
                                              : AppColors.amber,
                                          fontSize: 9.5,
                                        ),
                                  ),
                                ],
                              )
                            : Text('—'.tr),
                      ),
                      DataCell(
                        PopupMenuButton<String>(
                          tooltip: 'Delivery actions',
                          icon: const Icon(Icons.more_horiz_rounded, size: 19),
                          onSelected: (value) => _handleAction(value, order),
                          itemBuilder: (context) => _menuItems(order),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCards(BuildContext context, List<CourierOrder> orders) {
    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        for (final order in orders)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _openDetail(order),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(
                        name: order.customerName,
                        size: 42,
                        background: order.status.color,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.orderNo,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              order.customerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: order.status.label,
                        color: order.status.color,
                        icon: order.status.icon,
                        dense: true,
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 19),
                        onSelected: (value) => _handleAction(value, order),
                        itemBuilder: (context) => _menuItems(order),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 15,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${order.city} · ${order.shortAddress}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(
                        Icons.local_shipping_outlined,
                        size: 14,
                        color: AppColors.inkMuted,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          '${order.courierPartner}${order.trackingNumber == null ? '' : ' · ${order.trackingNumber}'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      if (order.hasCod)
                        StatusPill(
                          label: order.codCollected
                              ? 'COD ${Formats.currency(order.codAmount, symbol: controller.currency)} done'
                              : 'COD ${Formats.currency(order.codAmount, symbol: controller.currency)}',
                          color: order.codCollected
                              ? AppColors.green
                              : AppColors.amber,
                          dense: true,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _menuItems(CourierOrder order) {
    final next = order.status.next;
    return [
      const PopupMenuItem(
        value: 'detail',
        child: _MenuRow(icon: Icons.open_in_new_rounded, label: 'Open delivery'),
      ),
      if (next != null)
        PopupMenuItem(
          value: 'advance',
          child: _MenuRow(
            icon: next.icon,
            label: 'Mark ${next.label.toLowerCase()}',
          ),
        ),
      const PopupMenuItem(
        value: 'tracking',
        child: _MenuRow(
          icon: Icons.confirmation_number_outlined,
          label: 'Edit tracking',
        ),
      ),
      if (order.status == CourierStatus.delivered && order.codPending)
        const PopupMenuItem(
          value: 'collect',
          child: _MenuRow(
            icon: Icons.payments_outlined,
            label: 'Reconcile COD',
          ),
        ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'delete',
        child: _MenuRow(
          icon: Icons.delete_outline_rounded,
          label: 'Delete delivery',
          color: AppColors.red,
        ),
      ),
    ];
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
