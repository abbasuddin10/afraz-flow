import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Chooses which backend the repositories talk to.
///
/// Production builds start in cloud mode so every write goes to Supabase. The
/// demo workspace stays available from the login screen; it is persisted per
/// device so a reviewer can reopen it, but it never touches the cloud.
class BackendMode extends GetxService {
  BackendMode({
    required SharedPreferences prefs,
    required this.cloudAvailable,
    this.cloudError,
  }) : _prefs = prefs,
       _demo = RxBool(prefs.getString(_key) == _demoValue);

  static const String _key = 'afrazflow.backend.mode';
  static const String _demoValue = 'demo';
  static const String _cloudValue = 'cloud';

  final SharedPreferences _prefs;

  /// True only when credentials are configured *and* the Supabase client was
  /// created successfully.
  final bool cloudAvailable;

  /// Populated when Supabase initialisation failed, so the login screen can
  /// explain why the demo backend is active.
  final String? cloudError;

  final RxBool _demo;

  /// Cloud mode is active. All reads/writes go to Supabase.
  bool get isRemote => cloudAvailable && !_demo.value;

  /// Local demo mode is active. All reads/writes stay on this device.
  bool get isDemo => !isRemote;

  Future<void> useDemo() async {
    _demo.value = true;
    await _prefs.setString(_key, _demoValue);
  }

  Future<void> useCloud() async {
    if (!cloudAvailable) return;
    _demo.value = false;
    await _prefs.setString(_key, _cloudValue);
  }
}
