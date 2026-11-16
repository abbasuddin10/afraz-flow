import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../../core/services/app_services.dart';
import '../../../../routes/app_routes.dart';

class SplashController extends GetxController {
  final SessionService _session = Get.find<SessionService>();

  bool _disposed = false;

  @override
  void onInit() {
    super.onInit();
    _start();
  }

  Future<void> _start() async {
    final minimumDelay = Future<void>.delayed(
      const Duration(milliseconds: 900),
    );
    var authenticated = false;
    try {
      // Never let a stalled network restore trap the app on the splash.
      authenticated = await _session.restore().timeout(
        const Duration(seconds: 8),
        onTimeout: () => false,
      );
    } catch (error) {
      debugPrint('Session restore failed: $error');
      authenticated = false;
    }
    try {
      await minimumDelay;
    } catch (_) {}
    if (_disposed || isClosed) return;
    final target = authenticated ? Routes.shell : Routes.login;
    try {
      Get.offAllNamed(target);
    } catch (error) {
      debugPrint('Splash navigation to $target failed: $error');
      // Last-resort fallback: try login route.
      if (target != Routes.login) {
        try {
          Get.offAllNamed(Routes.login);
        } catch (_) {}
      }
    }
  }

  @override
  void onClose() {
    _disposed = true;
    super.onClose();
  }
}
