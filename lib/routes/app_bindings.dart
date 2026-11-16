import 'package:get/get.dart';

import '../../features/auth/controllers/auth_controller.dart';
import '../../features/assistant/controllers/assistant_controller.dart';
import '../../features/briefing/controllers/briefing_controller.dart';
import '../../features/courier/controllers/courier_controller.dart';
import '../../features/dashboard/controllers/dashboard_controller.dart';
import '../../features/inventory/controllers/inventory_controller.dart';
import '../../features/ledger/controllers/ledger_controller.dart';
import '../../features/notifications/controllers/notification_controller.dart';
import '../../features/pos/controllers/pos_controller.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../features/shell/controllers/navigation_controller.dart';
import '../../features/splash/controllers/splash_controller.dart';
import '../../features/staff/controllers/staff_controller.dart';

class AppBindings {
  const AppBindings._();

  static final SplashBinding splash = SplashBinding();
  static final AuthBinding auth = AuthBinding();
  static final ShellBinding shell = ShellBinding();
  static final CourierDetailBinding courierDetail = CourierDetailBinding();
}

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    // Create eagerly: SplashView does not read `controller`, so a lazyPut
    // would never be instantiated and onInit() would never redirect.
    Get.put(SplashController());
  }
}

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => AuthController(), fenix: true);
  }
}

class ShellBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => NavigationController(), fenix: true);
    Get.lazyPut(() => DashboardController(), fenix: true);
    Get.lazyPut(() => PosController(), fenix: true);
    Get.lazyPut(() => InventoryController(), fenix: true);
    Get.lazyPut(() => LedgerController(), fenix: true);
    Get.lazyPut(() => CourierController(), fenix: true);
    Get.lazyPut(() => StaffController(), fenix: true);
    Get.lazyPut(() => AssistantController(), fenix: true);
    Get.lazyPut(() => BriefingController(), fenix: true);
    Get.lazyPut(() => NotificationController(), fenix: true);
    Get.lazyPut(() => SettingsController(), fenix: true);
  }
}

class CourierDetailBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => CourierDetailController(), fenix: true);
  }
}
