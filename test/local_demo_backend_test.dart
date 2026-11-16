import 'package:afraz_flow/core/data/demo_seed.dart';
import 'package:afraz_flow/core/data/local_data_store.dart';
import 'package:afraz_flow/core/models/app_user.dart';
import 'package:afraz_flow/core/services/app_services.dart';
import 'package:afraz_flow/core/utils/app_failure.dart';
import 'package:afraz_flow/features/auth/data/auth_repository.dart';
import 'package:afraz_flow/features/auth/data/register_business_input.dart';
import 'package:afraz_flow/features/courier/data/courier_order.dart';
import 'package:afraz_flow/features/courier/data/courier_repository.dart';
import 'package:afraz_flow/features/inventory/data/product_repository.dart';
import 'package:afraz_flow/features/ledger/data/account_repository.dart';
import 'package:afraz_flow/features/pos/data/sale.dart';
import 'package:afraz_flow/features/pos/data/sale_repository.dart';
import 'package:afraz_flow/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late LocalDataStore store;
  late AuthRepository auth;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = LocalDataStore(prefs);
    auth = AuthRepository(store: store, prefs: prefs);
  });

  test('demo sign-in returns the seeded admin workspace', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );

    expect(session.isDemo, isTrue);
    expect(session.role, MemberRole.admin);
    expect(session.tenant.id, DemoSeed.tenantId);
    expect(session.tenant.name, 'Northwind Traders');
    expect(session.user.email, DemoSeed.demoEmail);
    expect(DemoSeed.demoEmail, 'demo@afrazflow.app');
  });

  test('wrong credentials are rejected with a friendly failure', () async {
    await expectLater(
      auth.signIn(email: DemoSeed.demoEmail, password: 'not-the-password'),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          'Incorrect email or password.',
        ),
      ),
    );
  });

  test('sessions restore from local storage', () async {
    await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );

    final restored = await AuthRepository(
      store: store,
      prefs: prefs,
    ).restoreSession();

    expect(restored, isNotNull);
    expect(restored!.tenant.id, DemoSeed.tenantId);
  });

  test('products are always scoped to the active tenant', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final sessionService = SessionService(auth)..adopt(session);
    final repository = ProductRepository(store, sessionService);

    final products = await repository.all();

    expect(products, isNotEmpty);
    expect(
      products.every((product) => product.tenantId == session.tenantId),
      isTrue,
    );
  });

  test('checkout deducts stock and records the credit charge', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final sessionService = SessionService(auth)..adopt(session);
    final products = ProductRepository(store, sessionService);
    final accounts = AccountRepository(store, sessionService);
    final sales = SaleRepository(store, sessionService);

    final product = (await products.all()).firstWhere(
      (item) => item.sku == 'RIC-0001',
    );
    final customer = (await accounts.customers()).firstWhere(
      (account) => account.balance == 0,
    );
    final stockBefore = product.stockQty;

    final sale = await sales.checkout(
      lines: [
        CartLine(
          productId: product.id,
          name: product.name,
          sku: product.sku,
          unitPrice: product.salePrice,
          costPrice: product.costPrice,
          quantity: 2,
          availableStock: product.stockQty,
          unit: product.unit,
        ),
      ],
      method: PaymentMethod.credit,
      discount: 0,
      taxRate: 5,
      accountId: customer.id,
      customerName: customer.name,
      paidAmount: 0,
    );

    final refreshed = (await products.all()).firstWhere(
      (item) => item.id == product.id,
    );
    expect(refreshed.stockQty, stockBefore - 2);
    expect(sale.dueAmount, closeTo(sale.total, 0.001));
    expect(sale.items, hasLength(1));

    final updatedCustomer = (await accounts.customers()).firstWhere(
      (account) => account.id == customer.id,
    );
    expect(updatedCustomer.balance, closeTo(sale.total, 0.01));

    final movements = await products.movements(productId: product.id);
    expect(
      movements.any((movement) => movement.reference == sale.invoiceNo),
      isTrue,
    );
  });

  test('checkout refuses to oversell stock', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final sessionService = SessionService(auth)..adopt(session);
    final products = ProductRepository(store, sessionService);
    final sales = SaleRepository(store, sessionService);
    final product = (await products.all()).firstWhere(
      (item) => item.sku == 'DET-0004',
    );

    await expectLater(
      sales.checkout(
        lines: [
          CartLine(
            productId: product.id,
            name: product.name,
            sku: product.sku,
            unitPrice: product.salePrice,
            costPrice: product.costPrice,
            quantity: product.stockQty + 1,
            availableStock: product.stockQty,
            unit: product.unit,
          ),
        ],
        method: PaymentMethod.cash,
        discount: 0,
        taxRate: 0,
        accountId: null,
        customerName: 'Walk-in customer',
        paidAmount: product.salePrice * (product.stockQty + 1),
      ),
      throwsA(
        isA<AppFailure>().having(
          (failure) => failure.message,
          'message',
          contains('Not enough stock'),
        ),
      ),
    );
  });

  test('COD is reconciled only after delivery', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final sessionService = SessionService(auth)..adopt(session);
    final couriers = CourierRepository(store, sessionService);
    final order = (await couriers.all()).firstWhere(
      (item) => item.hasCod && item.status == CourierStatus.pending,
    );

    await expectLater(couriers.collectCod(order), throwsA(isA<AppFailure>()));

    final shipped = await couriers.changeStatus(
      order: order,
      status: CourierStatus.shipped,
    );
    final delivered = await couriers.changeStatus(
      order: shipped,
      status: CourierStatus.delivered,
    );
    final collected = await couriers.collectCod(delivered);

    expect(collected.codCollected, isTrue);
    final events = await couriers.events(order.id);
    expect(
      events.map((event) => event.status),
      containsAll([CourierStatus.shipped, CourierStatus.delivered]),
    );
    expect(events.any((event) => event.note.contains('COD of')), isTrue);
  });

  test('a second organization cannot see another tenant\'s products', () async {
    final owner = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final ownerSession = SessionService(auth)..adopt(owner);
    final ownerProducts = ProductRepository(store, ownerSession);
    expect(await ownerProducts.all(), isNotEmpty);

    final second = await auth.registerBusiness(
      const RegisterBusinessInput(
        ownerName: 'Sara Iqbal',
        businessName: 'Second Store',
        email: 'sara@example.com',
        password: 'StrongPass123',
        phone: '03001234567',
        businessType: 'Services',
        currency: 'USD',
        taxRate: 0,
        lowStockThreshold: 3,
      ),
    );
    final secondSession = SessionService(auth)..adopt(second);
    final secondProducts = ProductRepository(store, secondSession);

    expect(second.tenant.id, isNot(owner.tenant.id));
    expect(await secondProducts.all(), isEmpty);
    expect(
      (await ownerProducts.all()).every(
        (product) => product.tenantId == owner.tenantId,
      ),
      isTrue,
    );
  });

  test('business settings save and update the live session', () async {
    final session = await auth.signIn(
      email: DemoSeed.demoEmail,
      password: DemoSeed.demoPassword,
    );
    final sessionService = SessionService(auth)..adopt(session);
    final repository = SettingsRepository(store, sessionService);

    final updated = await repository.updateTenant(
      session.tenant.copyWith(name: '  Northwind Express  ', taxRate: 8),
    );

    expect(updated.name, 'Northwind Express');
    expect(updated.taxRate, 8);
    expect(sessionService.tenant?.name, 'Northwind Express');

    final stored = await store.findById('tenants', session.tenantId);
    expect(stored?['name'], 'Northwind Express');
  });

  test('demo reset restores the original seed', () async {
    await store.deleteWhere('products', {'tenant_id': DemoSeed.tenantId});
    expect(await store.select('products'), isEmpty);

    await store.resetDemoData();

    final products = await store.select(
      'products',
      eq: {'tenant_id': DemoSeed.tenantId},
    );
    expect(products, isNotEmpty);
  });
}
