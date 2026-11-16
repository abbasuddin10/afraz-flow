import 'package:afraz_flow/core/data/backend_mode.dart';
import 'package:afraz_flow/core/data/data_store.dart';
import 'package:afraz_flow/core/data/routing_data_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal in-memory [DataStore] that tags every row it returns so a test can
/// prove which backend actually served a call.
class _FakeStore implements DataStore {
  _FakeStore(this.tag, {this.remote = false});

  final String tag;
  final bool remote;

  int calls = 0;

  @override
  bool get isRemote => remote;

  @override
  Future<List<Row>> select(
    String table, {
    Map<String, Object?> eq = const {},
    Map<String, List<Object?>> inFilter = const {},
    String? orderBy,
    bool ascending = false,
    int? limit,
    String? searchColumn,
    String? search,
  }) async {
    calls++;
    return [
      {'served_by': tag},
    ];
  }

  @override
  Future<Row?> findById(String table, String id) async {
    calls++;
    return {'served_by': tag};
  }

  @override
  Future<Row> insert(String table, Row data) async {
    calls++;
    return {...data, 'served_by': tag};
  }

  @override
  Future<Row> update(String table, String id, Row data) async {
    calls++;
    return {...data, 'served_by': tag};
  }

  @override
  Future<void> delete(String table, String id) async => calls++;

  @override
  Future<void> deleteWhere(String table, Map<String, Object?> eq) async =>
      calls++;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) async {
    calls++;
    return tag;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('a device without credentials stays on the local demo backend', () async {
    final mode = BackendMode(prefs: prefs, cloudAvailable: false);
    final local = _FakeStore('local');
    final store = RoutingDataStore(cloud: null, local: local, mode: mode);

    expect(mode.isDemo, isTrue);
    expect(mode.isRemote, isFalse);
    expect(store.isRemote, isFalse);

    final rows = await store.select('products');
    expect(rows.single['served_by'], 'local');
    expect(local.calls, 1);
  });

  test('production builds default to the cloud backend', () async {
    final mode = BackendMode(prefs: prefs, cloudAvailable: true);
    final cloud = _FakeStore('cloud', remote: true);
    final local = _FakeStore('local');
    final store = RoutingDataStore(cloud: cloud, local: local, mode: mode);

    expect(mode.isRemote, isTrue);
    expect(store.isRemote, isTrue);

    final rows = await store.select('sales');
    expect(rows.single['served_by'], 'cloud');
    expect(cloud.calls, 1);
    expect(local.calls, 0);
  });

  test('the demo choice is persisted and never touches the cloud', () async {
    final mode = BackendMode(prefs: prefs, cloudAvailable: true);
    final cloud = _FakeStore('cloud', remote: true);
    final local = _FakeStore('local');
    final store = RoutingDataStore(cloud: cloud, local: local, mode: mode);

    await mode.useDemo();

    expect(store.isRemote, isFalse);
    final rows = await store.select('products');
    expect(rows.single['served_by'], 'local');
    expect(cloud.calls, 0);

    // A fresh instance on the same device reopens the demo workspace.
    final reopened = BackendMode(prefs: prefs, cloudAvailable: true);
    expect(reopened.isDemo, isTrue);

    await reopened.useCloud();
    expect(reopened.isRemote, isTrue);
    final switched = RoutingDataStore(
      cloud: cloud,
      local: local,
      mode: reopened,
    );
    final afterSwitch = await switched.select('products');
    expect(afterSwitch.single['served_by'], 'cloud');
  });

  test('useCloud is a no-op when credentials are missing', () async {
    final mode = BackendMode(prefs: prefs, cloudAvailable: false);
    await mode.useCloud();
    expect(mode.isDemo, isTrue);
  });
}
