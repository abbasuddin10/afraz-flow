import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';

import '../../features/shell/controllers/navigation_controller.dart';
import '../../routes/app_routes.dart';
import '../data/data_store.dart';
import '../utils/json_helpers.dart';
import 'app_services.dart';

/// Top-level background handler. Must live outside any class so the
/// Firebase plugin can spawn it in a background isolate while the app is
/// terminated (Android).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
  debugPrint(
    'FCM background message received: ${message.messageId} '
    '(kind: ${message.data['kind']})',
  );

  // FCM displays messages that carry a `notification` block by itself while
  // the app is in the background. Data-only messages are delivered silently,
  // so mirror those as a local notification to guarantee the alert is seen.
  if (message.notification == null && message.data.isNotEmpty) {
    await _showBackgroundNotification(message.data);
  }
}

/// Displays a data-only push from the background isolate. Kept at top level
/// (with its own local-notifications instance) because background handlers
/// cannot reach the GetX `PushNotificationService` instance.
Future<void> _showBackgroundNotification(Map<String, dynamic> data) async {
  try {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(
          PushNotificationService.notificationIcon,
        ),
        iOS: DarwinInitializationSettings(),
      ),
    );
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          PushNotificationService.channelId,
          PushNotificationService.channelName,
          description: PushNotificationService.channelDescription,
          importance: Importance.high,
        ),
      );
    }
    final body = data['body']?.toString() ?? '';
    await plugin.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
      title: data['title']?.toString() ?? PushNotificationService.appName,
      body: body,
      notificationDetails: PushNotificationService.notificationDetails(body),
      payload: jsonEncode({
        'kind': data['kind']?.toString() ?? '',
        'reference_id': data['reference_id']?.toString() ?? '',
        'title': data['title']?.toString() ?? '',
        'body': data['body']?.toString() ?? '',
      }),
    );
  } catch (error) {
    debugPrint('Background local notification failed: $error');
  }
}

/// Real-time mobile push notifications over Firebase Cloud Messaging.
///
/// The Supabase database is the source of truth: when a row lands in
/// `app_notifications` (Daily AI Briefing or a low stock alert), a Postgres
/// trigger calls the `notify-push` Edge Function, which looks up the device
/// tokens in `fcm_tokens` and delivers an FCM message. This service:
///
/// * initialises Firebase + the local notification channel,
/// * asks for the Android 13+ notification permission,
/// * registers and keeps fresh the device's FCM token in `fcm_tokens`,
/// * shows a local notification when a push arrives while the app is in the
///   foreground (Android/iOS only auto-display background pushes),
/// * routes a tap on a push to the Briefing or Inventory section.
///
/// Firebase degrades gracefully: if `google-services.json` is missing or
/// initialisation fails, [available] stays false and the app continues with
/// the in-app bell only.
class PushNotificationService extends GetxService {
  PushNotificationService(this._store, this._session);

  static const String channelId = 'afraz_flow_alerts';
  static const String channelName = 'Afraz Flow alerts';
  static const String channelDescription =
      'Daily AI briefings and low stock alerts';

  /// Branded assets for the system notification banner. The status bar uses
  /// the white "AF" silhouette (Android requires a monochrome small icon),
  /// while the full-colour launcher logo stays as the large icon so the app
  /// logo is always visible in the shade.
  static const String appName = 'Afraz Flow';
  static const String notificationIcon = '@drawable/ic_stat_afraz_flow';
  static const String notificationLargeIcon = '@mipmap/launcher_icon';
  static const Color brandColor = Color(0xFF03265E);

