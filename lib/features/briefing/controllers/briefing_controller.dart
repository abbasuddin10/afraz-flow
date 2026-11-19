import 'package:get/get.dart';

import '../../../core/data/cache/data_cache.dart';
import '../../../core/models/app_user.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/widgets/feedback.dart';
import '../../notifications/controllers/notification_controller.dart';
import '../data/briefing_repository.dart';
import '../data/daily_briefing.dart';

class BriefingController extends GetxController {
  final BriefingRepository _repository = Get.find<BriefingRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<DailyBriefing> briefings = <DailyBriefing>[].obs;
  final Rxn<DailyBriefing> selected = Rxn<DailyBriefing>();
  final RxBool loading = true.obs;
  final RxBool generating = false.obs;
  final RxnString error = RxnString();

  bool get canGenerate => _session.role == MemberRole.admin;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) loading.value = true;
    error.value = null;
    try {
      final items = await _repository.history();
      briefings.assignAll(items);
      final current = selected.value;
      if (current == null ||
          !items.any((briefing) => briefing.id == current.id)) {
        selected.value = items.isEmpty ? null : items.first;
      }
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
      if (silent) rethrow;
    } finally {
      loading.value = false;
    }
  }

  Future<DailyBriefing?> generate() async {
    if (generating.value) return null;
    if (!canGenerate) {
      showAppMessage(
        'Only an active admin can generate the daily briefing.',
        error: true,
      );
      return null;
    }

    generating.value = true;
    error.value = null;
    try {
      final briefing = await _repository.generate();
      final index = briefings.indexWhere(
        (item) => item.id == briefing.id || item.dateKey == briefing.dateKey,
      );
      if (index >= 0) {
        briefings[index] = briefing;
      } else {
        briefings.insert(0, briefing);
      }
      briefings.sort((a, b) => b.date.compareTo(a.date));
      selected.value = briefing;
      showAppMessage("Today's briefing is ready.");
      _refreshNotifications();
      return briefing;
    } catch (exception) {
      final message = AppFailure.from(exception).message;
      error.value = message;
      showAppMessage(message, error: true);
      return null;
    } finally {
      generating.value = false;
    }
  }

  void select(DailyBriefing briefing) {
    selected.value = briefing;
  }

  void _refreshNotifications() {
    if (!Get.isRegistered<NotificationController>()) return;
    Get.find<NotificationController>().refresh();
  }

  @override
  Future<void> refresh() async {
    // Explicit refresh (pull-to-refresh, app resume): always re-fetch.
    if (Get.isRegistered<DataCache>()) Get.find<DataCache>().expireAll();
    await load(silent: true);
  }
}
