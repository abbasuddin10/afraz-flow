import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/data/cache/data_cache.dart';
import '../../../core/models/account.dart';
import '../../../core/models/ledger_entry.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../pos/data/sale.dart';
import '../controllers/ledger_controller.dart';
import '../data/expense.dart';

class ExpenseFormDialog extends StatefulWidget {
  const ExpenseFormDialog({super.key});

  @override
  State<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<ExpenseFormDialog> {
  final LedgerController _controller = Get.find<LedgerController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _reference = TextEditingController();

  String _category = Expense.categories.first;
  String _method = PaymentMethod.cash.value;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _description.dispose();
    _amount.dispose();
    _reference.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await _controller.createExpense(
      category: _category,
      description: _description.text.trim(),
      amount: Formats.parseAmount(_amount.text),
      paymentMethod: _method,
      date: _date,
      reference: _reference.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    value: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      prefixIcon: Icon(Icons.category_outlined, size: 20),
                    ),
                    items: [
                      for (final category in Expense.categories)
                        DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _category = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        Validators.required(value, field: 'Description'),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'e.g. June electricity bill',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => Validators.amount(value),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixText: '${_controller.currency} ',
                            prefixIcon: const Icon(
                              Icons.payments_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _method,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Paid via',
                            prefixIcon: Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 20,
                            ),
                          ),
                          items: [
                            for (final method in PaymentMethod.values)
                              DropdownMenuItem(
                                value: method.value,
                                child: Text(method.label),
                              ),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _method = value);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Expense date',
                              prefixIcon: Icon(
                                Icons.event_outlined,
                                size: 20,
                              ),
                            ),
                            child: Text(Formats.date(_date)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _reference,
                          decoration: const InputDecoration(
                            labelText: 'Reference',
                            hintText: 'Optional',
                            prefixIcon: Icon(
                              Icons.receipt_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: 'Record expense',
            loading: _saving,
            submitIcon: Icons.receipt_long_outlined,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class AccountFormDialog extends StatefulWidget {
  const AccountFormDialog({super.key, this.account});

  final Account? account;

  @override
  State<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends State<AccountFormDialog> {
  final LedgerController _controller = Get.find<LedgerController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _opening;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late AccountType _type;
  bool _saving = false;

  bool get _editing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name ?? '');
    _opening = TextEditingController(
      text: account == null
          ? ''
          : account.openingBalance % 1 == 0
          ? account.openingBalance.toStringAsFixed(0)
          : account.openingBalance.toStringAsFixed(2),
    );
    _phone = TextEditingController(text: account?.phone ?? '');
    _email = TextEditingController(text: account?.email ?? '');
    _address = TextEditingController(text: account?.address ?? '');
    _type = account?.type ?? AccountType.customer;
  }

  @override
  void dispose() {
    _name.dispose();
    _opening.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final existing = widget.account;
    final bool saved;
    if (existing == null) {
      saved = await _controller.createAccount(
        name: _name.text.trim(),
        type: _type,
        openingBalance: Formats.parseAmount(_opening.text),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        address: _address.text.trim(),
      );
    } else {
      saved = await _controller.updateAccount(
        existing.copyWith(
          name: _name.text.trim(),
          type: _type,
          phone: _phone.text.trim(),
          email: _email.text.trim(),
          address: _address.text.trim(),
        ),
      );
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<AccountType>(
                    segments: [
                      ButtonSegment(
                        value: AccountType.customer,
                        label: Text('Customer'.tr),
                        icon: Icon(Icons.person_outline_rounded, size: 17),
                      ),
                      ButtonSegment(
                        value: AccountType.supplier,
                        label: Text('Supplier'.tr),
                        icon: Icon(Icons.local_shipping_outlined, size: 17),
                      ),
                    ],
                    selected: {_type},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isNotEmpty) setState(() => _type = values.first);
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _name,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        Validators.required(value, field: 'Account name'),
                    decoration: InputDecoration(
                      labelText: _type == AccountType.customer
                          ? 'Customer name'
                          : 'Supplier name',
                      prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _opening,
                    enabled: !_editing,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => Validators.amount(
                      value,
                      allowZero: true,
                      field: 'Opening balance',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Opening balance',
                      hintText: '0',
                      prefixIcon: const Icon(
                        Icons.account_balance_outlined,
                        size: 20,
                      ),
                      suffixText: _controller.currency,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          validator: (value) =>
                              Validators.phone(value, optional: true),
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            hintText: 'Optional',
                            prefixIcon: Icon(Icons.phone_outlined, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'Optional',
                            prefixIcon: Icon(
                              Icons.alternate_email_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _address,
                    maxLines: 2,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'Optional',
                      prefixIcon: Icon(Icons.location_on_outlined, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: _editing ? 'Save changes' : 'Create account',
            loading: _saving,
            submitIcon: Icons.person_add_alt_1_rounded,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

class LedgerEntryDialog extends StatefulWidget {
  const LedgerEntryDialog({
    super.key,
    required this.account,
    this.initialType = LedgerEntryType.charge,
  });

  final Account account;
  final LedgerEntryType initialType;

  @override
  State<LedgerEntryDialog> createState() => _LedgerEntryDialogState();
}

class _LedgerEntryDialogState extends State<LedgerEntryDialog> {
  final LedgerController _controller = Get.find<LedgerController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  late final TextEditingController _description;
  late LedgerEntryType _type;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _description = TextEditingController(text: _defaultDescription(_type));
  }

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
    super.dispose();
  }

  String _defaultDescription(LedgerEntryType type) =>
      type == LedgerEntryType.charge
      ? widget.account.type.chargeLabel
      : widget.account.type.paymentLabel;

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final saved = await _controller.recordEntry(
      account: widget.account,
      type: _type,
      amount: Formats.parseAmount(_amount.text),
      description: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isCharge = _type == LedgerEntryType.charge;
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      InitialsAvatar(
                        name: widget.account.name,
                        size: 42,
                        background: AppColors.navySoft,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.account.name,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '${widget.account.type.label} · balance '
                              '${Formats.currency(widget.account.balance, symbol: _controller.currency)}',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<LedgerEntryType>(
                    segments: [
                      ButtonSegment(
                        value: LedgerEntryType.charge,
                        label: Text(widget.account.type.chargeLabel),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: LedgerEntryType.payment,
                        label: Text(widget.account.type.paymentLabel),
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                      ),
                    ],
                    selected: {_type},
                    showSelectedIcon: false,
                    onSelectionChanged: (values) {
                      if (values.isEmpty) return;
                      final oldDefault = _defaultDescription(_type);
                      setState(() => _type = values.first);
                      if (_description.text.trim().isEmpty ||
                          _description.text.trim() == oldDefault) {
                        _description.text = _defaultDescription(_type);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amount,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => Validators.amount(value),
                    decoration: InputDecoration(
                      labelText: isCharge ? 'Charge amount' : 'Payment amount',
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                      suffixText: _controller.currency,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) =>
                        Validators.required(value, field: 'Description'),
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.notes_rounded, size: 20),
                    ),
                  ),
                  if (!isCharge && widget.account.balance > 0) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Outstanding balance: '
                      '${Formats.currency(widget.account.balance, symbol: _controller.currency)}. '
                      'Payments cannot exceed this amount.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          DialogActions(
            cancelLabel: 'Cancel',
            submitLabel: isCharge ? 'Add charge' : 'Record payment',
            loading: _saving,
            submitIcon: Icons.check_rounded,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

Future<void> showAccountStatement(BuildContext context, Account account) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      final height = MediaQuery.sizeOf(sheetContext).height;
      return SizedBox(
        height: height * 0.82,
        child: AccountStatementSheet(account: account),
      );
    },
  );
}

class AccountStatementSheet extends StatefulWidget {
  const AccountStatementSheet({super.key, required this.account});

  final Account account;

  @override
  State<AccountStatementSheet> createState() => _AccountStatementSheetState();
}

class _AccountStatementSheetState extends State<AccountStatementSheet> {
  final LedgerController _controller = Get.find<LedgerController>();

  List<LedgerEntry> _entries = [];
  bool _loading = true;
  String? _error;

  Account get _account {
    for (final item in _controller.accounts) {
      if (item.id == widget.account.id) return item;
    }
    return widget.account;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = await _controller.entriesFor(_account);
      if (!mounted) return;
      setState(() => _entries = values);
    } catch (exception) {
      if (!mounted) return;
      setState(() => _error = 'Could not load this account statement.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _record(LedgerEntryType type) async {
    final saved = await AppDialogs.showForm<bool>(
      context,
      title: type == LedgerEntryType.charge
          ? _account.type.chargeLabel
          : _account.type.paymentLabel,
      subtitle: 'Update ${_account.name}’s khata balance.',
      child: LedgerEntryDialog(account: _account, initialType: type),
    );
    if (saved == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final account = _account;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
          child: Row(
            children: [
              InitialsAvatar(
                name: account.name,
                size: 44,
                background: account.type == AccountType.customer
                    ? AppColors.navySoft
                    : AppColors.purple,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${account.type.label} account · '
                      '${account.phone ?? account.email ?? 'No contact details'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            color: (account.balance > 0 ? AppColors.amber : AppColors.green)
                .withValues(alpha: 0.08),
            borderColor:
                (account.balance > 0 ? AppColors.amber : AppColors.green)
                    .withValues(alpha: 0.25),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.balance > 0
                            ? 'Outstanding balance'
                            : 'Account settled',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        Formats.currency(
                          account.balance,
                          symbol: _controller.currency,
                        ),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: account.balance > 0
                                  ? AppColors.amber
                                  : AppColors.green,
                            ),
                      ),
                    ],
                  ),
                ),
                if (_controller.canManage)
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _record(LedgerEntryType.payment),
                        icon: const Icon(
                          Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: Text('Payment'.tr),
                      ),
                      FilledButton.icon(
                        onPressed: () => _record(LedgerEntryType.charge),
                        icon: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                        ),
                        label: Text(account.type.chargeLabel),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'STATEMENT',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: _loading
              ? const LoadingState(label: 'Loading statement…')
              : _error != null
              ? ErrorState(
                  message: _error!,
                  title: 'Statement unavailable',
                  onRetry: _load,
                )
              : _entries.isEmpty
              ? const EmptyState(
                  compact: true,
                  icon: Icons.menu_book_outlined,
                  title: 'No entries yet',
                  message:
                      'Charges and payments recorded against this account will '
                      'appear here.',
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    // Pull-to-refresh always re-fetches from Supabase.
                    if (Get.isRegistered<DataCache>()) {
                      Get.find<DataCache>().expireAll();
                    }
                    await _load();
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                    itemCount: _entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      final charge = entry.type == LedgerEntryType.charge;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (charge ? AppColors.red : AppColors.green)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            charge
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 17,
                            color: charge ? AppColors.red : AppColors.green,
                          ),
                        ),
                        title: Text(
                          entry.description.isEmpty
                              ? entry.type.label
                              : entry.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          Formats.dateTime(
                            entry.entryDate.isAfter(entry.createdAt)
                                ? entry.entryDate
                                : entry.createdAt,
                          ),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        trailing: Text(
                          '${charge ? '+' : '-'} ${Formats.currency(entry.amount, symbol: _controller.currency)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: charge ? AppColors.red : AppColors.green,
                              ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
