import 'package:afraz_flow/core/data/data_store.dart';
import 'package:afraz_flow/core/data/local_data_store.dart';
import 'package:afraz_flow/core/services/app_services.dart';
import 'package:afraz_flow/features/auth/data/auth_repository.dart';
import 'package:afraz_flow/features/splash/controllers/splash_controller.dart';
import 'package:afraz_flow/features/splash/views/splash_view.dart';
import 'package:afraz_flow/routes/app_bindings.dart';
import 'package:afraz_flow/routes/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  testWidgets('splash leaves itself and opens login when there is no session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = LocalDataStore(prefs);
    final auth = AuthRepository(store: store, prefs: prefs);

    Get.put<DataStore>(store, permanent: true);
    Get.put<AuthRepository>(auth, permanent: true);
    Get.put<SessionService>(SessionService(auth), permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: Routes.splash,
        getPages: [
          GetPage(
            name: Routes.splash,
            page: () => const SplashView(),
            binding: AppBindings.splash,
          ),
          GetPage(
            name: Routes.login,
            page: () => const Scaffold(body: Text('Login screen')),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Business management, in flow.'), findsOneWidget);
    // The controller must be created by the binding even though SplashView
    // never reads `controller`. This guards against the lazyPut regression
    // that previously left the app stuck on the splash forever.
    expect(Get.isRegistered<SplashController>(), isTrue);

    // The splash has a 900 ms minimum plus the session restore.
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 400));

    expect(Get.currentRoute, Routes.login);
    expect(find.text('Login screen'), findsOneWidget);
    expect(find.text('Business management, in flow.'), findsNothing);
  });
}
