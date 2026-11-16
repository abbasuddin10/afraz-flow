import 'package:get/get.dart';

import '../../../../core/models/account.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/feedback.dart';
import '../../inventory/data/product.dart';
import '../../inventory/data/product_repository.dart';
import '../../ledger/data/account_repository.dart';
import '../data/sale.dart';
import '../data/sale_repository.dart';

class PosController extends GetxController {
  final ProductRepository _products = Get.find<ProductRepository>();
  final SaleRepository _sales = Get.find<SaleRepository>();
  final AccountRepository _accounts = Get.find<AccountRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<Product> products = <Product>[].obs;
  final RxList<Account> customers = <Account>[].obs;
  final RxList<CartLine> cart = <CartLine>[].obs;
  final RxBool loading = true.obs;
  final RxBool processing = false.obs;
  final RxnString error = RxnString();
  final RxString search = ''.obs;
  final RxString category = 'All'.obs;
  final Rx<PaymentMethod> paymentMethod = PaymentMethod.cash.obs;
  final RxnString selectedCustomerId = RxnString();
  final RxString discountInput = ''.obs;
  final RxString paidInput = ''.obs;
  final RxString noteInput = ''.obs;

  String get currency => _session.currencySymbol;
  double get taxRate => _session.tenant?.taxRate ?? 0;

