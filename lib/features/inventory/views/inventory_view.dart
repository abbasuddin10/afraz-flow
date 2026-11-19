import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/data/cache/data_cache.dart';
import '../../../core/services/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../core/widgets/feedback.dart';
import '../../../routes/app_routes.dart';
import '../controllers/inventory_controller.dart';
import '../data/product.dart';
import 'inventory_dialogs.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final InventoryController controller = Get.find<InventoryController>();
  final SessionService session = Get.find<SessionService>();
  final TextEditingController _search = TextEditingController();

  bool get canManage => session.role.canManageCatalog;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openProductForm([Product? product]) async {
    await AppDialogs.showForm<bool>(
      context,
      title: product == null ? 'Add a product' : 'Edit product',
      subtitle: product == null
          ? 'Create a catalogue item with pricing, stock and barcode.'
          : 'Update ${product.name} details. Stock changes use adjustments.',
      child: ProductFormDialog(product: product),
    );
  }

  Future<void> _openAdjust(Product product) async {
    await AppDialogs.showForm<bool>(
      context,
      title: 'Adjust stock',
      subtitle: 'Record a delivery, removal or a manual stock count.',
      child: StockAdjustDialog(product: product),
    );
  }

  void _openMovements(Product product) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StockMovementsSheet(product: product),
    );
  }

  Future<void> _archive(Product product) async {
    final confirmed = await AppDialogs.confirm(
      context,
      title: 'Archive ${product.name}?',
      message:
          'The product will be hidden from POS and inventory. Past sales and '
          'stock history are kept.',
      confirmLabel: 'Archive',
      destructive: true,
      icon: Icons.archive_outlined,
    );
    if (!confirmed) return;
    await controller.archive(product);
  }

  Future<void> _scan() async {
    try {
      final code = await Get.toNamed<String>(Routes.scanner);
      if (code == null || code.isEmpty || !mounted) return;
      final product = await controller.findByBarcode(code);
      if (product == null) {
        if (!mounted) return;
        showAppMessage('No product matched "$code".', error: true);
        return;
      }
      _openMovements(product);
    } catch (exception) {
      if (!mounted) return;
      showAppMessage(
        'Could not open the scanner. You can still search the catalogue.',
        error: true,
      );
    }
  }

  Future<void> _handleAction(String action, Product product) async {
    switch (action) {
      case 'adjust':
        await _openAdjust(product);
      case 'movements':
        _openMovements(product);
      case 'edit':
        await _openProductForm(product);
      case 'archive':
        await _archive(product);
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 960;
    return RefreshIndicator(
      onRefresh: () async {
        // Pull-to-refresh always re-fetches from Supabase.
        Get.find<DataCache>().expireAll();
        await controller.load(silent: true);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(wide ? 28 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              eyebrow: 'Catalogue',
              title: 'Inventory',
              subtitle: canManage
                  ? 'Track every product, price and stock movement.'
                  : 'Browse products and stock levels. Catalogue changes are '
                        'available to managers and admins.',
              actions: [
                OutlinedButton.icon(
                  onPressed: _scan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: Text('Scan'.tr),
                ),
                if (canManage)
                  FilledButton.icon(
                    onPressed: () => _openProductForm(),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text('Add product'.tr),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Obx(() {
              if (controller.loading.value) {
                return const AppCard(
                  child: LoadingState(label: 'Loading your catalogue…'),
                );
              }
              if (controller.error.value != null) {
                return AppCard(
                  child: ErrorState(
                    message: controller.error.value!,
                    onRetry: () => controller.load(),
                  ),
                );
              }
              return _buildContent(context, wide);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool wide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResponsiveGrid(
          minItemWidth: 160,
          maxColumns: 4,
          children: [
            _SummaryTile(
              label: 'Products',
              value: '${controller.products.length}',
              icon: Icons.inventory_2_outlined,
              color: AppColors.navy,
            ),
            _SummaryTile(
              label: 'Low stock',
              value: '${controller.lowStockCount}',
              icon: Icons.warning_amber_rounded,
              color: AppColors.amber,
            ),
            _SummaryTile(
              label: 'Out of stock',
              value:
                  '${controller.products.where((p) => p.isOutOfStock).length}',
              icon: Icons.remove_shopping_cart_outlined,
              color: AppColors.red,
            ),
            _SummaryTile(
              label: 'Stock value',
              value: Formats.currency(
                controller.stockValue,
                symbol: controller.currency,
              ),
              icon: Icons.payments_outlined,
              color: AppColors.teal,
            ),
          ],
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 680;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                AppSearchField(
                  width: narrow ? constraints.maxWidth : 300,
                  hint: 'Search name, SKU or barcode',
                  controller: _search,
                  onChanged: controller.setSearch,
                ),
                _CategoryDropdown(controller: controller),
                Obx(
                  () => FilterChip(
                    label: Text("Low stock (${controller.lowStockCount})"),
                    selected: controller.lowStockOnly.value,
                    onSelected: controller.toggleLowStock,
                    avatar: const Icon(Icons.warning_amber_rounded, size: 15),
                  ),
                ),
                if (controller.search.value.isNotEmpty ||
                    controller.category.value != 'All' ||
                    controller.lowStockOnly.value)
                  TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      controller
                        ..setSearch('')
                        ..setCategory('All')
                        ..toggleLowStock(false);
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: Text('Clear filters'.tr),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Obx(() {
          final products = controller.filteredProducts;
          if (products.isEmpty) {
            return AppCard(
              child: EmptyState(
                icon: Icons.inventory_2_outlined,
                title: 'No products found',
                message:
                    'Try a different search, or add your first product to start '
                    'selling.',
                action: canManage
                    ? FilledButton.icon(
                        onPressed: () => _openProductForm(),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('Add product'.tr),
                      )
                    : null,
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (wide)
                _buildTable(context, products)
              else
                _buildCards(context, products),
              const SizedBox(height: 10),
              Text(
                'Showing ${products.length} of ${controller.products.length} products',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  Widget _buildTable(BuildContext context, List<Product> products) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          showCheckboxColumn: false,
          columnSpacing: 26,
          columns: [
            DataColumn(label: Text('PRODUCT'.tr)),
            DataColumn(label: Text('CATEGORY'.tr)),
            DataColumn(label: Text('COST'.tr)),
            DataColumn(label: Text('PRICE'.tr)),
            DataColumn(label: Text('STOCK'.tr)),
            DataColumn(label: Text(''.tr)),
          ],
          rows: [
            for (final product in products)
              DataRow(
                onSelectChanged: (_) => _openMovements(product),
                cells: [
                  DataCell(
                    Row(
                      children: [
                        ProductThumbnail(
                          name: product.name,
                          imageUrl: product.imageUrl,
                          size: 34,
                          background: product.isLowStock
                              ? AppColors.amber
                              : AppColors.navySoft,
                          foreground: Colors.white,
                        ),
                        const SizedBox(width: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 210),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
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
                                '${product.sku}${product.barcode == null ? '' : ' · ${product.barcode}'}',
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
                      ],
                    ),
                  ),
                  DataCell(Text(product.category)),
                  DataCell(
                    Text(
                      Formats.currency(
                        product.costPrice,
                        symbol: controller.currency,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      Formats.currency(
                        product.salePrice,
                        symbol: controller.currency,
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  DataCell(
                    StatusPill(
                      label: product.stockLabel,
                      color: product.isOutOfStock
                          ? AppColors.red
                          : product.isLowStock
                          ? AppColors.amber
                          : AppColors.green,
                      dense: true,
                    ),
                  ),
                  DataCell(
                    PopupMenuButton<String>(
                      tooltip: 'Product actions',
                      icon: const Icon(Icons.more_horiz_rounded, size: 19),
                      onSelected: (value) => _handleAction(value, product),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'movements',
                          child: _MenuRow(
                            icon: Icons.history_rounded,
                            label: 'Stock history',
                          ),
                        ),
                        if (canManage) ...[
                          const PopupMenuItem(
                            value: 'adjust',
                            child: _MenuRow(
                              icon: Icons.swap_vert_rounded,
                              label: 'Adjust stock',
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'edit',
                            child: _MenuRow(
                              icon: Icons.edit_outlined,
                              label: 'Edit product',
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'archive',
                            child: _MenuRow(
                              icon: Icons.archive_outlined,
                              label: 'Archive',
                              color: AppColors.red,
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
      ),
    );
  }

  Widget _buildCards(BuildContext context, List<Product> products) {
    return Column(
      children: [
        for (final product in products)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              padding: const EdgeInsets.all(14),
              onTap: () => _openMovements(product),
              child: Row(
                children: [
                  ProductThumbnail(
                    name: product.name,
                    imageUrl: product.imageUrl,
                    size: 46,
                    background: product.isLowStock
                        ? AppColors.amber
                        : AppColors.navySoft,
                    foreground: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
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
                              ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            Text(
                              Formats.currency(
                                product.salePrice,
                                symbol: controller.currency,
                              ),
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 10),
                            StatusPill(
                              label: product.stockLabel,
                              color: product.isOutOfStock
                                  ? AppColors.red
                                  : product.isLowStock
                                  ? AppColors.amber
                                  : AppColors.green,
                              dense: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded, size: 19),
                    onSelected: (value) => _handleAction(value, product),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'movements',
                        child: _MenuRow(
                          icon: Icons.history_rounded,
                          label: 'Stock history',
                        ),
                      ),
                      if (canManage) ...[
                        const PopupMenuItem(
                          value: 'adjust',
                          child: _MenuRow(
                            icon: Icons.swap_vert_rounded,
                            label: 'Adjust stock',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'edit',
                          child: _MenuRow(
                            icon: Icons.edit_outlined,
                            label: 'Edit product',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'archive',
                          child: _MenuRow(
                            icon: Icons.archive_outlined,
                            label: 'Archive',
                            color: AppColors.red,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.controller});

  final InventoryController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final values = ['All', ...controller.categories];
      final current = values.contains(controller.category.value)
          ? controller.category.value
          : 'All';
      return Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: current,
            isDense: true,
            style: Theme.of(context).textTheme.bodySmall,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
            items: [
              for (final value in values)
                DropdownMenuItem(value: value, child: Text(value)),
            ],
            onChanged: (value) {
              if (value != null) controller.setCategory(value);
            },
          ),
        ),
      );
    });
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 9),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
