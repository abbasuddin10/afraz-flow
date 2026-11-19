import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../data_store.dart';

/// Client-side cache for cloud reads.
///
/// The Supabase free tier charges every read against the database, so the
/// mobile app keeps a small persistent cache (Hive box) of fetched rows:
///
/// * A screen visit that was fetched recently is served straight from the
///   cache — zero Supabase reads.
/// * Every write (`insert`/`update`/`delete`/`deleteWhere` and the data
///   mutating RPCs) invalidates the affected table immediately, so the next
///   visit re-syncs only when something actually changed.
/// * Entries older than their per-table TTL are returned instantly and a
///   silent background revalidation refreshes the cache for the next visit
///   (stale-while-revalidate), which also picks up changes made on another
///   device.
/// * Pull-to-refresh calls [expireAll] so the next load is fully fresh.
///
/// Only reads are cached; the cache is bypassed entirely for notifications
/// (realtime-driven) and membership/profile rows (auth correctness), and it
/// is cleared on sign-out so tenants never see each other's data.
class DataCache {
  DataCache._(Box<String>? box) : _box = box;

  static const String boxName = 'afrazflow_cache';

  /// Tables that must never be cached. `app_notifications` streams over
  /// Supabase Realtime; memberships and profiles drive role checks and must
  /// always reflect the server.
  static const Set<String> neverCache = {
    'app_notifications',
    'profiles',
    'tenant_members',
    'demo_accounts',
  };

  /// How long a cached read stays valid per table. Anything not listed uses
  /// [defaultTtl].
  static const Map<String, Duration> tableTtl = {
    'tenants': Duration(minutes: 20),
    'products': Duration(minutes: 3),
    'sales': Duration(minutes: 3),
    'sale_items': Duration(minutes: 3),
    'stock_movements': Duration(minutes: 3),
    'courier_orders': Duration(minutes: 3),
    'courier_events': Duration(minutes: 3),
    'inventory_reorders': Duration(minutes: 3),
    'expenses': Duration(minutes: 5),
    'ledger_accounts': Duration(minutes: 5),
    'ledger_entries': Duration(minutes: 5),
    'daily_summaries': Duration(minutes: 10),
  };

  static const Duration defaultTtl = Duration(minutes: 5);

  final Box<String>? _box;
  final Map<String, String> _memory = {};

  bool get ready => _box != null || _memory.isNotEmpty || true;

  Duration ttlFor(String table) => tableTtl[table] ?? defaultTtl;

  /// Opens the persistent cache. Falls back to an in-memory cache when
  /// Hive is unavailable so the app keeps working everywhere.
  static Future<DataCache> create() async {
    try {
      await Hive.initFlutter();
      final box = await Hive.openBox<String>(boxName);
      return DataCache._(box);
    } catch (error, stackTrace) {
      debugPrint('Local cache init failed — using memory only: $error');
      debugPrint('$stackTrace');
      return DataCache._(null);
    }
  }

  // ---------------------------------------------------------------------------
  // Read / write
  // ---------------------------------------------------------------------------

  List<Row>? read(String key, String table) {
    final raw = _box?.get(key) ?? _memory[key];
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['t'] is num) {
        final storedAt = DateTime.fromMillisecondsSinceEpoch(decoded['t']);
        if (DateTime.now().difference(storedAt) < ttlFor(table)) {
          final rows = decoded['r'];
          if (rows is List) {
            return rows
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList(growable: false);
          }
        }
      }
    } catch (error) {
      debugPrint('Cache read failed for $table: $error');
    }
    _drop(key);
    return null;
  }

  void write(String key, String table, List<Row> rows) {
    final payload = jsonEncode({
      'r': rows,
      't': DateTime.now().millisecondsSinceEpoch,
    });
    try {
      _box?.put(key, payload);
    } catch (error) {
      debugPrint('Cache write failed for $table: $error');
    }
    _memory[key] = payload;
  }

  /// Removes every entry for [table] (selects and findById lookups).
  void invalidateTable(String table) {
    final selectPrefix = 'select|$table|';
    final findPrefix = 'find|$table|';
    final keys = <String>[
      ..._memory.keys.where(
        (key) => key.startsWith(selectPrefix) || key.startsWith(findPrefix),
      ),
    ];
    if (_box != null) {
      keys.addAll(
        _box.keys.whereType<String>().where(
          (key) => key.startsWith(selectPrefix) || key.startsWith(findPrefix),
        ),
      );
    }
    for (final key in keys.toSet()) {
      _drop(key);
    }
  }

  /// Drops every cached entry. Called by pull-to-refresh so the next load
  /// re-fetches everything from Supabase.
  void expireAll() {
    _memory.clear();
    try {
      _box?.clear();
    } catch (error) {
      debugPrint('Cache clear failed: $error');
    }
  }

  void _drop(String key) {
    _memory.remove(key);
    try {
      _box?.delete(key);
    } catch (_) {}
  }

  /// Builds a stable key for a select call so the same query always maps to
  /// the same cache entry.
  static String selectKey({
    required String table,
    required Map<String, Object?> eq,
    required Map<String, List<Object?>> inFilter,
    String? orderBy,
    required bool ascending,
    int? limit,
    String? searchColumn,
    String? search,
  }) {
    return 'select|$table|${_encodeMap(eq)}|${_encodeMap(inFilter)}|'
        '$orderBy|$ascending|$limit|$searchColumn|$search';
  }

  static String findKey(String table, String id) => 'find|$table|$id';

  static String _encodeMap(Map<String, Object?> values) {
    final sorted = SplayTreeMap<String, Object?>.from(
      values,
      (a, b) => a.compareTo(b),
    );
    return jsonEncode(sorted);
  }
}

