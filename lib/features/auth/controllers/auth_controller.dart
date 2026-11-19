import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/data/backend_mode.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../routes/app_routes.dart';
import '../data/auth_repository.dart';
import '../data/register_business_input.dart';

class AuthController extends GetxController {
  final AuthRepository _auth = Get.find<AuthRepository>();
  final SessionService _session = Get.find<SessionService>();
  final PreferencesService _preferences = Get.find<PreferencesService>();
  final ThemeController _theme = Get.find<ThemeController>();
  final BackendMode _backend = Get.find<BackendMode>();

  final GlobalKey<FormState> loginFormKey = GlobalKey<FormState>();
  final GlobalKey<FormState> registerFormKey = GlobalKey<FormState>();

  late final TextEditingController emailController;
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController ownerNameController = TextEditingController();
  final TextEditingController businessNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController taxRateController = TextEditingController(
    text: '5',
  );
  final TextEditingController lowStockController = TextEditingController(
    text: '10',
  );

  final RxBool loading = false.obs;
  final RxBool obscurePassword = true.obs;
  final RxBool obscureConfirm = true.obs;
  final RxnString error = RxnString();
  final RxString businessType = AppConfig.businessTypes.first.obs;
  final RxString currency = 'PKR'.obs;

  bool get isDemoMode => _backend.isDemo;
  bool get cloudAvailable => _backend.cloudAvailable;
  String? get cloudError => _backend.cloudError;
  bool get isDark => _theme.isDark;

  @override
  void onInit() {
    super.onInit();
    emailController = TextEditingController(
      text: _preferences.lastEmail ?? '',
    );
  }

  void togglePassword() => obscurePassword.toggle();
  void toggleConfirm() => obscureConfirm.toggle();

  Future<bool> login() async {
    error.value = null;
    if (!(loginFormKey.currentState?.validate() ?? false)) return false;
    loading.value = true;
    try {
      final value = await _auth.signIn(
        email: emailController.text,
        password: passwordController.text,
      );
      _session.adopt(value);
      if (!value.isDemo) {
        await _preferences.setLastEmail(value.user.email);
        // Attach this device's FCM token to the new account immediately. The
        // notification controller also does this, but calling it here makes
        // registration deterministic even before the shell/bell is built.
        if (Get.isRegistered<PushNotificationService>()) {
          unawaited(Get.find<PushNotificationService>().onSessionReady());
        }
      }
      Get.offAllNamed(Routes.shell);
      return true;
    } catch (exception) {
      final failure = AppFailure.from(exception);
      error.value = failure.message;
      showAppMessage(failure.message, error: true);
      return false;
    } finally {
      loading.value = false;
    }
  }

  Future<bool> register() async {
    error.value = null;
    if (!(registerFormKey.currentState?.validate() ?? false)) return false;
    if (passwordController.text != confirmPasswordController.text) {
      error.value = 'Passwords do not match.';
      showAppMessage('Passwords do not match.', error: true);
      return false;
    }
    loading.value = true;
    try {
      final value = await _auth.registerBusiness(
        RegisterBusinessInput(
          ownerName: ownerNameController.text,
          businessName: businessNameController.text,
          email: emailController.text,
          password: passwordController.text,
          phone: phoneController.text,
          businessType: businessType.value,
          currency: currency.value,
          taxRate: double.tryParse(taxRateController.text.trim()) ?? 0,
          lowStockThreshold:
              int.tryParse(lowStockController.text.trim()) ?? 5,
        ),
      );
      _session.adopt(value);
      if (!value.isDemo) {
        await _preferences.setLastEmail(value.user.email);
        // Attach this device's FCM token to the new account immediately. The
        // notification controller also does this, but calling it here makes
        // registration deterministic even before the shell/bell is built.
        if (Get.isRegistered<PushNotificationService>()) {
          unawaited(Get.find<PushNotificationService>().onSessionReady());
        }
      }
      Get.offAllNamed(Routes.shell);
      return true;
    } on ConfirmationRequired {
      // The account exists in Supabase Auth; the workspace is provisioned on
      // the first sign-in after the email is confirmed.
      error.value = null;
      passwordController.clear();
      confirmPasswordController.clear();
      showAppMessage(
        'Account created. Check your inbox to confirm your email, '
        'then sign in to finish setting up your workspace.',
      );
      goToLogin();
      return false;
    } catch (exception) {
      final failure = AppFailure.from(exception);
      error.value = failure.message;
      showAppMessage(failure.message, error: true);
      return false;
    } finally {
      loading.value = false;
    }
  }

  /// Opens the local sample workspace. Available in every build so reviewers
  /// can explore the product without creating a real account.
  Future<void> useDemoAccount() async {
    await _backend.useDemo();
    emailController.text = AppConfig.demoEmail;
    passwordController.text = AppConfig.demoPassword;
    await login();
  }

  /// Returns to real Supabase sign-in after exploring the demo.
  Future<void> useCloudAccount() async {
    await _backend.useCloud();
    error.value = null;
    passwordController.clear();
    emailController.text = _preferences.lastEmail ?? '';
  }

  void goToRegister() {
    error.value = null;
    Get.toNamed(Routes.register);
  }

  void goToLogin() {
    error.value = null;
    Get.back();
  }

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    ownerNameController.dispose();
    businessNameController.dispose();
    phoneController.dispose();
    confirmPasswordController.dispose();
    taxRateController.dispose();
    lowStockController.dispose();
    super.onClose();
  }
}

String? confirmPasswordValidator(String? value, AuthController controller) {
  if (value == null || value.isEmpty) return 'Confirm your password';
  if (value != controller.passwordController.text) {
    return 'Passwords do not match';
  }
  return null;
}

String? requiredValidator(String? value) =>
    Validators.required(value, field: 'This field');
