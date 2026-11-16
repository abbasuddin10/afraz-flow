import 'dart:async';
import 'package:flutter/material.dart';
import 'app.dart';
import 'app_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  try {
    await AppBootstrap.initialize().timeout(const Duration(seconds: 15));
  } catch (error, stackTrace) {
    debugPrint('Bootstrap failed: $error');
    debugPrint('$stackTrace');
  }
  runApp(const AfrazFlowApp());
}
