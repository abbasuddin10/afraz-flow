typedef Row = Map<String, dynamic>;

/// Storage abstraction shared by the Supabase backend and the local demo
/// backend. Repositories only speak this API, which keeps the domain layer
/// independent of the cloud provider and makes the app testable offline.
abstract class DataStore {
  bool get isRemote;

  Future<List<Row>> select(
    String table, {
    Map<String, Object?> eq = const {},
    Map<String, List<Object?>> inFilter = const {},
    String? orderBy,
    bool ascending = false,
    int? limit,
    String? searchColumn,
    String? search,
  });

  Future<Row?> findById(String table, String id);

  Future<Row> insert(String table, Row data);

  Future<Row> update(String table, String id, Row data);

  Future<void> delete(String table, String id);

  Future<void> deleteWhere(String table, Map<String, Object?> eq);

  /// Executes a Postgres function. Only the Supabase backend supports this;
  /// the local backend throws and repositories fall back to sequential writes.
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}
