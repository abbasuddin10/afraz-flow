import 'package:get/get.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/feedback.dart';
import '../data/product.dart';
import '../data/product_repository.dart';

class InventoryController extends GetxController {
  final ProductRepository _repository = Get.find<ProductRepository>();
  final SessionService _session = Get.find<SessionService>();

  static const Uuid _uuid = Uuid();

  final RxList<Product> products = <Product>[].obs;
  final RxList<String> categories = <String>[].obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;
  final RxnString error = RxnString();
  final RxString search = ''.obs;
  final RxString category = 'All'.obs;
  final RxBool lowStockOnly = false.obs;

  String get currency => _session.currencySymbol;
  int get lowStockCount => products.where((product) => product.isLowStock).length;
  double get stockValue =>
      products.fold(0, (sum, product) => sum + product.stockValue);

  List<Product> get filteredProducts {
    final query = search.value.trim().toLowerCase();
    return products.where((product) {
      if (lowStockOnly.value && !product.isLowStock) return false;
      if (category.value != 'All' && product.category != category.value) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.barcode ?? '').toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList();
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
      final values = await _repository.all();
      products.assignAll(values);
      final values2 = await _repository.categories();
      categories.assignAll(values2);
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  void setSearch(String value) => search.value = value;
  void setCategory(String value) => category.value = value;
  void toggleLowStock([bool? value]) =>
      lowStockOnly.value = value ?? !lowStockOnly.value;

  Future<bool> saveProduct({
    Product? existing,
    required String name,
    required String sku,
    required String barcode,
    required String category,
    required String unit,
    required double costPrice,
    required double salePrice,
    required double stockQty,
    required int lowStockThreshold,
    String? imageUrl,
  }) async {
    saving.value = true;
    try {
      final now = DateTime.now();
      final product = existing == null
          ? Product(
              id: _uuid.v4(),
              tenantId: _session.requireTenantId(),
              name: name,
              sku: sku.isEmpty
                  ? await _repository.nextSku(name)
                  : sku.toUpperCase(),
              barcode: barcode.trim().isEmpty ? null : barcode.trim(),
              category: category.trim().isEmpty
                  ? 'Uncategorised'
                  : category.trim(),
              unit: unit.trim().isEmpty ? 'pcs' : unit.trim(),
              costPrice: costPrice,
              salePrice: salePrice,
              stockQty: stockQty,
              lowStockThreshold: lowStockThreshold,
              imageUrl: imageUrl,
              isActive: true,
              createdAt: now,
              updatedAt: now,
            )
          : existing.copyWith(
              name: name,
              sku: sku.isEmpty ? existing.sku : sku.toUpperCase(),
              barcode: barcode.trim().isEmpty ? null : barcode.trim(),
              category: category,
              unit: unit,
              costPrice: costPrice,
              salePrice: salePrice,
              lowStockThreshold: lowStockThreshold,
              imageUrl: imageUrl,
              clearImage: imageUrl == null,
            );
      if (existing == null) {
        await _repository.create(product);
      } else {
        await _repository.update(product);
      }
      await load(silent: true);
      showAppMessage(existing == null ? 'Product added.' : 'Product updated.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> archive(Product product) async {
    saving.value = true;
    try {
      await _repository.archive(product);
      await load(silent: true);
      showAppMessage('${product.name} archived.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> adjustStock({
    required Product product,
    required StockMovementType type,
    required double quantity,
    required String note,
  }) async {
    saving.value = true;
    try {
      await _repository.adjustStock(
        product: product,
        type: type,
        quantity: quantity,
        note: note,
      );
      await load(silent: true);
      showAppMessage('Stock updated for ${product.name}.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<List<StockMovement>> movementsFor(Product product) =>
      _repository.movements(productId: product.id, limit: 50);

  Future<Product?> findByBarcode(String code) async {
    try {
      return await _repository.findByBarcode(code);
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return null;
    }
  }
}
