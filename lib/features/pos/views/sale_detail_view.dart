import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/services/app_services.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../data/sale.dart';
import '../data/sale_repository.dart';

/// Full-page invoice preview opened from POS, the dashboard or a deep link.
/// It accepts a [Sale] or a sale id through `Get.arguments` and refetches the
/// line items when they are not part of the incoming object.
class SaleDetailView extends StatefulWidget {
  const SaleDetailView({super.key});

  @override
  State<SaleDetailView> createState() => _SaleDetailViewState();
}

class _SaleDetailViewState extends State<SaleDetailView> {
  final SaleRepository _repository = Get.find<SaleRepository>();
  final SessionService _session = Get.find<SessionService>();

  Sale? _sale;
  String? _error;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final argument = Get.arguments;
    if (argument is Sale) {
      _sale = argument;
    } else if (argument is String && argument.isNotEmpty) {
      _sale = null;
    }
    final id = argument is Sale
        ? argument.id
        : argument is String
        ? argument
        : null;
    if (_sale != null && _sale!.items.isNotEmpty) {
      _loading = false;
    } else {
      _load(id);
    }
  }

  Future<void> _load([String? id]) async {
    final saleId = id ?? _sale?.id;
    if (saleId == null || saleId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'This invoice could not be found. Open it from a sale list.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await _repository.byId(saleId);
      if (!mounted) return;
      setState(() {
        _sale = value;
        _error = value == null ? 'This invoice no longer exists.' : null;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load this invoice right now.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _print() async {
    final sale = _sale;
    final tenant = _session.tenant;
    if (sale == null || tenant == null) return;
    setState(() => _busy = true);
    try {
      await ReceiptService.printInvoice(tenant: tenant, sale: sale);
    } catch (exception) {
      showAppMessage('Could not open the print dialog.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    final sale = _sale;
    final tenant = _session.tenant;
    if (sale == null || tenant == null) return;
    setState(() => _busy = true);
    try {
      await ReceiptService.shareInvoice(tenant: tenant, sale: sale);
    } catch (exception) {
      showAppMessage('Could not share this invoice.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(num value) =>
      Formats.currency(value, symbol: _session.currencySymbol);

  @override
  Widget build(BuildContext context) {
    final sale = _sale;
    return Scaffold(
      appBar: AppBar(
        title: Text(sale == null ? 'Invoice' : 'Invoice ${sale.invoiceNo}'),
        actions: [
          IconButton(
            onPressed: sale == null || _busy ? null : _print,
            tooltip: 'Print invoice',
            icon: const Icon(Icons.print_outlined),
          ),
          IconButton(
            onPressed: sale == null || _busy ? null : _share,
            tooltip: 'Share invoice',
            icon: const Icon(Icons.share_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const LoadingState(label: 'Loading invoice…')
          : _error != null
          ? ErrorState(
              message: _error!,
              title: 'Invoice unavailable',
              onRetry: () => _load(),
            )
          : sale == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(18),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 860),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InvoiceHeader(
                          sale: sale,
                          tenantName: _session.tenant?.name ?? 'Afraz Flow',
                        ),
                        const SizedBox(height: 16),
                        _InvoiceBody(sale: sale, money: _money),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _busy ? null : _print,
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 18,
                                ),
                                label: Text('Print receipt'.tr),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _busy ? null : _share,
                                icon: const Icon(Icons.share_outlined, size: 18),
                                label: Text('Share PDF'.tr),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Generated by Afraz Flow · ${Formats.dateTime(sale.createdAt)}',
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
                  ),
                ),
              ),
            ),
    );
  }
}

class _InvoiceHeader extends StatelessWidget {
  const _InvoiceHeader({required this.sale, required this.tenantName});

  final Sale sale;
  final String tenantName;

  @override
  Widget build(BuildContext context) {
    final color = switch (sale.status) {
      SaleStatus.completed => AppColors.green,
      SaleStatus.refunded => AppColors.amber,
      SaleStatus.voided => AppColors.red,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppLogoMark(size: 44, radius: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tenantName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Sales invoice · ${sale.invoiceNo}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(label: sale.status.label, color: color),
            ],
          ),
          const Divider(height: 26),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final customer = _HeaderDatum(
                label: 'Billed to',
                value: sale.customerName,
                icon: Icons.person_outline_rounded,
              );
              final payment = _HeaderDatum(
                label: 'Payment',
                value: sale.paymentMethod.label,
                icon: Icons.credit_card_outlined,
              );
              final date = _HeaderDatum(
                label: 'Issued',
                value: Formats.dateTime(sale.createdAt),
                icon: Icons.event_outlined,
              );
              if (narrow) {
                return Column(
                  children: [
                    customer,
                    const SizedBox(height: 10),
                    payment,
                    const SizedBox(height: 10),
                    date,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: customer),
                  Expanded(child: payment),
                  Expanded(child: date),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderDatum extends StatelessWidget {
  const _HeaderDatum({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 17,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 0.9,
                  fontSize: 9,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvoiceBody extends StatelessWidget {
  const _InvoiceBody({required this.sale, required this.money});

  final Sale sale;
  final String Function(num) money;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Line items',
            subtitle: 'Products, quantities and prices for this invoice.',
          ),
          const SizedBox(height: 10),
          if (sale.items.isEmpty)
            const EmptyState(
              compact: true,
              icon: Icons.receipt_long_outlined,
              title: 'No line items',
              message:
                  'The invoice total is available, but its line items could '
                  'not be found.',
            )
          else
            Column(
              children: [
                for (final item in sale.items)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant
                              .withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                '${item.sku} · ${item.quantityLabel} × ${money(item.unitPrice)}',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          money(item.lineTotal),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final totals = _Totals(sale: sale, money: money);
              final note = _InvoiceNote(sale: sale);
              if (constraints.maxWidth < 620) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [note, const SizedBox(height: 16), totals],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: note),
                  const SizedBox(width: 28),
                  SizedBox(width: 260, child: totals),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InvoiceNote extends StatelessWidget {
  const _InvoiceNote({required this.sale});

  final Sale sale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.4,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NOTES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            sale.note?.isNotEmpty == true
                ? sale.note!
                : 'Thank you for your business. Keep this invoice for returns '
                      'within 7 days.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.5,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: AppColors.inkMuted,
              ),
              const SizedBox(width: 5),
              Text(
                '${sale.itemCount} unit${sale.itemCount == 1 ? '' : 's'} sold',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.sale, required this.money});

  final Sale sale;
  final String Function(num) money;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Line(label: 'Subtotal', value: money(sale.subtotal)),
        if (sale.discount > 0)
          _Line(
            label: 'Discount',
            value: '- ${money(sale.discount)}',
            color: AppColors.green,
          ),
        _Line(label: 'Tax', value: money(sale.tax)),
        const Divider(height: 16),
        _Line(label: 'Total', value: money(sale.total), strong: true),
        _Line(label: 'Paid', value: money(sale.paidAmount)),
        _Line(
          label: sale.hasDue ? 'Balance due' : 'Balance',
          value: money(sale.dueAmount),
          strong: sale.hasDue,
          color: sale.hasDue ? AppColors.red : AppColors.green,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.strong = false,
    this.color,
  });

  final String label;
  final String value;
  final bool strong;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style?.copyWith(
                color: strong
                    ? null
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: style?.copyWith(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
