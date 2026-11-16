import 'package:uuid/uuid.dart';

import '../../../../core/data/data_store.dart';
import '../../../../core/models/account.dart';
import '../../../../core/models/ledger_entry.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/json_helpers.dart';
import '../../dashboard/data/dashboard_snapshot.dart';
import '../../pos/data/sale_repository.dart';
import '../data/expense.dart';

class AccountRepository {
  AccountRepository(this._store, this._session);

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;

  Future<List<Account>> all({AccountType? type}) async {
    final rows = await _store.select(
      'ledger_accounts',
      eq: {
        'tenant_id': _session.requireTenantId(),
        if (type != null) 'account_type': type.value,
      },
      orderBy: 'name',
      ascending: true,
    );
    return rows.map(Account.fromJson).toList();
  }

  Future<List<Account>> customers() => all(type: AccountType.customer);
  Future<List<Account>> suppliers() => all(type: AccountType.supplier);

  Future<List<LedgerEntry>> entries(String accountId) async {
    final rows = await _store.select(
      'ledger_entries',
      eq: {'tenant_id': _session.requireTenantId(), 'account_id': accountId},
      orderBy: 'created_at',
      limit: 500,
    );
    return rows.map(LedgerEntry.fromJson).toList();
  }

  Future<List<LedgerEntry>> allEntries({int limit = 1000}) async {
    final rows = await _store.select(
      'ledger_entries',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'created_at',
      limit: limit,
    );
    return rows.map(LedgerEntry.fromJson).toList();
  }

  Future<Account> create({
    required String name,
    required AccountType type,
    double openingBalance = 0,
    String? phone,
    String? email,
    String? address,
  }) async {
    if (name.trim().isEmpty) {
      throw const AppFailure('Account name is required.');
    }
    final now = DateTime.now();
    final account = Account(
      id: _uuid.v4(),
      tenantId: _session.requireTenantId(),
      name: name.trim(),
      type: type,
      openingBalance: openingBalance,
      balance: openingBalance,
      phone: phone?.trim().isEmpty == true ? null : phone?.trim(),
      email: email?.trim().isEmpty == true ? null : email?.trim(),
      address: address?.trim().isEmpty == true ? null : address?.trim(),
      createdAt: now,
      updatedAt: now,
    );
    final row = await _store.insert('ledger_accounts', account.toJson());
    return Account.fromJson(row);
  }

  Future<Account> update(Account account) async {
    final row = await _store.update(
      'ledger_accounts',
      account.id,
      account.toJson(),
    );
    return Account.fromJson(row);
  }

  Future<void> recordEntry({
    required Account account,
    required LedgerEntryType type,
    required double amount,
    required String description,
    DateTime? date,
  }) async {
    if (amount <= 0) {
      throw const AppFailure('Amount must be greater than zero.');
    }
    if (type == LedgerEntryType.payment && amount > account.balance) {
      throw AppFailure(
        'Payment exceeds the outstanding balance of '
        '${account.balance.toStringAsFixed(2)}.',
      );
    }
    final now = DateTime.now();
    if (_store.isRemote) {
      await _store.rpc('record_ledger_entry', {
        'p_tenant_id': _session.requireTenantId(),
        'p_account_id': account.id,
        'p_entry_type': type.value,
        'p_amount': amount,
        'p_description': description.trim(),
      });
      return;
    }
    final entry = LedgerEntry(
      id: _uuid.v4(),
      tenantId: _session.requireTenantId(),
      accountId: account.id,
      type: type,
      amount: amount,
      description: description.trim(),
      entryDate: date ?? now,
      createdAt: now,
    );
    await _store.insert('ledger_entries', entry.toJson());
    await _store.update('ledger_accounts', account.id, {
      'balance': type.apply(account.balance, amount),
      'updated_at': toIso(now),
    });
  }
}

class ExpenseRepository {
  ExpenseRepository(this._store, this._session);

  static const Uuid _uuid = Uuid();

  final DataStore _store;
  final SessionService _session;

  Future<List<Expense>> all({int limit = 500}) async {
    final rows = await _store.select(
      'expenses',
      eq: {'tenant_id': _session.requireTenantId()},
      orderBy: 'expense_date',
      limit: limit,
    );
    return rows.map(Expense.fromJson).toList();
  }

  Future<Expense> create({
    required String category,
    required String description,
    required double amount,
    required String paymentMethod,
    required DateTime expenseDate,
    String? reference,
  }) async {
    if (description.trim().isEmpty) {
      throw const AppFailure('Add a short description for this expense.');
    }
    if (amount <= 0) {
      throw const AppFailure('Amount must be greater than zero.');
    }
    final expense = Expense(
      id: _uuid.v4(),
      tenantId: _session.requireTenantId(),
      category: category,
      description: description.trim(),
      amount: amount,
      paymentMethod: paymentMethod,
      expenseDate: expenseDate,
      reference: reference?.trim().isEmpty == true ? null : reference?.trim(),
      createdAt: DateTime.now(),
    );
    final row = await _store.insert('expenses', expense.toJson());
    return Expense.fromJson(row);
  }

  Future<void> delete(String id) => _store.delete('expenses', id);
}

/// Builds the unified daily cash book from sales, expenses and account
/// payments. Kept separate so the ledger screen does not duplicate query logic.
class CashBookRepository {
  CashBookRepository(this._sales, this._expenses, this._accounts);

  final SaleRepository _sales;
  final ExpenseRepository _expenses;
  final AccountRepository _accounts;

  Future<List<CashBookEntry>> build({int days = 30}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final sales = await _sales.all(limit: 500);
    final expenses = await _expenses.all(limit: 500);
    final entries = await _accounts.allEntries(limit: 500);
    final accounts = await _accounts.all();
    final accountById = {for (final account in accounts) account.id: account};

    final cashbook = <CashBookEntry>[];
    for (final sale in sales) {
      if (sale.createdAt.isBefore(from) || sale.paidAmount <= 0) continue;
      cashbook.add(
        CashBookEntry(
          id: 'sale-${sale.id}',
          title: sale.invoiceNo,
          subtitle: 'Sale · ${sale.customerName}',
          amount: sale.paidAmount,
          isInflow: true,
          date: sale.createdAt,
        ),
      );
    }
    for (final expense in expenses) {
      if (expense.expenseDate.isBefore(from)) continue;
      cashbook.add(
        CashBookEntry(
          id: 'expense-${expense.id}',
          title: expense.description,
          subtitle: 'Expense · ${expense.category}',
          amount: expense.amount,
          isInflow: false,
          date: expense.expenseDate,
        ),
      );
    }
    for (final entry in entries) {
      if (entry.createdAt.isBefore(from) ||
          entry.type != LedgerEntryType.payment) {
        continue;
      }
      final account = accountById[entry.accountId];
      if (account == null) continue;
      cashbook.add(
        CashBookEntry(
          id: 'ledger-${entry.id}',
          title: entry.description.isEmpty ? 'Account payment' : entry.description,
          subtitle: '${account.name} · ${account.type.label}',
          amount: entry.amount,
          isInflow: account.type == AccountType.customer,
          date: entry.createdAt,
        ),
      );
    }
    cashbook.sort((a, b) => b.date.compareTo(a.date));
    return cashbook;
  }
}
