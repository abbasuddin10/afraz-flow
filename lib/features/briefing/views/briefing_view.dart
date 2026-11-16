import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/briefing_controller.dart';
import '../data/daily_briefing.dart';

class BriefingView extends GetView<BriefingController> {
  const BriefingView({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              eyebrow: 'Daily executive summary',
              title: 'Daily AI Briefing',
              subtitle:
                  'A plain-language review of sales, cash, stock and next steps.',
              actions: [
                if (controller.canGenerate)
                  Obx(
                    () => FilledButton.icon(
                      onPressed: controller.generating.value
                          ? null
                          : _generate,
                      icon: controller.generating.value
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        controller.generating.value
                            ? 'Preparing…'
                            : 'Generate today',
                      ),
                    ),
                  ),
                IconButton.outlined(
                  onPressed: controller.loading.value
                      ? null
                      : () => controller.refresh(),
                  tooltip: 'Refresh briefings',
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Obx(() => _buildBody(context, wide)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool wide) {
    if (controller.loading.value && controller.briefings.isEmpty) {
      return const AppCard(
        child: LoadingState(label: 'Loading your briefings…'),
      );
    }

    if (controller.error.value != null && controller.briefings.isEmpty) {
      return AppCard(
        child: ErrorState(
          message: controller.error.value!,
          onRetry: controller.load,
        ),
      );
    }

    final selected = controller.selected.value;
    if (selected == null) {
      return AppCard(
        child: EmptyState(
          icon: Icons.insights_outlined,
          title: 'No briefing yet',
          message:
              'Your daily executive summary will appear here once it is '
              'generated. Admins can create today\'s briefing now.',
          action: controller.canGenerate
              ? FilledButton.icon(
                  onPressed: controller.generating.value ? null : _generate,
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Generate today'),
                )
              : null,
        ),
      );
    }

    final detail = _BriefingDetail(briefing: selected);
    final history = _BriefingHistory(
      briefings: controller.briefings,
      selectedId: selected.id,
      onSelect: controller.select,
    );

    if (!wide) {
      return Column(
        children: [
          detail,
          const SizedBox(height: 16),
          history,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: detail),
        const SizedBox(width: 20),
        Expanded(flex: 2, child: history),
      ],
    );
  }

  Future<void> _generate() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.generate();
  }
}

class _BriefingDetail extends StatelessWidget {
  const _BriefingDetail({required this.briefing});

  final DailyBriefing briefing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metrics = briefing.metrics;
    final symbol = metrics.currencySymbol;
    final phone = MediaQuery.sizeOf(context).width < 720;

    return AppCard(
      padding: EdgeInsets.all(phone ? 18 : 22),
      borderColor: AppColors.teal.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      briefing.headline,
                      style: theme.textTheme.titleLarge?.copyWith(height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      briefing.isToday
                          ? 'Today · ${Formats.date(briefing.date)}'
                          : Formats.date(briefing.date),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(
                label: briefing.sourceLabel,
                color: briefing.source == 'gemini'
                    ? AppColors.teal
                    : AppColors.amber,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            briefing.summary,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 20),
          ResponsiveGrid(
            minItemWidth: phone ? 118 : 132,
            spacing: 12,
            maxColumns: 4,
            children: [
              _MetricTile(
                label: 'Revenue',
                value: Formats.currency(metrics.revenue, symbol: symbol),
                icon: Icons.trending_up_rounded,
                color: AppColors.teal,
              ),
              _MetricTile(
                label: 'Net profit',
                value: Formats.currency(metrics.netProfit, symbol: symbol),
                icon: Icons.account_balance_wallet_rounded,
                color: metrics.netProfit >= 0
                    ? AppColors.green
                    : AppColors.red,
              ),
              _MetricTile(
                label: 'Expenses',
                value: Formats.currency(metrics.expenses, symbol: symbol),
                icon: Icons.receipt_long_rounded,
                color: AppColors.red,
              ),
              _MetricTile(
                label: 'Cash collected',
                value: Formats.currency(metrics.cashCollected, symbol: symbol),
                icon: Icons.payments_rounded,
                color: AppColors.blue,
              ),
              _MetricTile(
                label: 'New credit',
                value: Formats.currency(metrics.newCredit, symbol: symbol),
                icon: Icons.credit_score_rounded,
                color: AppColors.amber,
              ),
              _MetricTile(
                label: 'Reorders',
                value: '${metrics.reorderCount}',
                icon: Icons.autorenew_rounded,
                color: AppColors.purple,
              ),
            ],
          ),
          if (briefing.highlights.isNotEmpty) ...[
            const SizedBox(height: 22),
            _SectionLabel(
              icon: Icons.bolt_rounded,
              label: 'Highlights',
              color: AppColors.teal,
            ),
            const SizedBox(height: 10),
            for (final highlight in briefing.highlights)
              _BulletLine(
                text: highlight,
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.teal,
              ),
          ],
          if (briefing.recommendations.isNotEmpty) ...[
            const SizedBox(height: 20),
            _SectionLabel(
              icon: Icons.lightbulb_outline_rounded,
              label: 'Recommended next steps',
              color: AppColors.amber,
            ),
            const SizedBox(height: 10),
            for (final recommendation in briefing.recommendations)
              _BulletLine(
                text: recommendation,
                icon: Icons.arrow_right_rounded,
                color: AppColors.amber,
              ),
          ],
          if (metrics.topProducts.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel(
              icon: Icons.local_mall_outlined,
              label: 'Top products',
              color: AppColors.blue,
            ),
            const SizedBox(height: 10),
            for (var index = 0; index < metrics.topProducts.length; index++)
              _TopProductRow(
                index: index,
                product: metrics.topProducts[index],
                symbol: symbol,
              ),
          ],
          if (metrics.lowStock.isNotEmpty || metrics.reorders.isNotEmpty) ...[
            const SizedBox(height: 22),
            const _SectionLabel(
              icon: Icons.inventory_2_outlined,
              label: 'Stock watch',
              color: AppColors.amber,
            ),
            const SizedBox(height: 10),
            for (final product in metrics.lowStock)
              _StockRow(
                title: product.name,
                subtitle:
                    '${product.sku} · ${Formats.number(product.stockQty, decimals: product.stockQty % 1 == 0 ? 0 : 1)} ${product.unit} left · alert at ${product.threshold}',
                color: product.stockQty <= 0 ? AppColors.red : AppColors.amber,
              ),
            for (final reorder in metrics.reorders)
              _StockRow(
                title: '${reorder.productName} reorder',
                subtitle:
                    '${Formats.number(reorder.quantity, decimals: reorder.quantity % 1 == 0 ? 0 : 1)} units · ${reorder.status}',
                color: AppColors.teal,
                icon: Icons.autorenew_rounded,
              ),
          ],
          const SizedBox(height: 20),
          Divider(color: theme.colorScheme.outlineVariant),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Generated ${Formats.dateTime(briefing.generatedAt)} · ${briefing.timezone}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (briefing.isManual)
                StatusPill(
                  label: 'Manual',
                  color: AppColors.blue,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.index,
    required this.product,
    required this.symbol,
  });

  final int index;
  final BriefingTopProduct product;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.chart[index % AppColors.chart.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            '${Formats.number(product.quantity, decimals: product.quantity % 1 == 0 ? 0 : 1)} · ${Formats.currency(product.revenue, symbol: symbol)}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  const _StockRow({
    required this.title,
    required this.subtitle,
    required this.color,
    this.icon = Icons.warning_amber_rounded,
  });

  final String title;
  final String subtitle;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

class _BriefingHistory extends StatelessWidget {
  const _BriefingHistory({
    required this.briefings,
    required this.selectedId,
    required this.onSelect,
  });

  final List<DailyBriefing> briefings;
  final String selectedId;
  final void Function(DailyBriefing) onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Earlier briefings',
            subtitle: 'Tap a day to read its executive summary',
          ),
          const SizedBox(height: 12),
          if (briefings.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.history_rounded,
              title: 'No history yet',
              message: 'Generated briefings are kept here for easy reference.',
            )
          else
            for (final briefing in briefings.take(30))
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(briefing),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: briefing.id == selectedId
                        ? AppColors.teal.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${briefing.date.day}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              briefing.isToday
                                  ? 'Today'
                                  : Formats.date(briefing.date),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              briefing.sourceLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formats.currency(
                          briefing.metrics.netProfit,
                          symbol: briefing.metrics.currencySymbol,
                        ),
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: briefing.metrics.netProfit >= 0
                              ? AppColors.green
                              : AppColors.red,
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
