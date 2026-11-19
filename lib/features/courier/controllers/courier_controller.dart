import 'package:get/get.dart';

import '../../../../core/data/cache/data_cache.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/feedback.dart';
import '../data/courier_order.dart';
import '../data/courier_repository.dart';

class CourierController extends GetxController {
  final CourierRepository _repository = Get.find<CourierRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<CourierOrder> orders = <CourierOrder>[].obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;
  final RxnString error = RxnString();
  final RxString search = ''.obs;
  final Rxn<CourierStatus> statusFilter = Rxn<CourierStatus>();

  String get currency => _session.currencySymbol;

  List<CourierOrder> get filteredOrders {
    final query = search.value.trim().toLowerCase();
    return orders.where((order) {
      if (statusFilter.value != null && order.status != statusFilter.value) {
        return false;
      }
      if (query.isEmpty) return true;
      return order.orderNo.toLowerCase().contains(query) ||
          order.customerName.toLowerCase().contains(query) ||
          order.customerPhone.toLowerCase().contains(query) ||
          (order.trackingNumber ?? '').toLowerCase().contains(query) ||
          order.city.toLowerCase().contains(query);
    }).toList();
  }

  int countFor(CourierStatus status) =>
      orders.where((order) => order.status == status).length;

  double get codPending => orders
      .where((order) => order.codPending && order.status != CourierStatus.cancelled && order.status != CourierStatus.returned)
      .fold(0, (sum, order) => sum + order.codAmount);

  double get codCollected => orders
      .where((order) => order.codCollected)
      .fold(0, (sum, order) => sum + order.codAmount);

  double get shippingDue => orders
      .where((order) => order.status == CourierStatus.shipped)
      .fold(0, (sum, order) => sum + order.shippingFee);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      orders.assignAll(await _repository.all());
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  void setSearch(String value) => search.value = value;
  void setStatusFilter(CourierStatus? value) => statusFilter.value = value;

  Future<CourierOrder?> createOrder({
    required String customerName,
    required String customerPhone,
    required String address,
    required String city,
    required String courierPartner,
    required double codAmount,
    double shippingFee = 0,
    String? trackingNumber,
    String? notes,
  }) async {
    saving.value = true;
    try {
      final order = await _repository.create(
        customerName: customerName,
        customerPhone: customerPhone,
        address: address,
        city: city,
        courierPartner: courierPartner,
        codAmount: codAmount,
        shippingFee: shippingFee,
        trackingNumber: trackingNumber,
        notes: notes,
      );
      await load(silent: true);
      showAppMessage('Delivery ${order.orderNo} created.');
      return order;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return null;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> changeStatus(
    CourierOrder order,
    CourierStatus status, {
    String? note,
  }) async {
    saving.value = true;
    try {
      final updated = await _repository.changeStatus(
        order: order,
        status: status,
        note: note,
      );
      await load(silent: true);
      showAppMessage('${order.orderNo} marked ${status.label.toLowerCase()}.');
      return updated.status == status;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> collectCod(CourierOrder order) async {
    saving.value = true;
    try {
      await _repository.collectCod(order);
      await load(silent: true);
      showAppMessage('COD reconciled for ${order.orderNo}.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> deleteOrder(CourierOrder order) async {
    saving.value = true;
    try {
      await _repository.delete(order);
      await load(silent: true);
      showAppMessage('Delivery ${order.orderNo} deleted.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  Future<bool> updateTracking(
    CourierOrder order, {
    required String courierPartner,
    String? trackingNumber,
  }) async {
    saving.value = true;
    try {
      await _repository.updateTracking(
        order: order,
        courierPartner: courierPartner,
        trackingNumber: trackingNumber,
      );
      await load(silent: true);
      showAppMessage('Tracking details saved.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }
}

class CourierDetailController extends GetxController {
  final CourierRepository _repository = Get.find<CourierRepository>();

  final Rx<CourierOrder?> order = Rx<CourierOrder?>(null);
  final RxBool loading = true.obs;
  final RxnString error = RxnString();

  String? _id;

  @override
  void onInit() {
    super.onInit();
    final argument = Get.arguments;
    if (argument is CourierOrder) {
      _id = argument.id;
      order.value = argument;
    } else if (argument is String) {
      _id = argument;
    }
    load();
  }

  Future<void> load() async {
    if (_id == null) {
      error.value = 'Delivery could not be found.';
      loading.value = false;
      return;
    }
    loading.value = true;
    try {
      final value = await _repository.byId(_id!);
      if (value == null) {
        error.value = 'This delivery no longer exists.';
      } else {
        order.value = value;
      }
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> refreshQuietly() async {
    // Pull-to-refresh on the detail view: force a fresh read.
    if (Get.isRegistered<DataCache>()) Get.find<DataCache>().expireAll();
    await load();
  }

  Future<bool> changeStatus(CourierStatus status, {String? note}) async {
    final current = order.value;
    if (current == null) return false;
    try {
      await _repository.changeStatus(
        order: current,
        status: status,
        note: note,
      );
      await load();
      showAppMessage('Status updated to ${status.label}.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    }
  }

  Future<bool> collectCod() async {
    final current = order.value;
    if (current == null) return false;
    try {
      await _repository.collectCod(current);
      await load();
      showAppMessage('COD reconciled.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    }
  }

  Future<bool> updateTracking({
    required String courierPartner,
    String? trackingNumber,
  }) async {
    final current = order.value;
    if (current == null) return false;
    try {
      final updated = await _repository.updateTracking(
        order: current,
        courierPartner: courierPartner,
        trackingNumber: trackingNumber,
      );
      order.value = updated;
      showAppMessage('Tracking details saved.');
      return true;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
      return false;
    }
  }
}
