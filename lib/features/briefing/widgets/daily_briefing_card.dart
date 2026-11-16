import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../shell/controllers/navigation_controller.dart';
import '../controllers/briefing_controller.dart';
import '../data/daily_briefing.dart';

/// Compact dashboard entry point for the daily executive summary.
class DailyBriefingCard extends StatelessWidget {
  const DailyBriefingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BriefingController>();
    final theme = Theme.of(context);

    return Obx(() {
      final briefing = controller.selected.value;
      final busy = controller.loading.value && controller.briefings.isEmpty;

      if (busy) {
        return const AppCard(
          child: LoadingState(label: 'Preparing your daily briefing…'),
        );
      }

      return AppCard(
        padding: const EdgeInsets.all(18),
        borderColor: AppColors.teal.withValues(alpha: 0.35),
        onTap: () => Get.find<NavigationController>().go(AppSection.briefing),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Daily AI Briefing',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          if (briefing != null)
                            StatusPill(
                              label: briefing.sourceLabel,
                              color: briefing.source == 'gemini'
                                  ? AppColors.teal
                                  : AppColors.amber,
                              dense: true,
                            ),
                        ],
                      ),
                      Text(
                        briefing == null
                            ? 'Your automatic executive summary'
                            : '${briefing.isToday ? 'Today' : Formats.date(briefing.date)} · ${Formats.relative(briefing.generatedAt)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => Get.find<NavigationController>().go(
                    AppSection.briefing,
                  ),
                  child: const Text('Open'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (briefing == null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.error.value ??
                          'No briefing for today yet. Admins can generate one '
                              'from the briefing page or wait for the evening '
                              'schedule.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ),
                  if (controller.canGenerate) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: controller.generating.value
                          ? null
                          : controller.generate,
                      icon: controller.generating.value
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Generate'),
                    ),
                  ],
                ],
              )
            else
              _BriefingPreview(briefing: briefing),
          ],
        ),
      );
    });
  }
}

class _BriefingPreview extends StatelessWidget {
  const _BriefingPreview({required this.briefing});

  final DailyBriefing briefing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = briefing.metrics;
    final symbol = metrics.currencySymbol;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          briefing.headline,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(height: 1.3),
        ),
        const SizedBox(height: 6),
        Text(
          briefing.summary,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreviewStat(
              label: 'Revenue',
              value: Formats.currency(metrics.revenue, symbol: symbol),
              color: AppColors.teal,
            ),
            _PreviewStat(
              label: 'Net profit',
              value: Formats.currency(metrics.netProfit, symbol: symbol),
              color: metrics.netProfit >= 0 ? AppColors.green : AppColors.red,
            ),
            _PreviewStat(
              label: 'Cash collected',
              value: Formats.currency(metrics.cashCollected, symbol: symbol),
              color: AppColors.blue,
            ),
          ],
        ),
      ],
    );
  }
}

class _PreviewStat extends StatelessWidget {
  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
