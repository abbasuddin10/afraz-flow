import 'package:get/get.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/widgets/feedback.dart';
import '../data/app_notification.dart';
import '../data/notification_repository.dart';

class NotificationController extends GetxController {
  final NotificationRepository _repository = Get.find<NotificationRepository>();
  final SessionService _session = Get.find<SessionService>();

  final RxList<AppNotification> items = <AppNotification>[].obs;
  final RxInt unread = 0.obs;
  final RxBool loading = false.obs;
  final RxnString error = RxnString();

  @override
  void onInit() {
    super.onInit();
    if (_session.isAuthenticated) {
      refresh();
      _startRealtime();
    }
  }

  @override
  Future<void> refresh() async {
    if (!_session.isAuthenticated) return;
    loading.value = true;
    error.value = null;
    try {
      final results = await Future.wait([
        _repository.all(),
        _repository.unreadCount(),
      ]);
      items.assignAll(results[0] as List<AppNotification>);
      unread.value = results[1] as int;
    } catch (exception) {
      error.value = AppFailure.from(exception).message;
    } finally {
      loading.value = false;
    }
  }

  Future<void> markRead(AppNotification notification) async {
    if (notification.isUnread) {
      try {
        final updated = await _repository.markRead(notification.id);
        final index = items.indexWhere((item) => item.id == notification.id);
        if (index >= 0) items[index] = updated;
        if (unread.value > 0) unread.value -= 1;
      } catch (exception) {
        showAppMessage(AppFailure.from(exception).message, error: true);
      }
    }
  }

  Future<void> markAllRead() async {
    final unreadItems = items.where((item) => item.isUnread).toList();
    if (unreadItems.isEmpty) return;
    try {
      await _repository.markAllRead(
        unreadItems.map((item) => item.id).toList(growable: false),
      );
      final now = DateTime.now();
      for (final item in unreadItems) {
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index >= 0) items[index] = items[index].copyWith(readAt: now);
      }
      unread.value = 0;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
    }
  }

  Future<void> clearAll() async {
    try {
      await _repository.clearAll();
      items.clear();
      unread.value = 0;
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
    }
  }

  void _startRealtime() {
    _repository.startRealtime((notification) {
      if (items.any((item) => item.id == notification.id)) return;
      items.insert(0, notification);
      unread.value += 1;
      showAppMessage(notification.body, title: notification.title);
    });
  }

  @override
  void onClose() {
    _repository.stopRealtime();
    super.onClose();
  }
}
