import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'data_store.dart';
import 'demo_seed.dart';

/// A durable, offline-first store used for evaluation and local-first demos.
///
/// This is deliberately simple: it supports the same table/row semantics as
/// PostgREST and persists the whole database as JSON. It is not intended to
/// replace Supabase in production; it lets the complete product be evaluated
/// without credentials and provides a foundation for future offline sync.
class LocalDataStore implements DataStore {
  LocalDataStore(this._prefs);

  static const String _storageKey = 'afrazflow.local.db.v1';
  static const Uuid _uuid = Uuid();

  final SharedPreferences _prefs;
  final Map<String, List<Row>> _tables = {};
  bool _loaded = false;

  @override
  bool get isRemote => false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final raw = _prefs.getString(_storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          decoded.forEach((table, rows) {
            if (rows is List) {
              _tables[table] = rows
                  .whereType<Map>()
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList();
            }
          });
        }
      } catch (_) {
        _tables.clear();
      }
    }
    if (_tables.isEmpty) {
      _tables.addAll(DemoSeed.build());
      await _persist();
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    await _prefs.setString(_storageKey, jsonEncode(_tables));
  }

  List<Row> _table(String name) => _tables.putIfAbsent(name, () => []);

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
    await _ensureLoaded();
    var rows = _table(table).where((row) {
      for (final entry in eq.entries) {
        if (row[entry.key] != entry.value) return false;
      }
      for (final entry in inFilter.entries) {
        if (!entry.value.contains(row[entry.key])) return false;
      }
      if (searchColumn != null &&
          search != null &&
          search.trim().isNotEmpty) {
        final value = (row[searchColumn] ?? '').toString().toLowerCase();
        if (!value.contains(search.trim().toLowerCase())) return false;
      }
      return true;
    }).toList();

    if (orderBy != null) {
      rows.sort((a, b) {
        final left = a[orderBy];
        final right = b[orderBy];
        int result;
        if (left is num && right is num) {
          result = left.compareTo(right);
        } else {
          result = (left ?? '').toString().compareTo((right ?? '').toString());
        }
        return ascending ? result : -result;
      });
    }
    if (limit != null && limit > 0 && rows.length > limit) {
      rows = rows.take(limit).toList();
    }
    return rows
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  @override
  Future<Row?> findById(String table, String id) async {
    final rows = await select(table, eq: {'id': id}, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Row> insert(String table, Row data) async {
    await _ensureLoaded();
    final now = DateTime.now().toUtc().toIso8601String();
    final row = Map<String, dynamic>.from(data);
    row['id'] = (row['id'] as String?)?.trim().isNotEmpty == true
        ? row['id']
        : _uuid.v4();
    row.putIfAbsent('created_at', () => now);
    row.putIfAbsent('updated_at', () => now);
    _table(table).add(row);
    await _persist();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Row> update(String table, String id, Row data) async {
    await _ensureLoaded();
    final rows = _table(table);
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index < 0) {
      throw StateError('Record not found in $table');
    }
    final updated = <String, dynamic>{...rows[index], ...data};
    updated['id'] = id;
    updated['updated_at'] = DateTime.now().toUtc().toIso8601String();
    rows[index] = updated;
    await _persist();
    return Map<String, dynamic>.from(updated);
  }

  @override
  Future<void> delete(String table, String id) async {
    await _ensureLoaded();
    _table(table).removeWhere((row) => row['id'] == id);
    await _persist();
  }

  @override
  Future<void> deleteWhere(String table, Map<String, Object?> eq) async {
    await _ensureLoaded();
    _table(table).removeWhere((row) {
      for (final entry in eq.entries) {
        if (row[entry.key] != entry.value) return false;
      }
      return true;
    });
    await _persist();
  }

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) {
    throw UnsupportedError('RPC is only available on the Supabase backend');
  }

  /// Wipes and re-seeds demo data. Exposed in Settings → Demo tools.
  Future<void> resetDemoData() async {
    _tables
      ..clear()
      ..addAll(DemoSeed.build());
    _loaded = true;
    await _persist();
  }

  Future<void> clearAll() async {
    _tables.clear();
    _loaded = true;
    await _persist();
  }
}
