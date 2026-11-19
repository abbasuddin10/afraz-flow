import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'app.dart';
import 'app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('Unhandled error: $error');
    debugPrint('$stackTrace');
    // Keep the app running so a single failed background refresh (or a
    // platform plugin hiccup) cannot take the whole till offline.
    return true;
  };
  try {
    await AppBootstrap.initialize().timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    debugPrint('Bootstrap failed: $error');
    debugPrint('$stackTrace');
  }
  runApp(const AfrazFlowApp());
}
