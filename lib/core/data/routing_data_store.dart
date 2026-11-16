import 'backend_mode.dart';
import 'data_store.dart';

/// A [DataStore] that forwards every call to the backend selected by
/// [BackendMode].
///
/// Repositories receive this single instance at bootstrap, so switching between
/// Supabase and the on-device demo store at runtime never requires rebuilding
/// the dependency graph.
class RoutingDataStore implements DataStore {
  RoutingDataStore({
    required DataStore? cloud,
    required DataStore local,
    required BackendMode mode,
  }) : _cloud = cloud,
       _local = local,
       _mode = mode;

  final DataStore? _cloud;
  final DataStore _local;
  final BackendMode _mode;

  DataStore get local => _local;
  DataStore? get cloud => _cloud;

  DataStore get active {
    if (_mode.isRemote) {
      final cloud = _cloud;
      if (cloud != null) return cloud;
    }
    return _local;
  }

  @override
  bool get isRemote => active.isRemote;

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
  }) => active.select(
    table,
    eq: eq,
    inFilter: inFilter,
    orderBy: orderBy,
    ascending: ascending,
    limit: limit,
    searchColumn: searchColumn,
    search: search,
  );

  @override
  Future<Row?> findById(String table, String id) =>
      active.findById(table, id);

  @override
  Future<Row> insert(String table, Row data) => active.insert(table, data);

  @override
  Future<Row> update(String table, String id, Row data) =>
      active.update(table, id, data);

  @override
  Future<void> delete(String table, String id) => active.delete(table, id);

  @override
  Future<void> deleteWhere(String table, Map<String, Object?> eq) =>
      active.deleteWhere(table, eq);

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      active.rpc(function, params);
}