  List<String> get categories {
    final values = products
        .map((product) => product.category)
        .where((value) => value.trim().isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['All', ...values];
  }

  List<Product> get filteredProducts {
    final query = search.value.trim().toLowerCase();
    return products.where((product) {
      if (category.value != 'All' && product.category != category.value) {
        return false;
      }
      if (query.isEmpty) return true;
      return product.name.toLowerCase().contains(query) ||
          product.sku.toLowerCase().contains(query) ||
          (product.barcode ?? '').contains(query);
    }).toList();
  }

  Account? get selectedCustomer {
    final id = selectedCustomerId.value;
    if (id == null) return null;
    for (final account in customers) {
      if (account.id == id) return account;
    }
    return null;
  }

  String get customerName => selectedCustomer?.name ?? 'Walk-in customer';

  double get subtotal =>
      cart.fold<double>(0, (sum, line) => sum + line.lineTotal);
  double get discount {
    final value = Formats.parseAmount(discountInput.value);
    if (value < 0) return 0;
    return value > subtotal ? subtotal : value;
  }

  double get tax =>
      (subtotal - discount) * (taxRate / 100);
  double get total => subtotal - discount + tax;

  double get paidAmount {
    final raw = paidInput.value.trim();
    if (raw.isEmpty) return total;
    final value = Formats.parseAmount(raw);
    if (value < 0) return 0;
    return value > total ? total : value;
  }

  double get dueAmount => (total - paidAmount).clamp(0, double.infinity);
  bool get isCredit => paymentMethod.value == PaymentMethod.credit;
  int get cartCount => cart.fold(0, (sum, line) => sum + line.quantity.round());

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      final productFuture = _products.all();
      final customerFuture = _accounts.customers();
      final productValues = await productFuture;
      final customerValues = await customerFuture;
      products.assignAll(productValues);
      customers.assignAll(customerValues);
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  void setSearch(String value) => search.value = value;
  void setCategory(String value) => category.value = value;
  void setDiscount(String value) => discountInput.value = value;
  void setPaid(String value) => paidInput.value = value;
  void setNote(String value) => noteInput.value = value;

  void setPaymentMethod(PaymentMethod value) {
    paymentMethod.value = value;
    if (value == PaymentMethod.credit) {
      paidInput.value = '0';
    } else {
      paidInput.value = '';
    }
  }

  void selectCustomer(String? id) => selectedCustomerId.value = id;

  /// Creates a customer account from the POS so a credit sale can be recorded
  /// without leaving the till.
  Future<Account?> createCustomer({
    required String name,
    String? phone,
    String? email,
  }) async {
    try {
      final account = await _accounts.create(
        name: name,
        type: AccountType.customer,
        phone: phone,
        email: email,
      );
      customers.add(account);
      customers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      selectedCustomerId.value = account.id;
      showAppMessage('${account.name} added as a customer.');
      return account;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return null;
    }
  }

  bool addProduct(Product product) {
    if (product.stockQty <= 0) {
      showAppMessage('${product.name} is out of stock.', error: true);
      return false;
    }
    final index = cart.indexWhere((line) => line.productId == product.id);
    if (index >= 0) {
      final line = cart[index];
      if (line.quantity + 1 > product.stockQty) {
        showAppMessage(
          'Only ${product.stockLabel} available for ${product.name}.',
          error: true,
        );
        return false;
      }
      cart[index] = line.copyWith(quantity: line.quantity + 1);
    } else {
      cart.add(
        CartLine(
          productId: product.id,
          name: product.name,
          sku: product.sku,
          unitPrice: product.salePrice,
          costPrice: product.costPrice,
          quantity: 1,
          availableStock: product.stockQty,
          unit: product.unit,
        ),
      );
    }
    return true;
  }

  void increment(CartLine line) {
    final index = cart.indexWhere((item) => item.productId == line.productId);
    if (index < 0) return;
    if (line.quantity + 1 > line.availableStock) {
      showAppMessage(
        'Only ${Formats.number(line.availableStock)} available.',
        error: true,
      );
      return;
    }
    cart[index] = line.copyWith(quantity: line.quantity + 1);
  }

  void decrement(CartLine line) {
    final index = cart.indexWhere((item) => item.productId == line.productId);
    if (index < 0) return;
    if (line.quantity <= 1) {
      cart.removeAt(index);
    } else {
      cart[index] = line.copyWith(quantity: line.quantity - 1);
    }
  }

  void removeLine(CartLine line) =>
      cart.removeWhere((item) => item.productId == line.productId);

  /// Allows typing an exact quantity instead of only using +/- buttons.
  void setQuantity(CartLine line, dynamic value) {
    final index = cart.indexWhere((item) => item.productId == line.productId);
    if (index < 0) return;
    final text = value?.toString().trim() ?? '';
    if (text.isEmpty) return;
    final parsed = double.tryParse(text);
    if (parsed == null) return;
    if (parsed <= 0) {
      cart.removeAt(index);
      return;
    }
    if (parsed > line.availableStock) {
      showAppMessage(
        'Only ${Formats.number(line.availableStock)} available.',
        error: true,
      );
      return;
    }
    cart[index] = line.copyWith(quantity: parsed);
  }

  /// Alias kept for callers/tests that use a different verb.
  void setLineQuantity(CartLine line, dynamic value) => setQuantity(line, value);
  void updateQuantity(CartLine line, dynamic value) => setQuantity(line, value);
  void changeQuantity(CartLine line, dynamic value) => setQuantity(line, value);

  void clearCart() {
    cart.clear();
    discountInput.value = '';
    paidInput.value = '';
    noteInput.value = '';
    selectedCustomerId.value = null;
    paymentMethod.value = PaymentMethod.cash;
  }

  Future<bool> addByBarcode(String code) async {
    try {
      final product = await _products.findByBarcode(code);
      if (product == null) {
        showAppMessage('No product found for "$code".', error: true);
        return false;
      }
      return addProduct(product);
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    }
  }

  Future<Sale?> checkout() async {
    if (cart.isEmpty) {
      showAppMessage('Add at least one product to the cart.', error: true);
      return null;
    }
    if (dueAmount > 0.009 && selectedCustomerId.value == null) {
      showAppMessage(
        isCredit
            ? 'Credit sales need a customer account. Add or select one.'
            : 'Choose a customer to record the outstanding balance.',
        error: true,
      );
      return null;
    }
    processing.value = true;
    try {
      final sale = await _sales.checkout(
        lines: cart.toList(),
        method: paymentMethod.value,
        discount: discount,
        taxRate: taxRate,
        accountId: selectedCustomerId.value,
        customerName: customerName,
        paidAmount: paidAmount,
        note: noteInput.value,
      );
      clearCart();
      await load(silent: true);
      showAppMessage('Sale ${sale.invoiceNo} completed.');
      return sale;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return null;
    } finally {
      processing.value = false;
    }
  }
}
