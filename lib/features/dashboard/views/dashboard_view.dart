import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/app_user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../routes/app_routes.dart';
import '../../courier/data/courier_order.dart';
import '../../inventory/data/product.dart';
import '../../pos/data/sale.dart';
import '../../shell/controllers/navigation_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../data/dashboard_snapshot.dart';

class DashboardView extends GetView<DashboardController> {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = controller.session;
    final name = session.user?.fullName.split(' ').first ?? 'there';
    final isNarrow = MediaQuery.sizeOf(context).width < 720;
    if (isNarrow) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _MobileDateFilter(controller: controller),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.loading.value) {
                  return const AppCard(
                    child: LoadingState(label: 'Crunching your latest numbers…'),
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
                final snapshot = controller.snapshot.value;
                return _DashboardBody(
                  snapshot: snapshot,
                  currency: session.currencySymbol,
                  role: session.role,
                );
              }),
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              eyebrow: _greeting(),
              title: 'Hello, $name',
              subtitle:
                  'Here is how ${session.tenant?.name ?? 'your business'} is performing.',
              actions: [
                Obx(
                  () => SegmentedButton<DashboardPeriod>(
                    segments: [
                      for (final period in DashboardPeriod.values)
                        ButtonSegment(value: period, label: Text(period.label)),
                    ],
                    selected: {controller.period.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) {
                        controller.changePeriod(values.first);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Obx(() {
              if (controller.loading.value) {
                return const AppCard(
                  child: LoadingState(label: 'Crunching your latest numbers…'),
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
              final snapshot = controller.snapshot.value;
              return _DashboardBody(
                snapshot: snapshot,
                currency: session.currencySymbol,
                role: session.role,
              );
            }),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.snapshot,
    required this.currency,
    required this.role,
  });

  final DashboardSnapshot snapshot;
  final String currency;
  final MemberRole role;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 1000;
    final phone = width < 720;
    // Phones and tablets always keep the KPI cards two-per-row.
    final stacked = width < 1000;

    if (phone) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ResponsiveGrid(
            minItemWidth: 120,
            maxColumns: 2,
            spacing: 12,
            children: [
              _MetricCard(
                dense: true,
                minimal: true,
                label: 'Revenue',
                value: Formats.currency(snapshot.revenue, symbol: currency),
                hint: '${snapshot.salesCount} sales',
                icon: Icons.trending_up_rounded,
                color: AppColors.teal,
              ),
              if (role.canViewProfit)
                _MetricCard(
                  dense: true,
                  minimal: true,
                  label: 'Net profit',
                  value: Formats.currency(snapshot.netProfit, symbol: currency),
                  hint: '${Formats.percent(snapshot.margin)} margin',
                  icon: Icons.account_balance_wallet_rounded,
                  color: snapshot.netProfit >= 0
                      ? AppColors.green
                      : AppColors.red,
                ),
              _MetricCard(
                dense: true,
                minimal: true,
                label: 'Receivables',
                value: Formats.currency(snapshot.receivable, symbol: currency),
                hint: 'Owed by customers',
                icon: Icons.call_received_rounded,
                color: AppColors.blue,
              ),
              _MetricCard(
                dense: true,
                minimal: true,
                label: 'COD pending',
                value: Formats.currency(snapshot.codPending, symbol: currency),
                hint: '${snapshot.pendingOrders} orders to dispatch',
                icon: Icons.local_shipping_rounded,
                color: AppColors.amber,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _RevenueCard(snapshot: snapshot, currency: currency),
          const SizedBox(height: 16),
          _TopProductsCard(snapshot: snapshot, currency: currency),
          const SizedBox(height: 16),
          _RecentSalesCard(sales: snapshot.recentSales, currency: currency),
          const SizedBox(height: 16),
          _LowStockCard(products: snapshot.lowStock),
          if (snapshot.activeDeliveries.isNotEmpty) ...[
            const SizedBox(height: 16),
            _DeliveriesCard(
              orders: snapshot.activeDeliveries,
              currency: currency,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'Updated ${Formats.relative(snapshot.recentSales.isEmpty ? null : snapshot.recentSales.first.createdAt)} · pull to refresh',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveGrid(
          minItemWidth: stacked ? 120 : 220,
          maxColumns: stacked ? 2 : 4,
          spacing: phone ? 12 : 16,
          children: [
            _MetricCard(
              dense: phone,
              label: 'Revenue',
              value: Formats.currency(snapshot.revenue, symbol: currency),
              hint: phone
                  ? '${snapshot.salesCount} sales'
                  : '${snapshot.salesCount} sales · avg ${Formats.currency(snapshot.averageSale, symbol: currency)}',
              icon: Icons.trending_up_rounded,
              color: AppColors.teal,
            ),
            if (role.canViewProfit)
              _MetricCard(
                dense: phone,
                label: 'Net profit',
                value: Formats.currency(snapshot.netProfit, symbol: currency),
                hint: '${Formats.percent(snapshot.margin)} margin',
                icon: Icons.account_balance_wallet_rounded,
                color: snapshot.netProfit >= 0
                    ? AppColors.green
                    : AppColors.red,
              ),
            _MetricCard(
              dense: phone,
              label: 'Receivables',
              value: Formats.currency(snapshot.receivable, symbol: currency),
              hint: 'Owed by customers',
              icon: Icons.call_received_rounded,
              color: AppColors.blue,
            ),
            _MetricCard(
              dense: phone,
              label: 'COD pending',
              value: Formats.currency(snapshot.codPending, symbol: currency),
              hint: '${snapshot.pendingOrders} orders to dispatch',
              icon: Icons.local_shipping_rounded,
              color: AppColors.amber,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: _RevenueCard(snapshot: snapshot, currency: currency),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 4,
                  child: _TopProductsCard(
                    snapshot: snapshot,
                    currency: currency,
                  ),
                ),
              ],
            ),
          )
        else ...[
          _RevenueCard(snapshot: snapshot, currency: currency),
          const SizedBox(height: 20),
          _TopProductsCard(snapshot: snapshot, currency: currency),
        ],
        const SizedBox(height: 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _RecentSalesCard(
                  sales: snapshot.recentSales,
                  currency: currency,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(child: _LowStockCard(products: snapshot.lowStock)),
            ],
          )
        else ...[
          _RecentSalesCard(sales: snapshot.recentSales, currency: currency),
          const SizedBox(height: 20),
          _LowStockCard(products: snapshot.lowStock),
        ],
        if (snapshot.activeDeliveries.isNotEmpty) ...[
          const SizedBox(height: 20),
          _DeliveriesCard(
            orders: snapshot.activeDeliveries,
            currency: currency,
          ),
        ],
        const SizedBox(height: 12),
        Text(
          'Updated ${Formats.relative(snapshot.recentSales.isEmpty ? null : snapshot.recentSales.first.createdAt)} · pull to refresh',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _MobileDateFilter extends StatelessWidget {
  const _MobileDateFilter({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<DashboardPeriod>(
          segments: [
            for (final period in DashboardPeriod.values)
              ButtonSegment(value: period, label: Text(period.label)),
          ],
          selected: {controller.period.value},
          showSelectedIcon: false,
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          onSelectionChanged: (values) {
            if (values.isNotEmpty) {
              controller.changePeriod(values.first);
            }
          },
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.hint,
    required this.icon,
    required this.color,
    this.dense = false,
    this.minimal = false,
  });

  final String label;
  final String value;
  final String hint;
  final IconData icon;
  final Color color;
  final bool dense;
  final bool minimal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final box = dense ? 30.0 : 38.0;
    if (minimal) {
      return AppCard(
        padding: EdgeInsets.all(dense ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: box,
                  height: box,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(dense ? 9 : 11),
                  ),
                  child: Icon(icon, size: dense ? 16 : 18, color: color),
                ),
                SizedBox(width: dense ? 8 : 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: dense ? 8 : 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: (dense
                        ? theme.textTheme.titleLarge
                        : theme.textTheme.headlineSmall)
                    ?.copyWith(letterSpacing: -0.6, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.all(dense ? 13 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: box,
                height: box,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(dense ? 10 : 11),
                ),
                child: Icon(icon, size: dense ? 17 : 19, color: color),
              ),
              const Spacer(),
              Icon(
                Icons.north_east_rounded,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.4,
                ),
              ),
            ],
          ),
          SizedBox(height: dense ? 12 : 16),
          // Full amounts are always written out — never shortened to "1.2k".
          // The fitted box keeps every digit visible on narrow phones.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style:
                  (dense
                          ? theme.textTheme.titleLarge
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(letterSpacing: -0.6),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: dense ? 5 : 8),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: dense ? 9.5 : null,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.snapshot, required this.currency});

  final DashboardSnapshot snapshot;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final phone = MediaQuery.sizeOf(context).width < 720;
    final gap = phone ? 12.0 : 22.0;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Revenue vs expenses',
            subtitle: 'Daily performance across the selected period',
            trailing: Wrap(
              spacing: 14,
              children: [
                _Legend(color: AppColors.teal, label: 'Revenue'),
                _Legend(color: AppColors.red, label: 'Expenses'),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: phone ? 200 : 248,
            child: snapshot.chart.isEmpty
                ? const EmptyState(
                    compact: true,
                    icon: Icons.show_chart_rounded,
                    title: 'No activity yet',
                    message: 'Sales in this period will appear on the chart.',
                  )
                : _RevenueChart(points: snapshot.chart, currency: currency),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniStat(
                label: 'Revenue',
                value: Formats.currency(snapshot.revenue, symbol: currency),
                color: AppColors.teal,
              ),
              SizedBox(width: gap),
              _MiniStat(
                label: 'Expenses',
                value: Formats.currency(snapshot.expenses, symbol: currency),
                color: AppColors.red,
              ),
              SizedBox(width: gap),
              _MiniStat(
                label: 'Gross profit',
                value: Formats.currency(snapshot.grossProfit, symbol: currency),
                color: theme.colorScheme.onSurface,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.points, required this.currency});

  final List<ChartPoint> points;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var maxValue = 0.0;
    for (final point in points) {
      if (point.revenue > maxValue) maxValue = point.revenue;
      if (point.expenses > maxValue) maxValue = point.expenses;
    }
    final maxY = maxValue <= 0 ? 1000.0 : maxValue * 1.2;
    final interval = maxY / 4;
    final labelEvery = points.length <= 7 ? 1 : (points.length / 6).ceil();

    List<FlSpot> spots(bool revenue) => [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), revenue ? points[i].revenue : points[i].expenses),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: interval,
          getDrawingHorizontalLine: (value) => FlLine(
            color: theme.colorScheme.outlineVariant,
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 60,
              interval: interval,
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                space: 6,
                child: Text(
                  Formats.number(value),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 8.5,
                  ),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                if (index % labelEvery != 0 && index != points.length - 1) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 8,
                  child: Text(
                    (points[index].label ?? Formats.shortDate(points[index].date)),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 9,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.navyDeep,
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  '${spot.barIndex == 0 ? 'Revenue' : 'Expenses'}  '
                  '${Formats.currency(spot.y, symbol: currency)}',
                  const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        lineBarsData: [
          _line(spots: spots(true), color: AppColors.teal, fill: true),
          _line(spots: spots(false), color: AppColors.red, fill: false),
        ],
      ),
      duration: const Duration(milliseconds: 350),
    );
  }

  LineChartBarData _line({
    required List<FlSpot> spots,
    required Color color,
    required bool fill,
  }) => LineChartBarData(
    spots: spots,
    isCurved: true,
    curveSmoothness: 0.28,
    color: color,
    barWidth: 2.4,
    isStrokeCapRound: true,
    dotData: FlDotData(show: spots.length <= 1),
    belowBarData: BarAreaData(
      show: fill,
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0.01)],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  const _TopProductsCard({required this.snapshot, required this.currency});

  final DashboardSnapshot snapshot;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final top = snapshot.topProducts;
    final highest = top.isEmpty ? 1.0 : top.first.revenue;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Top products',
            subtitle: 'Best sellers by revenue',
          ),
          const SizedBox(height: 18),
          if (top.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.local_mall_outlined,
              title: 'No sales yet',
              message: 'Your best sellers will appear once you record sales.',
            )
          else
            for (var i = 0; i < top.length; i++) ...[
              _TopProductRow(
                index: i,
                product: top[i],
                fraction: highest <= 0 ? 0 : top[i].revenue / highest,
                currency: currency,
              ),
              if (i != top.length - 1) const SizedBox(height: 14),
            ],
        ],
      ),
    );
  }
}

class _TopProductRow extends StatelessWidget {
  const _TopProductRow({
    required this.index,
    required this.product,
    required this.fraction,
    required this.currency,
  });

  final int index;
  final TopProduct product;
  final double fraction;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppColors.chart[index % AppColors.chart.length];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                '${index + 1}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 9),
            ProductThumbnail(
              name: product.name,
              imageUrl: product.imageUrl,
              size: 24,
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
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 96),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  Formats.currency(product.revenue, symbol: currency),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            value: fraction.clamp(0, 1),
            minHeight: 4,
            backgroundColor: color.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${Formats.number(product.quantity, decimals: product.quantity % 1 == 0 ? 0 : 1)} units sold',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _RecentSalesCard extends StatelessWidget {
  const _RecentSalesCard({required this.sales, required this.currency});

  final List<Sale> sales;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent sales',
            subtitle: 'Latest invoices across every channel',
            trailing: TextButton(
              onPressed: () =>
                  Get.find<NavigationController>().go(AppSection.pos),
              child: Text('New sale'.tr),
            ),
          ),
          const SizedBox(height: 10),
          if (sales.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No sales recorded',
              message: 'Complete a sale at the POS and it will show up here.',
            )
          else
            for (final sale in sales)
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => Get.toNamed(Routes.saleDetail, arguments: sale),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.teal.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.receipt_long_rounded,
                          size: 16,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sale.invoiceNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '${sale.customerName} · ${Formats.dateTime(sale.createdAt)}',
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
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 108),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                Formats.currency(sale.total, symbol: currency),
                                maxLines: 1,
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                          StatusPill(
                            label: sale.paymentMethod.label,
                            color: sale.paymentMethod == PaymentMethod.credit
                                ? AppColors.amber
                                : AppColors.green,
                            dense: true,
                          ),
                        ],
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

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Low stock alerts',
            subtitle: 'Reorder these before they run out',
            trailing: TextButton(
              onPressed: () =>
                  Get.find<NavigationController>().go(AppSection.inventory),
              child: Text('Open stock'.tr),
            ),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.inventory_2_outlined,
              title: 'Stock looks healthy',
              message: 'No products are at or below their alert level.',
            )
          else
            for (final product in products)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    ProductThumbnail(
                      name: product.name,
                      imageUrl: product.imageUrl,
                      size: 34,
                      background: product.isOutOfStock
                          ? AppColors.red
                          : AppColors.amber,
                      foreground: Colors.white,
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${product.sku} · ${product.category}',
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
                    const SizedBox(width: 8),
                    StatusPill(
                      label: product.stockLabel,
                      color: product.isOutOfStock
                          ? AppColors.red
                          : AppColors.amber,
                      dense: true,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _DeliveriesCard extends StatelessWidget {
  const _DeliveriesCard({required this.orders, required this.currency});

  final List<CourierOrder> orders;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Active deliveries',
            subtitle: 'Parcels currently with a courier',
            trailing: TextButton(
              onPressed: () =>
                  Get.find<NavigationController>().go(AppSection.courier),
              child: Text('Track all'.tr),
            ),
          ),
          const SizedBox(height: 12),
          ResponsiveGrid(
            minItemWidth: 150,
            maxColumns: 2,
            spacing: 12,
            children: [
              for (final order in orders)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              order.orderNo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusPill(
                            label: order.status.label,
                            color: order.status.color,
                            dense: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        order.customerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${order.city} · ${order.courierPartner}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      if (order.hasCod) ...[
                        const SizedBox(height: 8),
                        Text(
                          'COD ${Formats.currency(order.codAmount, symbol: currency)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: AppColors.amber,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
