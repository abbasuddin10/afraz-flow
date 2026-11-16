import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_widgets.dart';
import '../controllers/inventory_controller.dart';
import '../data/product.dart';

class ProductFormDialog extends StatefulWidget {
  const ProductFormDialog({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormDialog> createState() => _ProductFormDialogState();
}

class _ProductFormDialogState extends State<ProductFormDialog> {
  final InventoryController _controller = Get.find<InventoryController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _barcode;
  late final TextEditingController _category;
  String _unitValue = 'pcs';
  late final TextEditingController _cost;
  late final TextEditingController _price;
  late final TextEditingController _stock;
  late final TextEditingController _threshold;

  bool get _editing => widget.product != null;

  List<String> get _unitOptions {
    final options = [...AppConfig.units];
    if (_unitValue.trim().isNotEmpty &&
        !options.contains(_unitValue.trim())) {
      options.insert(0, _unitValue.trim());
    }
    if (options.isEmpty) options.add('pcs');
    return options;
  }

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _barcode = TextEditingController(text: product?.barcode ?? '');
    _category = TextEditingController(text: product?.category ?? '');
    _unitValue = product?.unit ?? 'pcs';
    _cost = TextEditingController(
      text: product == null ? '' : _number(product.costPrice),
    );
    _price = TextEditingController(
      text: product == null ? '' : _number(product.salePrice),
    );
    _stock = TextEditingController(
      text: product == null ? '' : _number(product.stockQty),
    );
    _threshold = TextEditingController(
      text: '${product?.lowStockThreshold ?? 5}',
    );
  }

  String _number(double value) =>
      value % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _barcode.dispose();
    _category.dispose();
    // unit is now a dropdown value; nothing to dispose.
    _cost.dispose();
    _price.dispose();
    _stock.dispose();
    _threshold.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _controller.saveProduct(
      existing: widget.product,
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      barcode: _barcode.text.trim(),
      category: _category.text.trim(),
      unit: _unitValue.trim(),
      costPrice: Formats.parseAmount(_cost.text),
      salePrice: Formats.parseAmount(_price.text),
      stockQty: _editing
          ? (widget.product?.stockQty ?? 0)
          : Formats.parseAmount(_stock.text),
      lowStockThreshold: int.tryParse(_threshold.text.trim()) ?? 5,
    );
    if (saved && mounted) Navigator.of(context).pop(true);
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
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    validator: (value) =>
                        Validators.required(value, field: 'Product name'),
                    decoration: const InputDecoration(
                      labelText: 'Product name',
                      prefixIcon: Icon(Icons.label_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _sku,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'SKU',
                            hintText: 'Auto if empty',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _barcode,
                          decoration: const InputDecoration(
                            labelText: 'Barcode',
                            hintText: 'Optional',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _category,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            hintText: 'General',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _unitOptions.contains(_unitValue)
                              ? _unitValue
                              : null,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Unit',
                          ),
                          items: [
                            for (final unit in _unitOptions)
                              DropdownMenuItem(value: unit, child: Text(unit)),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _unitValue = value);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'PRICING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cost,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => Validators.amount(
                            value,
                            allowZero: true,
                            field: 'Cost price',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Cost price',
                            prefixIcon: Icon(
                              Icons.shopping_bag_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _price,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) => Validators.amount(
                            value,
                            allowZero: true,
                            field: 'Sale price',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Sale price',
                            prefixIcon: Icon(
                              Icons.sell_outlined,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _editing ? 'STOCK CONTROL' : 'OPENING STOCK',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stock,
                          enabled: !_editing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _editing
                              ? null
                              : (value) => Validators.amount(
                                  value,
                                  allowZero: true,
                                  field: 'Opening stock',
                                ),
                          decoration: InputDecoration(
                            labelText: 'Quantity in stock',
                            helperText: _editing
                                ? 'Use stock adjustment to change levels'
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _threshold,
                          keyboardType: TextInputType.number,
                          validator: (value) => Validators.amount(
                            value,
                            allowZero: true,
                            field: 'Low stock level',
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Low stock alert at',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Obx(
            () => DialogActions(
              cancelLabel: 'Cancel',
              submitLabel: _editing ? 'Save changes' : 'Add product',
              loading: _controller.saving.value,
              submitIcon: _editing ? Icons.check_rounded : Icons.add_rounded,
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class StockAdjustDialog extends StatefulWidget {
  const StockAdjustDialog({super.key, required this.product});

  final Product product;

  @override
  State<StockAdjustDialog> createState() => _StockAdjustDialogState();
}

class _StockAdjustDialogState extends State<StockAdjustDialog> {
  final InventoryController _controller = Get.find<InventoryController>();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _quantity = TextEditingController();
  final TextEditingController _note = TextEditingController();
  StockMovementType _type = StockMovementType.inbound;

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final saved = await _controller.adjustStock(
      product: widget.product,
      type: _type,
      quantity: Formats.parseAmount(_quantity.text),
      note: _note.text.trim(),
    );
    if (saved && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final adjustment = _type == StockMovementType.adjustment;
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
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        InitialsAvatar(name: widget.product.name, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.product.name,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              Text(
                                '${widget.product.sku} · currently ${widget.product.stockLabel}',
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
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<StockMovementType>(
                    value: _type,
                     isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Movement type',
                      prefixIcon: Icon(Icons.swap_vert_rounded, size: 20),
                    ),
                    items: [
                      for (final type in StockMovementType.values)
                        DropdownMenuItem(value: type, child: Text(type.label)),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _type = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => Validators.amount(
                      value,
                      allowZero: adjustment,
                      field: adjustment ? 'New stock level' : 'Quantity',
                    ),
                    decoration: InputDecoration(
                      labelText: adjustment
                          ? 'New stock level'
                          : 'Quantity to ${_type == StockMovementType.inbound ? 'add' : 'remove'}',
                      prefixIcon: const Icon(Icons.numbers_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note',
                      hintText: 'e.g. Supplier delivery, damaged units…',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Obx(
            () => DialogActions(
              cancelLabel: 'Cancel',
              submitLabel: 'Apply movement',
              loading: _controller.saving.value,
              submitIcon: Icons.check_rounded,
              onSubmit: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

class StockMovementsSheet extends StatelessWidget {
  const StockMovementsSheet({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<InventoryController>();
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.82,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 14, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stock movements',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${product.name} · ${product.stockLabel} on hand',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
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
            const Divider(),
            Expanded(
              child: FutureBuilder<List<StockMovement>>(
                future: controller.movementsFor(product),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingState(label: 'Loading stock history…');
                  }
                  if (snapshot.hasError) {
                    return ErrorState(
                      message:
                          'Stock movements could not be loaded. ${snapshot.error}',
                    );
                  }
                  final movements = snapshot.data ?? <StockMovement>[];
                  if (movements.isEmpty) {
                    return const EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No movements yet',
                      message:
                          'Stock in, stock out and adjustments will appear here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: movements.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final movement = movements[index];
                      final incoming = movement.type != StockMovementType.outbound;
                      final color = movement.type == StockMovementType.adjustment
                          ? AppColors.blue
                          : incoming
                          ? AppColors.green
                          : AppColors.red;
                      return AppCard(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                movement.type == StockMovementType.adjustment
                                    ? Icons.tune_rounded
                                    : incoming
                                    ? Icons.add_rounded
                                    : Icons.remove_rounded,
                                color: color,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    movement.type.label,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    [
                                      if (movement.note.isNotEmpty) movement.note,
                                      if (movement.reference != null)
                                        movement.reference!,
                                    ].where((value) => value.isNotEmpty).join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    Formats.dateTime(movement.createdAt),
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
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
                            const SizedBox(width: 10),
                            Text(
                              '${incoming && movement.type != StockMovementType.adjustment ? '+' : movement.type == StockMovementType.outbound ? '−' : ''}${Formats.number(movement.quantity, decimals: movement.quantity % 1 == 0 ? 0 : 2)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(color: color),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
