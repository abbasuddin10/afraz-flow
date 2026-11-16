import '../../../core/models/account.dart';
import '../../inventory/data/product.dart';
import '../../pos/data/sale.dart';
import '../../courier/data/courier_order.dart';

enum DashboardPeriod {
  today(1, 'Today'),
  week(7, '7 Days'),
  fortnight(14, '14 Days'),
  month(30, '30 Days');

  const DashboardPeriod(this.days, this.label);
  final int days;
  final String label;
}

class ChartPoint {
  const ChartPoint({
    required this.date,
    required this.revenue,
    required this.expenses,
  });

  final DateTime date;
  final double revenue;
  final double expenses;
}

class TopProduct {
  const TopProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
  });

  final String name;
  final double quantity;
  final double revenue;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.revenue,
    required this.expenses,
    required this.costOfGoods,
    required this.receivable,
    required this.payable,
    required this.salesCount,
    required this.averageSale,
    required this.chart,
    required this.topProducts,
    required this.lowStock,
    required this.recentSales,
    required this.activeDeliveries,
    required this.codPending,
    required this.pendingOrders,
  });

  final double revenue;
  final double expenses;
  final double costOfGoods;
  final double receivable;
  final double payable;
  final int salesCount;
  final double averageSale;
  final List<ChartPoint> chart;
  final List<TopProduct> topProducts;
  final List<Product> lowStock;
  final List<Sale> recentSales;
  final List<CourierOrder> activeDeliveries;
  final double codPending;
  final int pendingOrders;

  double get grossProfit => revenue - costOfGoods;
  double get netProfit => grossProfit - expenses;
  double get margin => revenue <= 0 ? 0 : (netProfit / revenue) * 100;

  static DashboardSnapshot empty() => const DashboardSnapshot(
    revenue: 0,
    expenses: 0,
    costOfGoods: 0,
    receivable: 0,
    payable: 0,
    salesCount: 0,
    averageSale: 0,
    chart: [],
    topProducts: [],
    lowStock: [],
    recentSales: [],
    activeDeliveries: [],
    codPending: 0,
    pendingOrders: 0,
  );
}

/// A unified cash-book line built from sales, expenses and ledger payments.
class CashBookEntry {
  const CashBookEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.isInflow,
    required this.date,
  });

  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final bool isInflow;
  final DateTime date;

  double get signedAmount => isInflow ? amount : -amount;
}

class AccountWithEntries {
  const AccountWithEntries({required this.account, required this.entries});

  final Account account;
  final List<dynamic> entries;
}
