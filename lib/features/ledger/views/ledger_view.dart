import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/account.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../dashboard/data/dashboard_snapshot.dart';
import '../controllers/ledger_controller.dart';
import '../data/expense.dart';
import 'ledger_dialogs.dart';

class LedgerView extends StatefulWidget {
  const LedgerView({super.key});

  @override
  State<LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends State<LedgerView> {
  final LedgerController controller = Get.find<LedgerController>();
  final SessionService session = Get.find<SessionService>();
  final TextEditingController _search = TextEditingController();

  String _query = '';

  bool get canManage => controller.canManage;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _addExpense() async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Record an expense',
      subtitle: 'Cash out of the business is tracked in the cash book.',
      child: const ExpenseFormDialog(),
    );
  }

  Future<void> _addAccount() async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'New khata account',
      subtitle: 'Track dues with a customer or payments owed to a supplier.',
      child: const AccountFormDialog(),
    );
  }

  Future<void> _editAccount(Account account) async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Edit account',
      subtitle: 'Update ${account.name}’s contact details.',
      child: AccountFormDialog(account: account),
    );
  }

  Future<void> _record(Account account, LedgerEntryType type) async {
    await AppDialogs.showForm<bool>(
      context,
      title: type == LedgerEntryType.charge
          ? account.type.chargeLabel
          : account.type.paymentLabel,
      subtitle: 'Update ${account.name}’s khata balance.',
      child: LedgerEntryDialog(account: account, initialType: type),
    );
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Delete this expense?',
      message:
          '${expense.description} · ${Formats.currency(expense.amount, symbol: controller.currency)} '
          'will be removed from your cash book.',
      confirmLabel: 'Delete',
      destructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed) await controller.deleteExpense(expense);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return Padding(
      padding: EdgeInsets.all(wide ? 28 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'Money',
            title: 'Cash Book & Khata',
            subtitle:
                'Daily cash flow, customer dues, supplier payables and expenses.',
            actions: [
              if (canManage)
                OutlinedButton.icon(
                  onPressed: _addAccount,
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: Text('New account'.tr),
                ),
              if (canManage)
                FilledButton.icon(
                  onPressed: _addExpense,
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text('Record expense'.tr),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Obx(() {
              if (controller.loading.value) {
                return const AppCard(
                  child: LoadingState(label: 'Building your cash book…'),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveGrid(
          minItemWidth: 190,
          maxColumns: 4,
          children: [
            _SummaryTile(
              label: 'Net cash',
              value: Formats.currency(
                controller.netCash,
                symbol: controller.currency,
              ),
              hint:
                  '${Formats.currency(controller.cashIn, symbol: controller.currency)} in · '
                  '${Formats.currency(controller.cashOut, symbol: controller.currency)} out',
              icon: Icons.account_balance_wallet_outlined,
              color: controller.netCash >= 0 ? AppColors.teal : AppColors.red,
            ),
            _SummaryTile(
              label: 'Receivables',
              value: Formats.currency(
                controller.receivable,
                symbol: controller.currency,
              ),
              hint: 'Owed by customers',
              icon: Icons.call_received_rounded,
              color: AppColors.blue,
            ),
            _SummaryTile(
              label: 'Payables',
              value: Formats.currency(
                controller.payable,
                symbol: controller.currency,
              ),
              hint: 'Owed to suppliers',
              icon: Icons.call_made_rounded,
              color: AppColors.purple,
            ),
            _SummaryTile(
              label: 'Expenses this month',
              value: Formats.currency(
                controller.expensesThisMonth,
                symbol: controller.currency,
              ),
              hint: '${controller.expenses.length} recorded',
              icon: Icons.trending_down_rounded,
              color: AppColors.amber,
            ),
          ],
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(
                value: 0,
                label: Text('Cash book'.tr),
                icon: Icon(Icons.menu_book_outlined, size: 17),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Khata accounts'.tr),
                icon: Icon(Icons.people_alt_outlined, size: 17),
              ),
              ButtonSegment(
                value: 2,
                label: Text('Expenses'.tr),
                icon: Icon(Icons.receipt_long_outlined, size: 17),
              ),
            ],
            selected: {controller.tab.value},
            showSelectedIcon: false,
            onSelectionChanged: (values) {
              if (values.isNotEmpty) controller.setTab(values.first);
            },
          ),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: Obx(
            () => switch (controller.tab.value) {
              1 => _AccountsTab(
                  controller: controller,
                  search: _search,
                  query: _query,
                  onQueryChanged: (value) => setState(() => _query = value),
                  onAdd: canManage ? _addAccount : null,
                  onEdit: canManage ? _editAccount : null,
                  onRecord: canManage ? _record : null,
                ),
              2 => _ExpensesTab(
                  controller: controller,
                  onAdd: canManage ? _addExpense : null,
                  onDelete: canManage ? _deleteExpense : null,
                ),
              _ => _CashBookTab(controller: controller),
            },
          ),
        ),
      ],
    );
  }
}

class _CashBookTab extends StatelessWidget {
  const _CashBookTab({required this.controller});

  final LedgerController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.cashbook;
    final today = controller.todayEntries;
    return RefreshIndicator(
      onRefresh: () => controller.load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.today_outlined,
                      size: 18,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Today',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${today.length} transaction${today.length == 1 ? '' : 's'}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _CashFigure(
                        label: 'Cash in',
                        value: controller.cashIn,
                        color: AppColors.green,
                        icon: Icons.south_west_rounded,
                        currency: controller.currency,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CashFigure(
                        label: 'Cash out',
                        value: controller.cashOut,
                        color: AppColors.red,
                        icon: Icons.north_east_rounded,
                        currency: controller.currency,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _CashFigure(
                        label: 'Net',
                        value: controller.netCash,
                        color: controller.netCash >= 0
                            ? AppColors.teal
                            : AppColors.red,
                        icon: Icons.balance_rounded,
                        currency: controller.currency,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const AppCard(
              child: EmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No cash movement yet',
                message:
                    'Sales, expenses and khata payments will appear here as '
                    'they happen.',
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CashBookTile(entry: entry, currency: controller.currency),
              ),
        ],
      ),
    );
  }
}

class _CashBookTile extends StatelessWidget {
  const _CashBookTile({required this.entry, required this.currency});

  final CashBookEntry entry;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final inflow = entry.isInflow;
    final color = inflow ? AppColors.green : AppColors.red;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              inflow ? Icons.south_west_rounded : Icons.north_east_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${entry.subtitle} · ${Formats.date(entry.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${inflow ? '+' : '-'} ${Formats.currency(entry.amount, symbol: currency)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _CashFigure extends StatelessWidget {
  const _CashFigure({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
    required this.currency,
  });

  final String label;
  final double value;
  final Color color;
  final IconData icon;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formats.currency(value, symbol: currency),
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends StatelessWidget {
  const _AccountsTab({
    required this.controller,
    required this.search,
    required this.query,
    required this.onQueryChanged,
    this.onAdd,
    this.onEdit,
    this.onRecord,
  });

  final LedgerController controller;
  final TextEditingController search;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback? onAdd;
  final ValueChanged<Account>? onEdit;
  final Future<void> Function(Account, LedgerEntryType)? onRecord;

  List<Account> get _accounts {
    final normalized = query.trim().toLowerCase();
    return controller.filteredAccounts.where((account) {
      if (normalized.isEmpty) return true;
      return account.name.toLowerCase().contains(normalized) ||
          (account.phone ?? '').toLowerCase().contains(normalized) ||
          (account.email ?? '').toLowerCase().contains(normalized);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final accounts = _accounts;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 700;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppSearchField(
                  width: narrow ? constraints.maxWidth : 300,
                  hint: 'Search by name, phone or email',
                  controller: search,
                  onChanged: onQueryChanged,
                ),
                Obx(
                  () => SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'all', label: Text('All'.tr)),
                      ButtonSegment(value: 'customers', label: Text('Customers'.tr)),
                      ButtonSegment(value: 'suppliers', label: Text('Suppliers'.tr)),
                    ],
                    selected: {controller.accountFilter.value},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) {
                        controller.setAccountFilter(values.first);
                      }
                    },
                  ),
                ),
                if (onAdd != null)
                  TextButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: Text('Add account'.tr),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Expanded(
          child: accounts.isEmpty
              ? AppCard(
                  child: EmptyState(
                    icon: Icons.people_alt_outlined,
                    title: 'No accounts found',
                    message:
                        'Add a customer or supplier to start tracking dues and '
                        'payments.',
                    action: onAdd == null
                        ? null
                        : FilledButton.icon(
                            onPressed: onAdd,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text('Add account'.tr),
                          ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => controller.load(silent: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 20),
                    children: [
                      for (final account in accounts)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _AccountTile(
                            account: account,
                            currency: controller.currency,
                            canManage: onRecord != null,
                            onStatement: () =>
                                showAccountStatement(context, account),
                            onCharge: onRecord == null
                                ? null
                                : () => onRecord!(
                                    account,
                                    LedgerEntryType.charge,
                                  ),
                            onPayment: onRecord == null
                                ? null
                                : () => onRecord!(
                                    account,
                                    LedgerEntryType.payment,
                                  ),
                            onEdit: onEdit == null
                                ? null
                                : () => onEdit!(account),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.currency,
    required this.canManage,
    required this.onStatement,
    this.onCharge,
    this.onPayment,
    this.onEdit,
  });

  final Account account;
  final String currency;
  final bool canManage;
  final VoidCallback onStatement;
  final VoidCallback? onCharge;
  final VoidCallback? onPayment;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isCustomer = account.type == AccountType.customer;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onStatement,
      child: Row(
        children: [
          InitialsAvatar(
            name: account.name,
            size: 42,
            background: isCustomer ? AppColors.navySoft : AppColors.purple,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        account.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(
                      label: account.type.label,
                      color: isCustomer ? AppColors.blue : AppColors.purple,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  account.phone?.isNotEmpty == true
                      ? account.phone!
                      : account.email?.isNotEmpty == true
                      ? account.email!
                      : 'Statement & balance',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                Formats.currency(account.balance, symbol: currency),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: account.balance > 0.009
                      ? AppColors.amber
                      : AppColors.green,
                ),
              ),
              Text(
                account.balance > 0.009 ? 'Outstanding' : 'Settled',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (canManage)
            PopupMenuButton<String>(
              tooltip: 'Account actions',
              icon: const Icon(Icons.more_vert_rounded, size: 19),
              onSelected: (value) {
                switch (value) {
                  case 'statement':
                    onStatement();
                  case 'charge':
                    onCharge?.call();
                  case 'payment':
                    onPayment?.call();
                  case 'edit':
                    onEdit?.call();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'statement',
                  child: _MenuRow(
                    icon: Icons.menu_book_outlined,
                    label: 'View statement',
                  ),
                ),
                PopupMenuItem(
                  value: 'charge',
                  child: _MenuRow(
                    icon: Icons.arrow_upward_rounded,
                    label: account.type.chargeLabel,
                  ),
                ),
                PopupMenuItem(
                  value: 'payment',
                  child: _MenuRow(
                    icon: Icons.arrow_downward_rounded,
                    label: account.type.paymentLabel,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'edit',
                  child: _MenuRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit account',
                  ),
                ),
              ],
            )
          else
            const Icon(Icons.chevron_right_rounded, size: 19),
        ],
      ),
    );
  }
}

class _ExpensesTab extends StatelessWidget {
  const _ExpensesTab({
    required this.controller,
    this.onAdd,
    this.onDelete,
  });

  final LedgerController controller;
  final VoidCallback? onAdd;
  final Future<void> Function(Expense)? onDelete;

  @override
  Widget build(BuildContext context) {
    final expenses = controller.expenses;
    final byCategory = controller.expensesByCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return RefreshIndicator(
      onRefresh: () => controller.load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Expenses this month',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            Formats.currency(
                              controller.expensesThisMonth,
                              symbol: controller.currency,
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                    if (onAdd != null)
                      FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Add expense'.tr),
                      ),
                  ],
                ),
                if (byCategory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final item in byCategory.take(6))
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.inkMuted.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '${item.key} · ${Formats.currency(item.value, symbol: controller.currency)}',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (expenses.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses recorded',
                message:
                    'Rent, salaries, logistics and other cash-outs will appear '
                    'here once recorded.',
                action: onAdd == null
                    ? null
                    : FilledButton.icon(
                        onPressed: onAdd,
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Record expense'.tr),
                      ),
              ),
            )
          else
            for (final expense in expenses)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ExpenseTile(
                  expense: expense,
                  currency: controller.currency,
                  onDelete: onDelete == null
                      ? null
                      : () => onDelete!(expense),
                ),
              ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    required this.expense,
    required this.currency,
    this.onDelete,
  });

  final Expense expense;
  final String currency;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 18,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.description,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${expense.category} · ${Formats.date(expense.expenseDate)} · '
                  '${expense.paymentMethod.toUpperCase()}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            Formats.currency(expense.amount, symbol: currency),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.red,
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete expense',
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 18,
                color: AppColors.inkMuted,
              ),
            ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const Spacer(),
              Icon(
                Icons.insights_rounded,
                size: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hint,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9.5,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17),
        const SizedBox(width: 9),
        Text(label),
      ],
    );
  }
}