  /// Layout shared by foreground and background notifications: app logo,
  /// brand accent, app name as sub-text and an expandable full message.
  static NotificationDetails notificationDetails(String body) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        channelDescription: channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        icon: notificationIcon,
        largeIcon: const DrawableResourceAndroidBitmap(notificationLargeIcon),
        color: brandColor,
        styleInformation: BigTextStyleInformation(body),
        subText: appName,
        category: AndroidNotificationCategory.message,
        groupKey: channelId,
        autoCancel: true,
        showWhen: true,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        subtitle: appName,
        threadIdentifier: channelId,
      ),
    );
  }

  final DataStore _store;
  final SessionService _session;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool available = false;
  String? _token;
  bool _initializing = false;
  bool _initialized = false;

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Called after Firebase/notifications bootstrap. Non-blocking and safe to
  /// call more than once.
  Future<void> initialize() async {
    if (_initialized || _initializing || !isSupported) return;
    _initializing = true;

    try {
      await _initLocalNotifications();
    } catch (error) {
      debugPrint('Local notification setup failed: $error');
    }

    try {
      await Firebase.initializeApp();
      available = true;
    } catch (error, stackTrace) {
      debugPrint('Firebase init failed — push disabled: $error');
      debugPrint('$stackTrace');
      _initializing = false;
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('Notification permission: ${settings.authorizationStatus}');
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
    }

    try {
      // ignore: deprecated_member_use
      _messaging.onTokenRefresh.listen((token) {
        _token = token;
        unawaited(registerToken());
      });
      // ignore: deprecated_member_use
      _token = await _messaging.getToken();
    } catch (error) {
      debugPrint('FCM token fetch failed: $error');
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);
    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null) _onMessageTap(initial);
    } catch (_) {}

    _initialized = true;
    _initializing = false;
    await registerToken();
  }

  /// Called whenever a session becomes available (fresh sign-in or a
  /// restored session) so the device token is attached to the right
  /// tenant/profile.
  Future<void> onSessionReady() async {
    if (!_initialized) {
      unawaited(initialize());
      return;
    }
    await registerToken();
  }

  /// Upserts this device's FCM token into `fcm_tokens`, scoped to the
  /// signed-in tenant and profile. Cloud sessions only — the offline demo
  /// has no push backend.
  Future<void> registerToken() async {
    final token = _token;
    if (!available || token == null || token.isEmpty) return;
    if (!_store.isRemote || _session.isDemo) return;
    final userId = _session.userId;
    final tenantId = _session.tenantId;
    if (userId.isEmpty || tenantId.isEmpty) return;

    final now = toIso(DateTime.now());
    final payload = <String, dynamic>{
      'token': token,
      'user_id': userId,
      'tenant_id': tenantId,
      'platform': Platform.isAndroid ? 'android' : 'ios',
      'updated_at': now,
    };
    try {
      final existing = await _store.select(
        'fcm_tokens',
        eq: {'token': token},
        limit: 1,
      );
      if (existing.isEmpty) {
        await _store.insert('fcm_tokens', {...payload, 'created_at': now});
      } else {
        final id = asString(existing.first['id']);
        if (id.isNotEmpty) {
          await _store.update('fcm_tokens', id, payload);
        }
      }
    } catch (error) {
      debugPrint('FCM token registration failed: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // Display + routing
  // ---------------------------------------------------------------------------

  Future<void> _initLocalNotifications() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings(notificationIcon),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );
    final android = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          channelId,
          channelName,
          description: channelDescription,
          importance: Importance.high,
        ),
      );
      final enabled = await android.areNotificationsEnabled() ?? true;
      if (!enabled) await android.requestNotificationsPermission();
    }
  }

  /// While the app is open, FCM notification messages are not shown by the
  /// system, so mirror them as a local notification.
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;
    final title = notification?.title ??
        (data['title']?.toString() ?? appName);
    final body = notification?.body ?? data['body']?.toString() ?? '';
    await showLocalNotification(
      title: title,
      body: body,
      payload: _payload(message.data),
    );
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(1000000),
        title: title,
        body: body,
        notificationDetails: notificationDetails(body),
        payload: payload,
      );
    } catch (error) {
      debugPrint('Local notification failed: $error');
    }
  }

  String _payload(Map<String, dynamic> data) => jsonEncode({
    'kind': data['kind']?.toString() ?? '',
    'reference_id': data['reference_id']?.toString() ?? '',
    'title': data['title']?.toString() ?? '',
    'body': data['body']?.toString() ?? '',
  });

  Future<void> _onLocalNotificationTap(NotificationResponse response) async {
    try {
      final decoded = jsonDecode(response.payload ?? '');
      if (decoded is Map) {
        await routeToSection(
          kind: decoded['kind']?.toString(),
        );
      }
    } catch (_) {}
  }

  void _onMessageTap(RemoteMessage message) {
    unawaited(
      routeToSection(
        kind: message.data['kind']?.toString(),
      ),
    );
  }

  /// Opens the section that matches the notification kind: briefings jump to
  /// the Daily AI Briefing, low stock alerts to Inventory.
  Future<void> routeToSection({String? kind}) async {
    AppSection? section;
    switch (kind) {
      case 'daily_briefing':
        section = AppSection.briefing;
      case 'low_stock':
        section = AppSection.inventory;
      default:
        return;
    }
    try {
      Get.find<NavigationController>().go(section);
    } catch (_) {
      // Cold start from a terminated app: the shell may not be bound yet.
      await Get.toNamed(Routes.shell);
      try {
        Get.find<NavigationController>().go(section);
      } catch (_) {}
    }
  }
}