/// A [DataStore] decorator that adds [DataCache] in front of the cloud
/// backend. Writes always hit the real store first and then invalidate the
/// affected table, so create/update/delete flows re-sync on the next read.
class CachedDataStore implements DataStore {
  CachedDataStore(
    this._inner, {
    required DataCache cache,
    Set<String> uncachedTables = const {},
  }) : _cache = cache,
       _uncached = uncachedTables;

  final DataStore _inner;
  final DataCache _cache;
  final Set<String> _uncached;
  final Set<String> _revalidating = {};

  bool _cachable(String table) =>
      _cache.ready &&
      !DataCache.neverCache.contains(table) &&
      !_uncached.contains(table);

  @override
  bool get isRemote => _inner.isRemote;

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
    if (!_cachable(table)) {
      return _inner.select(
        table,
        eq: eq,
        inFilter: inFilter,
        orderBy: orderBy,
        ascending: ascending,
        limit: limit,
        searchColumn: searchColumn,
        search: search,
      );
    }

    final key = DataCache.selectKey(
      table: table,
      eq: eq,
      inFilter: inFilter,
      orderBy: orderBy,
      ascending: ascending,
      limit: limit,
      searchColumn: searchColumn,
      search: search,
    );

    final cached = _cache.read(key, table);
    if (cached != null) {
      _revalidateInBackground(key, table, {
        'eq': eq,
        'inFilter': inFilter,
        'orderBy': orderBy,
        'ascending': ascending,
        'limit': limit,
        'searchColumn': searchColumn,
        'search': search,
      });
      return cached;
    }

    final rows = await _inner.select(
      table,
      eq: eq,
      inFilter: inFilter,
      orderBy: orderBy,
      ascending: ascending,
      limit: limit,
      searchColumn: searchColumn,
      search: search,
    );
    _cache.write(key, table, rows);
    return rows;
  }

  @override
  Future<Row?> findById(String table, String id) async {
    if (!_cachable(table)) return _inner.findById(table, id);
    final key = DataCache.findKey(table, id);
    final cached = _cache.read(key, table);
    if (cached != null) {
      _revalidateInBackground(key, table, {'eq': {'id': id}});
      return cached.isEmpty ? null : cached.first;
    }
    final row = await _inner.findById(table, id);
    _cache.write(key, table, row == null ? const [] : [row]);
    return row;
  }

  @override
  Future<Row> insert(String table, Row data) async {
    final row = await _inner.insert(table, data);
    _cache.invalidateTable(table);
    return row;
  }

  @override
  Future<Row> update(String table, String id, Row data) async {
    final row = await _inner.update(table, id, data);
    _cache.invalidateTable(table);
    return row;
  }

  @override
  Future<void> delete(String table, String id) async {
    await _inner.delete(table, id);
    _cache.invalidateTable(table);
  }

  @override
  Future<void> deleteWhere(String table, Map<String, Object?> eq) async {
    await _inner.deleteWhere(table, eq);
    _cache.invalidateTable(table);
  }

  /// RPCs that change data invalidate the affected tables. Auth RPCs
  /// (tenant/profile management) are not listed because those tables are
  /// never cached.
  static const Map<String, List<String>> rpcInvalidations = {
    'checkout_sale': ['products', 'sales', 'sale_items', 'stock_movements'],
    'adjust_stock': ['products', 'stock_movements'],
    'record_ledger_entry': ['ledger_accounts', 'ledger_entries'],
  };

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) async {
    final result = await _inner.rpc(function, params);
    for (final table in rpcInvalidations[function] ?? const <String>[]) {
      _cache.invalidateTable(table);
    }
    return result;
  }

  /// Stale-while-revalidate: an expired cache hit is returned immediately
  /// while a silent background fetch refreshes it for the next visit.
  void _revalidateInBackground(String key, String table, Map<String, dynamic> args) {
    if (!_revalidating.add(key)) return;
    unawaited(() async {
      try {
        final fresh = await _inner.select(
          table,
          eq: args['eq'] as Map<String, Object?>? ?? const {},
          inFilter:
              args['inFilter'] as Map<String, List<Object?>>? ?? const {},
          orderBy: args['orderBy'] as String?,
          ascending: args['ascending'] as bool? ?? false,
          limit: args['limit'] as int?,
          searchColumn: args['searchColumn'] as String?,
          search: args['search'] as String?,
        );
        _cache.write(key, table, fresh);
      } catch (error) {
        // Keep the stale cache; the next visit retries.
        debugPrint('Background revalidation failed for $table: $error');
      } finally {
        _revalidating.remove(key);
      }
    }());
  }
}
