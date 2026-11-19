import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/data/cache/data_cache.dart';
import '../../../core/services/app_services.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../../routes/app_routes.dart';
import '../../inventory/data/product.dart';
import '../controllers/pos_controller.dart';
import '../data/sale.dart';

class PosView extends StatefulWidget {
  const PosView({super.key});

  @override
  State<PosView> createState() => _PosViewState();
}

class _PosViewState extends State<PosView> {
  final PosController controller = Get.find<PosController>();
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    try {
      final code = await Get.toNamed<String>(Routes.scanner);
      if (code == null || code.isEmpty || !mounted) return;
      await controller.addByBarcode(code);
    } catch (exception) {
      if (!mounted) return;
      showAppMessage(
        'Could not open the scanner. You can still search for the product.',
        error: true,
      );
    }
  }

  Future<void> _addCustomer() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _NewCustomerDialog(),
    );
    if (created == true && mounted) {
      showAppMessage('Customer ready for this sale.');
    }
  }

  void _openCart() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final height = MediaQuery.sizeOf(sheetContext).height;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SizedBox(
            height: height * 0.86,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _CartPanel(
                onCheckoutComplete: () {
                  if (Navigator.of(sheetContext).canPop()) {
                    Navigator.of(sheetContext).pop();
                  }
                },
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1040;
        return Padding(
          padding: EdgeInsets.all(wide ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                PageHeader(
                  eyebrow: 'Checkout',
                  title: 'Point of Sale',
                  subtitle:
                      'Build a basket, take payment and print a receipt in seconds.',
                  actions: [
                    OutlinedButton.icon(
                      onPressed: _scan,
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                      label: Text('Scan'.tr),
                    ),
                  ],
                ),
              if (wide) const SizedBox(height: 18),
              Obx(() {
                if (controller.loading.value) {
                  return const Expanded(
                    child: AppCard(
                      child: LoadingState(label: 'Opening the catalogue…'),
                    ),
                  );
                }
                if (controller.error.value != null) {
                  return Expanded(
                    child: AppCard(
                      child: ErrorState(
                        message: controller.error.value!,
                        onRetry: controller.load,
                      ),
                    ),
                  );
                }
                if (!wide) {
                  return Expanded(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: _scan,
                              icon: const Icon(
                                Icons.qr_code_scanner_rounded,
                                size: 18,
                              ),
                              label: Text('Scan'.tr),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Obx(
                                () => FilledButton.icon(
                                  onPressed: _openCart,
                                  icon: const Icon(
                                    Icons.shopping_bag_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    controller.cart.isEmpty
                                        ? 'Cart'
                                        : 'Cart (${controller.cartCount})',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppSearchField(
                          width: double.infinity,
                          hint: 'Search products, SKU or scan a barcode',
                          controller: _search,
                          onChanged: controller.setSearch,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: _CatalogPane(
                            controller: controller,
                            search: _search,
                            showSearch: false,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _CatalogPane(
                          controller: controller,
                          search: _search,
                        ),
                      ),
                      const SizedBox(width: 18),
                      SizedBox(
                        width: 390,
                        child: _CartPanel(
                          onAddCustomer: _addCustomer,
                          onCheckoutComplete: null,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

/// A compact always-visible summary used on mobile to open the cart sheet.

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.controller,
    required this.search,
    this.showSearch = true,
  });

  final PosController controller;
  final TextEditingController search;
  final bool showSearch;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSearch)
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 620;
              return Row(
                children: [
                  Expanded(
                    child: AppSearchField(
                      width: double.infinity,
                      hint: 'Search products, SKU or scan a barcode',
                      controller: search,
                      onChanged: controller.setSearch,
                    ),
                  ),
                  if (!narrow) ...[
                    const SizedBox(width: 10),
                    Obx(
                      () => Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).inputDecorationTheme.fillColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value:
                                controller.categories.contains(
                                  controller.category.value,
                                )
                                ? controller.category.value
                                : 'All',
                            isDense: true,
                            style: Theme.of(context).textTheme.bodySmall,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 18,
                            ),
                            items: [
                              for (final value in controller.categories)
                                DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                            ],
                            onChanged: (value) {
                              if (value != null) controller.setCategory(value);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        if (showSearch) const SizedBox(height: 12),
        Obx(
          () => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in controller.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: controller.category.value == value,
                      onSelected: (_) => controller.setCategory(value),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              // Pull-to-refresh always re-fetches from Supabase.
              Get.find<DataCache>().expireAll();
              await controller.load(silent: true);
            },
            child: Obx(() {
              final products = controller.filteredProducts;
              if (products.isEmpty) {
                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppCard(
                        child: EmptyState(
                          icon: Icons.inventory_2_outlined,
                          title: 'No products match this view',
                          message:
                              'Try another search or category. Products added '
                              'in Inventory appear here instantly. Pull down to '
                              'refresh from the cloud.',
                        ),
                      ),
                    ),
                  ],
                );
              }
              final isMobile = MediaQuery.sizeOf(context).width < 760;
              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 18),
                gridDelegate: isMobile
                    ? const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisExtent: 152,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 8,
                      )
                    : const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 210,
                        mainAxisExtent: 214,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                itemCount: products.length,
                itemBuilder: (context, index) => _ProductCard(
                  product: products[index],
                  onTap: () => controller.addProduct(products[index]),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PosController>();
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 760;
    final out = product.isOutOfStock;
    final radius = BorderRadius.circular(compact ? 11 : 14);
    final priceColor = theme.brightness == Brightness.dark
        ? Colors.white
        : AppColors.navy;

    return Opacity(
      opacity: out ? 0.62 : 1,
      child: Material(
        color: theme.cardTheme.color,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: out ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The photo keeps a fixed, compact height so the remaining space
              // is reserved for the product name, which must stay readable.
              SizedBox(
                // height: compact ? 88 : 116,
                height: compact ? 75 : 100,

                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ProductImage(
                      name: product.name,
                      imageUrl: product.imageUrl,
                      fit: BoxFit.fill,
                      background: out
                          ? theme.colorScheme.surfaceContainerHigh
                          : null,
                    ),
                    Positioned(
                      top: compact ? 5 : 8,
                      right: compact ? 5 : 8,
                      child: _StockBadge(
                        label: out
                            ? (compact ? 'Out' : 'Out of stock')
                            : product.stockLabel,
                        color: out
                            ? AppColors.red
                            : product.isLowStock
                            ? AppColors.amber
                            : AppColors.green,
                        compact: compact,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 6 : 10,
                    compact ? 4 : 8,
                    compact ? 4 : 8,
                    compact ? 4 : 8,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: compact ? 2 : 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            (compact
                                    ? theme.textTheme.labelSmall
                                    : theme.textTheme.titleSmall)
                                ?.copyWith(
                                  height: 1.15,
                                  fontWeight: FontWeight.w600,
                                  fontSize: compact ? 10 : null,
                                ),
                      ),
                      SizedBox(height: compact ? 5 : 4),
                      Row(
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                Formats.currency(
                                  product.salePrice,
                                  symbol: controller.currency,
                                ),
                                maxLines: 1,
                                style:
                                    (compact
                                            ? theme.textTheme.labelMedium
                                            : theme.textTheme.titleSmall)
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: priceColor,
                                          fontSize: compact ? 11.5 : null,
                                        ),
                              ),
                            ),
                          ),
                          SizedBox(width: compact ? 3 : 6),
                          Container(
                            width: compact ? 20 : 26,
                            height: compact ? 20 : 26,
                            decoration: BoxDecoration(
                              color: out
                                  ? AppColors.inkMuted.withValues(alpha: 0.15)
                                  : AppColors.teal.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(
                                compact ? 6 : 8,
                              ),
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: compact ? 14 : 17,
                              color: out ? AppColors.inkMuted : AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact stock overlay pinned to the top corner of a product photo.
class _StockBadge extends StatelessWidget {
  const _StockBadge({
    required this.label,
    required this.color,
    required this.compact,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 70 : 110),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 7,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 8.5 : 10,
          fontWeight: FontWeight.w700,
          height: 1.15,
        ),
      ),
    );
  }
}

class _CartPanel extends StatefulWidget {
  const _CartPanel({this.onAddCustomer, this.onCheckoutComplete});

  final VoidCallback? onAddCustomer;
  final VoidCallback? onCheckoutComplete;

  @override
  State<_CartPanel> createState() => _CartPanelState();
}

class _CartPanelState extends State<_CartPanel> {
  final PosController controller = Get.find<PosController>();

  Future<void> _checkout() async {
    final sale = await controller.checkout();
    if (sale == null) return;
    widget.onCheckoutComplete?.call();
    Get.dialog<void>(
      _SaleCompleteDialog(sale: sale),
      barrierDismissible: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current sale',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Prices include your configured tax rate.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Obx(
                () => TextButton(
                  onPressed: controller.cart.isEmpty
                      ? null
                      : controller.clearCart,
                  child: Text('Clear'.tr),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Obx(
            () => DropdownButtonFormField<String?>(
              value:
                  controller.customers.any(
                    (account) =>
                        account.id == controller.selectedCustomerId.value,
                  )
                  ? controller.selectedCustomerId.value
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Customer',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                suffixIcon: widget.onAddCustomer == null
                    ? null
                    : IconButton(
                        tooltip: 'Add customer',
                        onPressed: widget.onAddCustomer,
                        icon: const Icon(
                          Icons.person_add_alt_1_rounded,
                          size: 19,
                        ),
                      ),
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Walk-in customer'.tr),
                ),
                for (final account in controller.customers)
                  DropdownMenuItem<String?>(
                    value: account.id,
                    child: Text(
                      account.hasDue
                          ? '${account.name} · due ${Formats.currency(account.balance, symbol: controller.currency)}'
                          : account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: controller.selectCustomer,
            ),
          ),
          const SizedBox(height: 12),
          Obx(() {
            if (controller.cart.isEmpty) {
              return const EmptyState(
                compact: true,
                icon: Icons.shopping_bag_outlined,
                title: 'Cart is empty',
                message: 'Tap products on the left to add them to this sale.',
              );
            }
            return Column(
              children: [
                for (final line in controller.cart) _CartLineTile(line: line),
              ],
            );
          }),
          const Divider(height: 20),
          Obx(() {
            final sub = controller.subtotal;
            final discount = controller.discount;
            final tax = controller.tax;
            final total = controller.total;
            final due = controller.dueAmount;
            return Column(
              children: [
                _TotalRow(label: 'Subtotal', value: sub),
                if (discount > 0)
                  _TotalRow(
                    label: 'Discount',
                    value: -discount,
                    valueColor: AppColors.green,
                  ),
                _TotalRow(label: 'Tax', value: tax),
                const Divider(height: 14),
                _TotalRow(label: 'Total', value: total, strong: true),
                if (due > 0.009)
                  _TotalRow(
                    label: 'Balance due',
                    value: due,
                    valueColor: AppColors.red,
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SyncedField(
                        label: 'Discount',
                        hint: '0',
                        value: controller.discountInput.value,
                        onChanged: controller.setDiscount,
                        icon: Icons.percent_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SyncedField(
                        label: controller.isCredit ? 'Paid now' : 'Amount paid',
                        hint: controller.isCredit
                            ? '0'
                            : total.toStringAsFixed(0),
                        value: controller.paidInput.value,
                        onChanged: controller.setPaid,
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'PAYMENT METHOD',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      for (final method in PaymentMethod.values)
                        ChoiceChip(
                          label: Text(method.label),
                          selected: controller.paymentMethod.value == method,
                          onSelected: (_) =>
                              controller.setPaymentMethod(method),
                        ),
                    ],
                  ),
                ),
                if (controller.isCredit) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      controller.selectedCustomerId.value == null
                          ? 'Choose or add a customer to record this credit sale in their khata.'
                          : 'The outstanding balance will be added to ${controller.customerName}’s khata.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.amber,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _SyncedField(
                  label: 'Note on receipt',
                  hint: 'Optional',
                  value: controller.noteInput.value,
                  onChanged: controller.setNote,
                  icon: Icons.notes_rounded,
                  maxLines: 2,
                ),
                const SizedBox(height: 14),
                Obx(
                  () => SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          controller.processing.value || controller.cart.isEmpty
                          ? null
                          : _checkout,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: controller.processing.value
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 19,
                            ),
                      label: Text(
                        controller.cart.isEmpty
                            ? 'Add products to charge'
                            : 'Charge ${Formats.currency(total, symbol: controller.currency)}',
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PosController>();
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.6),
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
                  line.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 1),
                Text(
                  '${Formats.currency(line.unitPrice, symbol: controller.currency)} / ${line.unit}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _QtyButton(
            icon: Icons.remove_rounded,
            onTap: () => controller.decrement(line),
          ),
          SizedBox(
            width: 56,
            child: _QtyInputField(line: line, controller: controller),
          ),
          _QtyButton(
            icon: Icons.add_rounded,
            onTap: () => controller.increment(line),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 66,
            child: Text(
              Formats.currency(line.lineTotal, symbol: controller.currency),
              textAlign: TextAlign.end,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => controller.removeLine(line),
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            icon: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.inkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyInputField extends StatefulWidget {
  const _QtyInputField({required this.line, required this.controller});

  final CartLine line;
  final PosController controller;

  @override
  State<_QtyInputField> createState() => _QtyInputFieldState();
}

class _QtyInputFieldState extends State<_QtyInputField> {
  late final TextEditingController _textController = TextEditingController(
    text: _format(widget.line.quantity),
  );
  late final FocusNode _focusNode = FocusNode();
  bool _editing = false;

  String _format(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        setState(() => _editing = false);
      } else {
        setState(() => _editing = true);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _QtyInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && !_editing) {
      final next = _format(widget.line.quantity);
      if (_textController.text != next) {
        _textController.text = next;
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _textController,
      focusNode: _focusNode,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      onChanged: (value) => widget.controller.setQuantity(widget.line, value),
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        border: OutlineInputBorder(),
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        width: 25,
        height: 25,
        decoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 15, color: AppColors.teal),
      ),
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.value,
    this.strong = false,
    this.valueColor,
  });

  final String label;
  final double value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PosController>();
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
            Formats.currency(value, symbol: controller.currency),
            style: style?.copyWith(
              fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Keeps an editable text field in sync with a GetX string value without
/// resetting the cursor while the user is typing.
class _SyncedField extends StatefulWidget {
  const _SyncedField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.hint,
    this.icon,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final String? hint;
  final IconData? icon;
  final int maxLines;
  final ValueChanged<String> onChanged;

  @override
  State<_SyncedField> createState() => _SyncedFieldState();
}

class _SyncedFieldState extends State<_SyncedField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant _SyncedField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      maxLines: widget.maxLines,
      keyboardType: widget.maxLines > 1
          ? TextInputType.multiline
          : const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        isDense: true,
        prefixIcon: widget.icon == null ? null : Icon(widget.icon, size: 18),
      ),
    );
  }
}

class _NewCustomerDialog extends StatefulWidget {
  const _NewCustomerDialog();

  @override
  State<_NewCustomerDialog> createState() => _NewCustomerDialogState();
}

class _NewCustomerDialogState extends State<_NewCustomerDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _email = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final account = await Get.find<PosController>().createCustomer(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (account != null) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'New customer',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a khata account so credit and dues are tracked.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  validator: (value) =>
                      Validators.required(value, field: 'Customer name'),
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  validator: (value) => Validators.phone(value, optional: true),
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.phone_outlined, size: 20),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: Text('Cancel'.tr),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.person_add_alt_1_rounded,
                              size: 18,
                            ),
                      label: Text('Add customer'.tr),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaleCompleteDialog extends StatefulWidget {
  const _SaleCompleteDialog({required this.sale});

  final Sale sale;

  @override
  State<_SaleCompleteDialog> createState() => _SaleCompleteDialogState();
}

class _SaleCompleteDialogState extends State<_SaleCompleteDialog> {
  bool _printing = false;

  Future<void> _print() async {
    final tenant = Get.find<SessionService>().tenant;
    if (tenant == null) return;
    setState(() => _printing = true);
    try {
      await ReceiptService.printInvoice(tenant: tenant, sale: widget.sale);
    } catch (exception) {
      showAppMessage('Could not open the print dialog.', error: true);
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }

  Future<void> _share() async {
    final tenant = Get.find<SessionService>().tenant;
    if (tenant == null) return;
    try {
      await ReceiptService.shareInvoice(tenant: tenant, sale: widget.sale);
    } catch (exception) {
      showAppMessage('Could not share this invoice.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = Get.find<SessionService>();
    final sale = widget.sale;
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppColors.green.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 34,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Sale complete',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 3),
              Text(
                '${sale.invoiceNo} · ${sale.customerName}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Column(
                  children: [
                    _TotalRow(label: 'Total', value: sale.total, strong: true),
                    _TotalRow(label: 'Paid', value: sale.paidAmount),
                    if (sale.hasDue)
                      _TotalRow(
                        label: 'Due on khata',
                        value: sale.dueAmount,
                        valueColor: AppColors.red,
                      ),
                    _TotalRow(
                      label: 'Items',
                      value: sale.items.fold<double>(
                        0,
                        (sum, item) => sum + item.quantity,
                      ),
                    ),
                  ],
                ),
              ),
              if (sale.hasDue) ...[
                const SizedBox(height: 10),
                Text(
                  'The outstanding balance was added to ${sale.customerName}’s account.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.amber,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _printing ? null : _print,
                      icon: _printing
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.print_outlined, size: 18),
                      label: Text('Print'.tr),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _share,
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text('Share'.tr),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Get.toNamed<dynamic>(Routes.saleDetail, arguments: sale);
                  },
                  icon: const Icon(Icons.receipt_long_outlined, size: 18),
                  label: Text("View invoice · ${session.currencySymbol}"),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Start the next sale'.tr),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Re-exported so the shell can push this page without importing the feature
/// internals in more than one place.
Sale? saleForRoute(dynamic argument) => argument is Sale ? argument : null;
