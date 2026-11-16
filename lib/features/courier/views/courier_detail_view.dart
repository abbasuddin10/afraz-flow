import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../controllers/courier_controller.dart';
import '../data/courier_order.dart';
import 'courier_dialogs.dart';

class CourierDetailView extends GetView<CourierDetailController> {
  const CourierDetailView({super.key});

  Future<void> _changeStatus(BuildContext context, CourierStatus status) async {
    final order = controller.order.value;
    if (order == null) return;
    await AppDialogs.showForm<bool>(
      context,
      title: 'Update delivery',
      subtitle: 'Keep the tracking timeline accurate for the whole team.',
      child: CourierStatusDialog(
        order: order,
        status: status,
        onSubmit: (note) => controller.changeStatus(status, note: note),
      ),
    );
  }

  Future<void> _editTracking(BuildContext context) async {
    final order = controller.order.value;
    if (order == null) return;
    await AppDialogs.showForm<bool>(
      context,
      title: 'Tracking details',
      subtitle: 'Update the courier partner or tracking number.',
      child: CourierTrackingDialog(
        order: order,
        onSubmit: (partner, tracking) => controller.updateTracking(
          courierPartner: partner,
          trackingNumber: tracking,
        ),
      ),
    );
  }

  Future<void> _collectCod(BuildContext context) async {
    final order = controller.order.value;
    if (order == null) return;
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Reconcile COD?',
      message:
          '${Formats.currency(order.codAmount, symbol: Get.find<SessionService>().currencySymbol)} '
          'was collected for ${order.orderNo}. This is added to the cash book.',
      confirmLabel: 'Reconcile',
      icon: Icons.payments_outlined,
    );
    if (confirmed) await controller.collectCod();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final order = controller.order.value;
      return Scaffold(
        appBar: AppBar(
          title: Text(order == null ? 'Delivery' : order.orderNo),
          actions: [
            IconButton(
              onPressed: controller.loading.value ? null : controller.refreshQuietly,
              tooltip: 'Refresh delivery',
              icon: const Icon(Icons.refresh_rounded),
            ),
            if (order != null)
              PopupMenuButton<String>(
                tooltip: 'More status options',
                onSelected: (value) {
                  switch (value) {
                    case 'returned':
                      _changeStatus(context, CourierStatus.returned);
                    case 'cancelled':
                      _changeStatus(context, CourierStatus.cancelled);
                    case 'pending':
                      _changeStatus(context, CourierStatus.pending);
                  }
                },
                itemBuilder: (context) => [
                  if (order.status != CourierStatus.pending &&
                      order.status != CourierStatus.shipped)
                    const PopupMenuItem(
                      value: 'pending',
                      child: _MenuRow(
                        icon: Icons.schedule_rounded,
                        label: 'Move back to pending',
                      ),
                    ),
                  if (order.status != CourierStatus.returned)
                    const PopupMenuItem(
                      value: 'returned',
                      child: _MenuRow(
                        icon: Icons.undo_rounded,
                        label: 'Mark returned',
                      ),
                    ),
                  if (order.status != CourierStatus.cancelled)
                    const PopupMenuItem(
                      value: 'cancelled',
                      child: _MenuRow(
                        icon: Icons.cancel_rounded,
                        label: 'Cancel delivery',
                        color: AppColors.red,
                      ),
                    ),
                ],
              ),
            const SizedBox(width: 6),
          ],
        ),
        body: controller.loading.value && order == null
            ? const LoadingState(label: 'Loading delivery…')
            : order == null
            ? ErrorState(
                message:
                    controller.error.value ?? 'This delivery could not be found.',
                title: 'Delivery unavailable',
                onRetry: controller.load,
              )
            : RefreshIndicator(
                onRefresh: controller.refreshQuietly,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (controller.error.value != null) ...[
                            AppCard(
                              borderColor: AppColors.red.withValues(alpha: 0.3),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.cloud_off_rounded,
                                    size: 18,
                                    color: AppColors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      controller.error.value!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: AppColors.red),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                          _HeaderCard(
                            order: order,
                            onChangeStatus: (status) =>
                                _changeStatus(context, status),
                            onEditTracking: () => _editTracking(context),
                            onCollectCod: () => _collectCod(context),
                          ),
                          const SizedBox(height: 14),
                          _StatusFlow(order: order),
                          const SizedBox(height: 14),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              if (constraints.maxWidth < 760) {
                                return Column(
                                  children: [
                                    _CodCard(
                                      order: order,
                                      onCollect: () => _collectCod(context),
                                    ),
                                    const SizedBox(height: 14),
                                    _TimelineCard(order: order),
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _TimelineCard(order: order)),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 320,
                                    child: _CodCard(
                                      order: order,
                                      onCollect: () => _collectCod(context),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
      );
    });
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.order,
    required this.onChangeStatus,
    required this.onEditTracking,
    required this.onCollectCod,
  });

  final CourierOrder order;
  final ValueChanged<CourierStatus> onChangeStatus;
  final VoidCallback onEditTracking;
  final VoidCallback onCollectCod;

  @override
  Widget build(BuildContext context) {
    final next = order.status.next;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: order.status.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  order.status.icon,
                  size: 25,
                  color: order.status.color,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            order.customerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 9),
                        StatusPill(
                          label: order.status.label,
                          color: order.status.color,
                          icon: order.status.icon,
                          dense: true,
                        ),
                      ],
                    ),
                    Text(
                      '${order.courierPartner} · ${order.trackingNumber ?? 'No tracking number yet'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;
              final items = [
                _Detail(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: order.customerPhone,
                ),
                _Detail(
                  icon: Icons.location_on_outlined,
                  label: 'Deliver to',
                  value: '${order.address}, ${order.city}',
                ),
                _Detail(
                  icon: Icons.event_outlined,
                  label: 'Created',
                  value: Formats.dateTime(order.createdAt),
                ),
                if (order.dispatchedAt != null)
                  _Detail(
                    icon: Icons.local_shipping_outlined,
                    label: 'Dispatched',
                    value: Formats.dateTime(order.dispatchedAt),
                  ),
                if (order.deliveredAt != null)
                  _Detail(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Delivered',
                    value: Formats.dateTime(order.deliveredAt),
                  ),
              ];
              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in items) ...[
                      item,
                      const SizedBox(height: 10),
                    ],
                  ],
                );
              }
              return Wrap(
                spacing: 30,
                runSpacing: 14,
                children: [
                  for (final item in items)
                    SizedBox(width: 250, child: item),
                ],
              );
            },
          ),
          if (order.notes != null && order.notes!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.amber.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 16,
                    color: AppColors.amber,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      order.notes!,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: [
              if (next != null)
                FilledButton.icon(
                  onPressed: () => onChangeStatus(next),
                  icon: Icon(next.icon, size: 17),
                  label: Text("Mark ${next.label.toLowerCase()}"),
                ),
              if (order.status == CourierStatus.delivered && order.codPending)
                FilledButton.icon(
                  onPressed: onCollectCod,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                  ),
                  icon: const Icon(Icons.payments_outlined, size: 17),
                  label: Text('Reconcile COD'.tr),
                ),
              OutlinedButton.icon(
                onPressed: onEditTracking,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: Text('Edit tracking'.tr),
              ),
              if (order.status.isOpen)
                TextButton.icon(
                  onPressed: () => onChangeStatus(CourierStatus.returned),
                  icon: const Icon(Icons.undo_rounded, size: 17),
                  label: Text('Returned'.tr),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 8.5,
                  letterSpacing: 0.8,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusFlow extends StatelessWidget {
  const _StatusFlow({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context) {
    final flow = CourierStatus.flow;
    final index = flow.indexOf(order.status);
    if (index < 0) {
      return AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(order.status.icon, size: 18, color: order.status.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                order.status == CourierStatus.returned
                    ? 'This parcel was returned to the business.'
                    : 'This delivery was cancelled.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Row(
        children: [
          for (var i = 0; i < flow.length; i++) ...[
            _FlowStep(
              status: flow[i],
              done: i <= index,
              active: i == index,
            ),
            if (i < flow.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: i < index
                        ? AppColors.teal
                        : Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  const _FlowStep({
    required this.status,
    required this.done,
    required this.active,
  });

  final CourierStatus status;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.teal : AppColors.inkMuted;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: done
                ? color.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: BoxShape.circle,
            border: active ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Icon(
            status.icon,
            size: 16,
            color: done ? color : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: done ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _CodCard extends StatelessWidget {
  const _CodCard({required this.order, required this.onCollect});

  final CourierOrder order;
  final VoidCallback onCollect;

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final currency = session.currencySymbol;
    final collected = order.codCollected;
    final available = order.status == CourierStatus.delivered;
    final color = collected
        ? AppColors.green
        : available
        ? AppColors.amber
        : AppColors.inkMuted;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                size: 17,
                color: AppColors.teal,
              ),
              const SizedBox(width: 7),
              Text(
                'CASH ON DELIVERY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            Formats.currency(order.codAmount, symbol: currency),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 2),
          Text(
            collected
                ? 'Reconciled with the business'
                : available
                ? 'Collected — awaiting reconciliation'
                : 'Not collected yet',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
          const Divider(height: 22),
          InfoRow(
            label: 'Shipping fee',
            value: Formats.currency(order.shippingFee, symbol: currency),
            icon: Icons.delivery_dining_outlined,
          ),
          InfoRow(
            label: 'Status',
            value: order.status.label,
            icon: order.status.icon,
            valueColor: order.status.color,
          ),
          if (order.codAmount > 0) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: collected
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle_rounded, size: 17),
                      label: Text('COD reconciled'.tr),
                    )
                  : FilledButton.icon(
                      onPressed: available ? onCollect : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                      ),
                      icon: const Icon(Icons.payments_outlined, size: 17),
                      label: Text(
                        available
                            ? 'Reconcile ${Formats.currency(order.codAmount, symbol: currency)}'
                            : 'Available after delivery',
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.order});

  final CourierOrder order;

  @override
  Widget build(BuildContext context) {
    final events = order.events.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Tracking timeline',
            subtitle: 'Every status change, newest first.',
          ),
          const SizedBox(height: 14),
          if (events.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.timeline_rounded,
              title: 'No tracking events',
              message: 'Status changes will build a timeline here.',
            )
          else
            for (var i = 0; i < events.length; i++)
              _TimelineEntry(
                event: events[i],
                isLast: i == events.length - 1,
              ),
        ],
      ),
    );
  }
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.event, required this.isLast});

  final CourierEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final isLatest = event.status.isOpen || event.status == CourierStatus.delivered;
    final color = isLatest ? event.status.color : AppColors.inkMuted;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(event.status.icon, size: 14, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.status.label,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        Formats.dateTime(event.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 9.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.note,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
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
