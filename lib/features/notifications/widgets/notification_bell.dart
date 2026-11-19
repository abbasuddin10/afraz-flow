import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../shell/controllers/navigation_controller.dart';
import '../controllers/notification_controller.dart';
import '../data/app_notification.dart';

/// Bell icon with an unread badge and a bottom-sheet inbox.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    return Obx(() {
      final count = controller.unread.value;
      return IconButton(
        tooltip: 'Notifications',
        onPressed: () => _openInbox(context, controller),
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 21),
            if (count > 0)
              Positioned(
                top: -5,
                right: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 15),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.4,
                    ),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 8,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }

  Future<void> _openInbox(
    BuildContext context,
    NotificationController controller,
  ) async {
    controller.refresh();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _NotificationSheet(),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.68;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight + 96),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: theme.textTheme.titleLarge,
                        ),
                        Obx(
                          () => Text(
                            controller.unread.value == 0
                                ? 'You are all caught up'
                                : '${controller.unread.value} unread',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Obx(
                    () => TextButton(
                      onPressed: controller.unread.value == 0
                          ? null
                          : controller.markAllRead,
                      child: const Text('Mark all read'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear all',
                    onPressed: () => _confirmClear(context, controller),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Obx(() {
                  if (controller.loading.value && controller.items.isEmpty) {
                    return const LoadingState(label: 'Loading notifications…');
                  }
                  if (controller.items.isEmpty) {
                    return const EmptyState(
                      compact: true,
                      icon: Icons.notifications_none_rounded,
                      title: 'No notifications',
                      message:
                          'Your daily briefings and important alerts will '
                          'appear here.',
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: controller.items.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: theme.colorScheme.outlineVariant,
                    ),
                    itemBuilder: (context, index) {
                      final notification = controller.items[index];
                      return _NotificationTile(
                        notification: notification,
                        onTap: () => _open(context, controller, notification),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(
    BuildContext context,
    NotificationController controller,
    AppNotification notification,
  ) async {
    await controller.markRead(notification);
    if (!context.mounted) return;
    Navigator.of(context).pop();
    final navigation = Get.find<NavigationController>();
    if (notification.isBriefing) {
      navigation.go(AppSection.briefing);
    } else if (notification.isLowStock) {
      navigation.go(AppSection.inventory);
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    NotificationController controller,
  ) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Clear notifications?',
      message: 'This removes every notification from your inbox.',
      confirmLabel: 'Clear all',
      destructive: true,
      icon: Icons.delete_sweep_outlined,
    );
    if (confirmed) await controller.clearAll();
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unread = notification.isUnread;
    final accent = notification.isBriefing
        ? AppColors.teal
        : notification.isLowStock
        ? AppColors.amber
        : AppColors.blue;
    final icon = notification.isBriefing
        ? Icons.insights_rounded
        : notification.isLowStock
        ? Icons.inventory_2_outlined
        : Icons.notifications_active_outlined;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                icon,
                size: 18,
                color: accent,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (unread)
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    Formats.relative(notification.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.isAlert)
              const Padding(
                padding: EdgeInsets.only(top: 10, left: 4),
                child: Icon(Icons.chevron_right_rounded, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
