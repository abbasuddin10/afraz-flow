import 'package:get/get.dart';

import '../../../../core/models/account.dart';
import '../../../../core/models/ledger_entry.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/feedback.dart';
import '../../dashboard/data/dashboard_snapshot.dart';
import '../data/account_repository.dart';
import '../data/expense.dart';

class LedgerController extends GetxController {
  final AccountRepository _accounts = Get.find<AccountRepository>();
  final ExpenseRepository _expenses = Get.find<ExpenseRepository>();
  final CashBookRepository _cashbook = Get.find<CashBookRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxInt tab = 0.obs;
  final RxList<Account> accounts = <Account>[].obs;
  final RxList<LedgerEntry> entries = <LedgerEntry>[].obs;
  final RxList<Expense> expenses = <Expense>[].obs;
  final RxList<CashBookEntry> cashbook = <CashBookEntry>[].obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;
  final RxnString error = RxnString();
  final RxString accountFilter = 'all'.obs;

  String get currency => _session.currencySymbol;
  bool get canManage => _session.role.canManageFinance;

  List<Account> get filteredAccounts {
    final filter = accountFilter.value;
    if (filter == 'all') return accounts;
    final type = AccountType.fromValue(filter.endsWith('s') ? filter.substring(0, filter.length - 1) : filter);
    return accounts.where((account) => account.type == type).toList();
  }

  double get receivable => accounts
      .where((account) => account.type == AccountType.customer)
      .fold(0, (sum, account) => sum + account.balance);
  double get payable => accounts
      .where((account) => account.type == AccountType.supplier)
      .fold(0, (sum, account) => sum + account.balance);
  double get totalExpenses =>
      expenses.fold(0, (sum, expense) => sum + expense.amount);
  double get cashIn => cashbook
      .where((entry) => entry.isInflow)
      .fold(0, (sum, entry) => sum + entry.amount);
  double get cashOut => cashbook
      .where((entry) => !entry.isInflow)
      .fold(0, (sum, entry) => sum + entry.amount);
  double get netCash => cashIn - cashOut;

  double get expensesThisMonth {
    final now = DateTime.now();
    return expenses
        .where(
          (expense) =>
              expense.expenseDate.year == now.year &&
              expense.expenseDate.month == now.month,
        )
        .fold(0, (sum, expense) => sum + expense.amount);
  }

  Map<String, double> get expensesByCategory {
    final map = <String, double>{};
    for (final expense in expenses) {
      map.update(
        expense.category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }
    return map;
  }

  List<CashBookEntry> get todayEntries {
    final now = DateTime.now();
    return cashbook
        .where(
          (entry) =>
              entry.date.year == now.year &&
              entry.date.month == now.month &&
              entry.date.day == now.day,
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      final accountsFuture = _accounts.all();
      final entriesFuture = _accounts.allEntries();
      final expensesFuture = _expenses.all();
      final cashbookFuture = _cashbook.build();
      accounts.assignAll(await accountsFuture);
      entries.assignAll(await entriesFuture);
      expenses.assignAll(await expensesFuture);
      cashbook.assignAll(await cashbookFuture);
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  void setTab(int value) => tab.value = value;
  void setAccountFilter(String value) => accountFilter.value = value;

  Future<List<LedgerEntry>> entriesFor(Account account) =>
      _accounts.entries(account.id);

  Future<bool> createExpense({
    required String category,
    required String description,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    String? reference,
  }) async {
    saving.value = true;
    try {
      await _expenses.create(
        category: category,
        description: description,
        amount: amount,
        paymentMethod: paymentMethod,
        expenseDate: date,
        reference: reference,
      );
      await load(silent: true);
      showAppMessage('Expense recorded.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> deleteExpense(Expense expense) async {
    saving.value = true;
    try {
      await _expenses.delete(expense.id);
      await load(silent: true);
      showAppMessage('Expense deleted.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> createAccount({
    required String name,
    required AccountType type,
    required double openingBalance,
    String? phone,
    String? email,
    String? address,
  }) async {
    saving.value = true;
    try {
      await _accounts.create(
        name: name,
        type: type,
        openingBalance: openingBalance,
        phone: phone,
        email: email,
        address: address,
      );
      await load(silent: true);
      showAppMessage('${type.label} account created.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> recordEntry({
    required Account account,
    required LedgerEntryType type,
    required double amount,
    required String description,
  }) async {
    saving.value = true;
    try {
      await _accounts.recordEntry(
        account: account,
        type: type,
        amount: amount,
        description: description,
      );
      await load(silent: true);
      showAppMessage(
        type == LedgerEntryType.charge
            ? 'Charge added to ${account.name}.'
            : 'Payment recorded for ${account.name}.',
      );
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> updateAccount(Account account) async {
    saving.value = true;
    try {
      await _accounts.update(account);
      await load(silent: true);
      showAppMessage('Account updated.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  String format(double value) => Formats.currency(value, symbol: currency);
}
