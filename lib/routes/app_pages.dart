import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../core/services/app_services.dart';
import '../features/auth/views/login_view.dart';
import '../features/courier/views/courier_detail_view.dart';
import '../features/pos/views/sale_detail_view.dart';
import '../features/scanner/views/scanner_view.dart';
import '../features/shell/views/app_shell.dart';
import '../features/splash/views/splash_view.dart';
import 'app_bindings.dart';
import 'app_routes.dart';

class AppPages {
  const AppPages._();

  static final List<GetPage> pages = [
    GetPage(
      name: Routes.splash,
      page: () => const SplashView(),
      binding: AppBindings.splash,
    ),
    GetPage(
      name: Routes.login,
      page: () => const LoginView(),
      binding: AppBindings.auth,
    ),
    GetPage(
      name: Routes.register,
      page: () => const RegisterView(),
      binding: AppBindings.auth,
    ),
    GetPage(
      name: Routes.shell,
      page: () => const AppShell(),
      binding: AppBindings.shell,
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.scanner,
      page: () => const ScannerView(),
      transition: Transition.fadeIn,
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.saleDetail,
      page: () => const SaleDetailView(),
      middlewares: [AuthMiddleware()],
    ),
    GetPage(
      name: Routes.courierDetail,
      page: () => const CourierDetailView(),
      binding: AppBindings.courierDetail,
      middlewares: [AuthMiddleware()],
    ),
  ];
}

/// Prevents deep links from reaching authenticated screens without a session.
class AuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final session = Get.find<SessionService>();
    if (!session.isAuthenticated) {
      return const RouteSettings(name: Routes.login);
    }
    return null;
  }
}
