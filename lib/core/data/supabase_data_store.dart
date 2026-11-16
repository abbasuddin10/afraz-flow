import 'package:supabase_flutter/supabase_flutter.dart';

import 'data_store.dart';

/// Supabase/PostgREST implementation. Every table is protected by RLS; callers
/// additionally scope queries with `tenant_id` as defence in depth.
class SupabaseDataStore implements DataStore {
  SupabaseDataStore(this.client);

  final SupabaseClient client;

  @override
  bool get isRemote => true;

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
    dynamic query = client.from(table).select();

    eq.forEach((key, value) {
      query = value == null
          ? query.filter(key, 'is', null)
          : query.eq(key, value);
    });
    inFilter.forEach((key, values) {
      query = query.inFilter(key, values);
    });
    if (searchColumn != null &&
        search != null &&
        search.trim().isNotEmpty) {
      query = query.ilike(searchColumn, '%${search.trim()}%');
    }
    if (orderBy != null && orderBy.isNotEmpty) {
      query = query.order(orderBy, ascending: ascending);
    }
    if (limit != null && limit > 0) query = query.limit(limit);

    final data = await query;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    return [];
  }

  @override
  Future<Row?> findById(String table, String id) async {
    final row = await client.from(table).select().eq('id', id).maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  @override
  Future<Row> insert(String table, Row data) async {
    final row = await client.from(table).insert(data).select().single();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<Row> update(String table, String id, Row data) async {
    final row = await client
        .from(table)
        .update(data)
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  @override
  Future<void> delete(String table, String id) async {
    await client.from(table).delete().eq('id', id);
  }

  @override
  Future<void> deleteWhere(String table, Map<String, Object?> eq) async {
    dynamic query = client.from(table).delete();
    eq.forEach((key, value) {
      query = value == null
          ? query.filter(key, 'is', null)
          : query.eq(key, value);
    });
    await query;
  }

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      client.rpc(function, params: params);
}
