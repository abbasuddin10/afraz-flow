import '../../../../core/models/account.dart';
import '../../courier/data/courier_order.dart';
import '../../courier/data/courier_repository.dart';
import '../../inventory/data/product_repository.dart';
import '../../ledger/data/account_repository.dart';
import '../../pos/data/sale.dart';
import '../../pos/data/sale_repository.dart';
import '../data/dashboard_snapshot.dart';

class DashboardRepository {
  DashboardRepository({
    required SaleRepository sales,
    required ProductRepository products,
    required AccountRepository accounts,
    required ExpenseRepository expenses,
    required CourierRepository couriers,
  }) : _sales = sales,
       _products = products,
       _accounts = accounts,
       _expenses = expenses,
       _couriers = couriers;

  final SaleRepository _sales;
  final ProductRepository _products;
  final AccountRepository _accounts;
  final ExpenseRepository _expenses;
  final CourierRepository _couriers;

  Future<DashboardSnapshot> load(DashboardPeriod period) async {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: period.days - 1));

    final salesFuture = _sales.all(limit: 1000);
    final expensesFuture = _expenses.all(limit: 500);
    final productsFuture = _products.all();
    final accountsFuture = _accounts.all();
    final couriersFuture = _couriers.all(limit: 300);

    final sales = await salesFuture;
    final expenses = await expensesFuture;
    final products = await productsFuture;
    final accounts = await accountsFuture;
    final couriers = await couriersFuture;

    final periodSales = sales
        .where(
          (sale) =>
              sale.status == SaleStatus.completed &&
              !sale.createdAt.isBefore(start),
        )
        .toList();
    final periodExpenses = expenses
        .where((expense) => !expense.expenseDate.isBefore(start))
        .toList();

    final revenue = periodSales.fold<double>(0, (sum, sale) => sum + sale.total);
    final costOfGoods = periodSales.fold<double>(
      0,
      (sum, sale) => sum + sale.totalCost,
    );
    final totalExpenses = periodExpenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final salesCount = periodSales.length;

    final chart = <ChartPoint>[];
    for (var offset = period.days - 1; offset >= 0; offset--) {
      final day = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: offset));
      final next = day.add(const Duration(days: 1));
      final dayRevenue = periodSales
          .where(
            (sale) =>
                !sale.createdAt.isBefore(day) && sale.createdAt.isBefore(next),
          )
          .fold<double>(0, (sum, sale) => sum + sale.total);
      final dayExpenses = periodExpenses
          .where(
            (expense) =>
                !expense.expenseDate.isBefore(day) &&
                expense.expenseDate.isBefore(next),
          )
          .fold<double>(0, (sum, expense) => sum + expense.amount);
      chart.add(
        ChartPoint(date: day, revenue: dayRevenue, expenses: dayExpenses),
      );
    }

    final productStats = <String, TopProduct>{};
    for (final sale in periodSales) {
      for (final item in sale.items) {
        final key = item.productId.isEmpty ? item.productName : item.productId;
        final existing = productStats[key];
        productStats[key] = TopProduct(
          name: item.productName,
          quantity: (existing?.quantity ?? 0) + item.quantity,
          revenue: (existing?.revenue ?? 0) + item.lineTotal,
        );
      }
    }
    final topProducts = productStats.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    final lowStock = products.where((product) => product.isLowStock).toList()
      ..sort((a, b) => a.stockQty.compareTo(b.stockQty));

    final recentSales = List<Sale>.from(sales)..sort(
      (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    final activeDeliveries = couriers
        .where((order) => order.status.isOpen)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final codPending = couriers
        .where(
          (order) =>
              order.codPending &&
              order.status != CourierStatus.returned &&
              order.status != CourierStatus.cancelled,
        )
        .fold<double>(0, (sum, order) => sum + order.codAmount);

    final receivable = accounts
        .where((account) => account.type == AccountType.customer)
        .fold<double>(0, (sum, account) => sum + account.balance);
    final payable = accounts
        .where((account) => account.type == AccountType.supplier)
        .fold<double>(0, (sum, account) => sum + account.balance);

    return DashboardSnapshot(
      revenue: revenue,
      expenses: totalExpenses,
      costOfGoods: costOfGoods,
      receivable: receivable,
      payable: payable,
      salesCount: salesCount,
      averageSale: salesCount == 0 ? 0 : revenue / salesCount,
      chart: chart,
      topProducts: topProducts.take(5).toList(),
      lowStock: lowStock.take(6).toList(),
      recentSales: recentSales.take(6).toList(),
      activeDeliveries: activeDeliveries.take(4).toList(),
      codPending: codPending,
      pendingOrders: couriers
          .where((order) => order.status == CourierStatus.pending)
          .length,
    );
  }

  /// Lightweight counts for shell badges.
  Future<int> lowStockCount() async {
    final products = await _products.all();
    return products.where((product) => product.isLowStock).length;
  }

  Future<({int pending, int lowStock, double cod})> badges() async {
    final productsFuture = _products.all();
    final couriersFuture = _couriers.all(limit: 300);
    final products = await productsFuture;
    final couriers = await couriersFuture;
    return (
      pending: couriers.where((o) => o.status == CourierStatus.pending).length,
      lowStock: products.where((product) => product.isLowStock).length,
      cod: couriers
          .where((o) => o.codPending && o.status == CourierStatus.delivered)
          .fold<double>(0, (sum, o) => sum + o.codAmount),
    );
  }
}
