import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/data/backend_mode.dart';
import '../../../../core/models/tenant.dart';
import '../../../../core/services/app_services.dart';
import '../../../../core/utils/app_failure.dart';
import '../../../../core/widgets/feedback.dart';
import '../../../../routes/app_routes.dart';
import '../data/settings_repository.dart';

class SettingsController extends GetxController {
  final SettingsRepository _repository = Get.find<SettingsRepository>();
  final SessionService _session = Get.find<SessionService>();
  final ThemeController theme = Get.find<ThemeController>();
  final LanguageController language = Get.find<LanguageController>();
  final BackendMode backend = Get.find<BackendMode>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  late final TextEditingController nameController;
  late final TextEditingController phoneController;
  late final TextEditingController emailController;
  late final TextEditingController addressController;
  late final TextEditingController taxRateController;
  late final TextEditingController lowStockController;

  final RxString businessType = ''.obs;
  final RxString currency = 'PKR'.obs;
  final RxBool saving = false.obs;
  final RxBool savingBriefing = false.obs;
  final RxBool briefingEnabled = true.obs;
  final RxString briefingTime = '22:00'.obs;
  final RxString briefingTimezone = 'Asia/Karachi'.obs;
  final RxnString error = RxnString();

  Tenant? get tenant => _session.tenant;
  bool get canEdit => _session.role.canManageSettings;
  bool get isDemo => _session.isDemo;
  bool get cloudAvailable => backend.cloudAvailable;
  SessionService get session => _session;
  String get currencySymbol => _session.currencySymbol;

  @override
  void onInit() {
    super.onInit();
    final value = tenant;
    nameController = TextEditingController(text: value?.name ?? '');
    phoneController = TextEditingController(text: value?.phone ?? '');
    emailController = TextEditingController(text: value?.email ?? '');
    addressController = TextEditingController(text: value?.address ?? '');
    taxRateController = TextEditingController(
      text: (value?.taxRate ?? 0).toStringAsFixed(
        (value?.taxRate ?? 0) % 1 == 0 ? 0 : 1,
      ),
    );
    lowStockController = TextEditingController(
      text: '${value?.lowStockThreshold ?? 5}',
    );
    businessType.value = value?.businessType ?? AppConfig.businessTypes.first;
    currency.value = value?.currency ?? 'PKR';
    briefingEnabled.value = value?.dailyBriefingEnabled ?? true;
    briefingTime.value = value?.dailyBriefingTime ?? '22:00';
    briefingTimezone.value = value?.dailyBriefingTimezone ?? 'Asia/Karachi';
  }

  Future<bool> save() async {
    if (!canEdit) {
      showAppMessage(
        'Only an admin can change business settings.',
        error: true,
      );
      return false;
    }
    if (!(formKey.currentState?.validate() ?? false)) return false;
    final current = tenant;
    if (current == null) return false;
    saving.value = true;
    try {
      await _repository.updateTenant(
        current.copyWith(
          name: nameController.text.trim(),
          businessType: businessType.value,
          currency: currency.value,
          currencySymbol: AppConfig.symbolFor(currency.value),
          taxRate: double.tryParse(taxRateController.text.trim()) ?? 0,
          lowStockThreshold: int.tryParse(lowStockController.text.trim()) ?? 5,
          phone: phoneController.text.trim(),
          email: emailController.text.trim(),
          address: addressController.text.trim(),
        ),
      );
      showAppMessage('Business settings saved.');
      return true;
    } catch (exception) {
      final failure = AppFailure.from(exception);
      error.value = failure.message;
      showAppMessage(failure.message, error: true);
      return false;
    } finally {
      saving.value = false;
    }
  }

  TimeOfDay get briefingTimeOfDay {
    final parts = briefingTime.value.split(':');
    final hour = int.tryParse(parts.first) ?? 22;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  }

  void setBriefingEnabled(bool value) => briefingEnabled.value = value;

  void setBriefingTime(TimeOfDay value) {
    briefingTime.value =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  void setBriefingTimezone(String value) => briefingTimezone.value = value;

  Future<bool> saveBriefingSchedule() async {
    if (!canEdit) {
      showAppMessage(
        'Only an admin can change the briefing schedule.',
        error: true,
      );
      return false;
    }
    final current = tenant;
    if (current == null) return false;
    savingBriefing.value = true;
    try {
      await _repository.updateTenant(
        current.copyWith(
          dailyBriefingEnabled: briefingEnabled.value,
          dailyBriefingTime: briefingTime.value,
          dailyBriefingTimezone: briefingTimezone.value,
        ),
      );
      showAppMessage('Daily briefing schedule saved.');
      return true;
    } catch (exception) {
      final failure = AppFailure.from(exception);
      error.value = failure.message;
      showAppMessage(failure.message, error: true);
      return false;
    } finally {
      savingBriefing.value = false;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) => theme.setMode(mode);

  Future<void> setLanguage(Locale locale) => language.setLocale(locale);

  Future<void> signOut() async {
    await _session.signOut();
    Get.offAllNamed(Routes.login);
  }

  Future<void> resetDemo() async {
    try {
      await _repository.resetDemoData();
      await _session.signOut();
      Get.offAllNamed(Routes.login);
      showAppMessage('Demo data has been reset.');
    } catch (exception) {
      showAppMessage(AppFailure.from(exception).message, error: true);
    }
  }

  /// Leaves the local demo and returns to the real Supabase workspace.
  Future<void> useCloud() async {
    await _session.signOut();
    Get.offAllNamed(Routes.login);
  }

  @override
  void onClose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    taxRateController.dispose();
    lowStockController.dispose();
    super.onClose();
  }
}
