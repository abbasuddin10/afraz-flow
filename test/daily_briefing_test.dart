import 'package:afraz_flow/core/data/demo_seed.dart';
import 'package:afraz_flow/core/data/local_data_store.dart';
import 'package:afraz_flow/core/services/app_services.dart';
import 'package:afraz_flow/features/auth/data/auth_repository.dart';
import 'package:afraz_flow/features/briefing/data/briefing_repository.dart';
import 'package:afraz_flow/features/notifications/data/notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late LocalDataStore store;
  late SessionService session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    store = LocalDataStore(prefs);
    final auth = AuthRepository(store: store, prefs: prefs);
    final signedIn = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    session = SessionService(auth)..adopt(signedIn);
  });

  test('the demo seed ships a briefing and an unread notification', () async {
    final briefings = BriefingRepository(store, session);
    final history = await briefings.history();

    expect(history, isNotEmpty);
    expect(history.first.isToday, isTrue);
    expect(history.first.source, 'local');
    expect(history.first.metrics.currencySymbol, r'$');
    expect(history.first.metrics.salesCount, greaterThan(0));

    final notifications = NotificationRepository(store, session);
    final inbox = await notifications.all();

    expect(inbox, isNotEmpty);
    expect(inbox.first.isBriefing, isTrue);
    expect(inbox.first.body, contains('Tap to view.'));
    expect(await notifications.unreadCount(), greaterThan(0));

    await notifications.markRead(inbox.first.id);
    expect(await notifications.unreadCount(), 0);
  });

  test(
    'generating a briefing locally upserts today and raises reorders',
    () async {
      final briefings = BriefingRepository(store, session);
      final notifications = NotificationRepository(store, session);
      final unreadBefore = await notifications.unreadCount();

      final generated = await briefings.generate();
      final history = await briefings.history();

      expect(
        history.where((item) => item.dateKey == generated.dateKey),
        hasLength(1),
      );
      expect(history.first.dateKey, generated.dateKey);
      expect(generated.isManual, isTrue);
      expect(generated.metrics.reorderCount, greaterThan(0));

      final reorders = await store.select(
        'inventory_reorders',
        eq: {'tenant_id': DemoSeed.tenantId},
      );
      expect(reorders, isNotEmpty);

      // The seeded notification already covers today's briefing, so the
      // dedupe key keeps the inbox stable.
      expect(await notifications.unreadCount(), unreadBefore);
    },
  );
}
