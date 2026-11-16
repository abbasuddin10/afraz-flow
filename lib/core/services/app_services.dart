import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/backend_mode.dart';
import '../utils/formatters.dart';
import '../data/data_store.dart';
import '../models/app_user.dart';
import '../models/tenant.dart';
import '../utils/app_failure.dart';
import '../../features/auth/data/auth_repository.dart';

/// A tiny typed wrapper around SharedPreferences for UI preferences.
class PreferencesService extends GetxService {
  PreferencesService(this._prefs);

  static const String _themeKey = 'afrazflow.theme';
  static const String _lastEmailKey = 'afrazflow.last_email';
  static const String _languageKey = 'afrazflow.language';

  final SharedPreferences _prefs;

  ThemeMode get themeMode {
    switch (_prefs.getString(_themeKey)) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_themeKey, mode.name);
  }

  String? get lastEmail => _prefs.getString(_lastEmailKey);

  Future<void> setLastEmail(String email) async {
    await _prefs.setString(_lastEmailKey, email.trim());
  }

  Locale get locale {
    final raw = _prefs.getString(_languageKey) ?? 'en_US';
    final parts = raw.split('_');
    if (parts.length == 1) return Locale(parts.first);
    return Locale(parts[0], parts[1]);
  }

  Future<void> setLocale(Locale locale) async {
    final country = locale.countryCode;
    await _prefs.setString(
      _languageKey,
      country == null || country.isEmpty
          ? locale.languageCode
          : '${locale.languageCode}_$country',
    );
  }
}

class ThemeController extends GetxController {
  ThemeController(this._preferences)
    : mode = _preferences.themeMode.obs;

  final PreferencesService _preferences;
  final Rx<ThemeMode> mode;

  bool get isDark {
    if (mode.value == ThemeMode.system) {
      final brightness =
          Get.context?.theme.brightness ?? Brightness.light;
      return brightness == Brightness.dark;
    }
    return mode.value == ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode value) async {
    mode.value = value;
    await _preferences.setThemeMode(value);
    Get.changeThemeMode(value);
  }

  Future<void> toggle() async {
    final context = Get.context;
    final effectiveDark = mode.value == ThemeMode.dark ||
        (mode.value == ThemeMode.system &&
            (context?.theme.brightness ?? Brightness.light) ==
                Brightness.dark);
    await setMode(effectiveDark ? ThemeMode.light : ThemeMode.dark);
  }
}

/// Holds the active UI language and persists it across sessions.
class LanguageController extends GetxController {
  LanguageController(this._preferences)
      : locale = _preferences.locale.obs;

  final PreferencesService _preferences;
  final Rx<Locale> locale;

  @override
  void onInit() {
    super.onInit();
    Formats.setLocale(locale.value);
  }

  Future<void> setLocale(Locale value) async {
    locale.value = value;
    await _preferences.setLocale(value);
    // Keep number/date formatting and GetX's global locale in sync with the
    // newly selected language.
    Formats.setLocale(value);
    Get.locale = value;
    Get.updateLocale(value);
  }
}

/// Holds the authenticated tenant context. All feature repositories read the
/// tenant id from here, and RLS independently enforces the same boundary.
class SessionService extends GetxService {
  SessionService(this._auth, {BackendMode? mode}) : _mode = mode;

  final AuthRepository _auth;
  final BackendMode? _mode;

  final Rxn<AppSession> _session = Rxn<AppSession>();
  final RxBool restoring = true.obs;
  final RxBool busy = false.obs;

  AppSession? get session => _session.value;
  bool get isAuthenticated => _session.value != null;
  bool get isDemo => _session.value?.isDemo ?? false;

  String get tenantId => _session.value?.tenantId ?? '';
  String get userId => _session.value?.user.id ?? '';

  Tenant? get tenant => _session.value?.tenant;
  AppUser? get user => _session.value?.user;
  MemberRole get role => _session.value?.role ?? MemberRole.cashier;

  String get currencySymbol => tenant?.currencySymbol ?? 'Rs';
  String get currency => tenant?.currency ?? 'PKR';

  String requireTenantId() {
    final value = _session.value?.tenantId;
    if (value == null || value.isEmpty) {
      throw const AppFailure('No active organization. Please sign in again.');
    }
    return value;
  }

  Future<bool> restore() async {
    restoring.value = true;
    try {
      final value = await _auth.restoreSession();
      _session.value = value;
      return value != null;
    } finally {
      restoring.value = false;
    }
  }

  void adopt(AppSession value) {
    _session.value = value;
  }

  void updateTenant(Tenant tenant) {
    final current = _session.value;
    if (current == null) return;
    _session.value = current.copyWith(tenant: tenant);
  }

  void updateUser(AppUser user) {
    final current = _session.value;
    if (current == null) return;
    _session.value = current.copyWith(
      user: user,
      membership: current.membership.copyWith(user: user),
    );
  }

  Future<void> signOut() async {
    busy.value = true;
    try {
      await _auth.signOut();
      _session.value = null;
      // Leaving the demo returns the next sign-in to the real workspace.
      await _mode?.useCloud();
    } finally {
      busy.value = false;
    }
  }

  DataStore get dataStore => Get.find<DataStore>();
}
