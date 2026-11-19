import 'package:get/get.dart';

import '../../../../core/data/cache/data_cache.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../data/dashboard_repository.dart';
import '../data/dashboard_snapshot.dart';

class DashboardController extends GetxController {
  final DashboardRepository _repository = Get.find<DashboardRepository>();
  final SessionService _session = Get.find<SessionService>();

  final Rx<DashboardSnapshot> snapshot = DashboardSnapshot.empty().obs;
  final Rx<DashboardPeriod> period = DashboardPeriod.today.obs;
  final RxBool loading = true.obs;
  final RxnString error = RxnString();
  final Rx<DateTime> lastUpdated = DateTime.now().obs;

  SessionService get session => _session;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      snapshot.value = await _repository.load(period.value);
      lastUpdated.value = DateTime.now();
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
      if (silent) rethrow;
    } finally {
      loading.value = false;
    }
  }

  Future<void> changePeriod(DashboardPeriod value) async {
    if (period.value == value) return;
    period.value = value;
    await load();
  }

  @override
  Future<void> refresh() async {
    // Explicit refresh (pull-to-refresh, app resume): always re-fetch.
    if (Get.isRegistered<DataCache>()) Get.find<DataCache>().expireAll();
    await load(silent: true);
  }
}
