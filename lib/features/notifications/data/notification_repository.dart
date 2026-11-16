import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/data_store.dart';
import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/json_helpers.dart';
import 'app_notification.dart';

/// Reads, updates and streams the signed-in user's in-app notifications.
///
/// Every row is private to a profile. In cloud mode Supabase Realtime pushes
/// new rows as they are inserted by the briefing pipeline; the local demo keeps
/// the same API but without a socket.
class NotificationRepository {
  NotificationRepository(this._store, this._session, {SupabaseClient? client})
    : _client = client;

  final DataStore _store;
  final SessionService _session;
  final SupabaseClient? _client;

  RealtimeChannel? _channel;

  bool get realtimeAvailable => _client != null && !_session.isDemo;

  Future<List<AppNotification>> all({int limit = 40}) async {
    final userId = _session.userId;
    if (userId.isEmpty) return const [];
    final rows = await _store.select(
      'app_notifications',
      eq: {'user_id': userId},
      orderBy: 'created_at',
      limit: limit,
    );
    return rows.map(AppNotification.fromJson).toList(growable: false);
  }

  Future<int> unreadCount() async {
    final userId = _session.userId;
    if (userId.isEmpty) return 0;
    final rows = await _store.select(
      'app_notifications',
      eq: {'user_id': userId, 'read_at': null},
      limit: 200,
    );
    return rows.length;
  }

  Future<AppNotification> markRead(String id) async {
    final row = await _store.update('app_notifications', id, {
      'read_at': toIso(DateTime.now()),
    });
    return AppNotification.fromJson(row);
  }

  Future<void> markAllRead(List<String> ids) async {
    if (ids.isEmpty) return;
    final now = toIso(DateTime.now());
    for (final id in ids) {
      try {
        await _store.update('app_notifications', id, {'read_at': now});
      } on AppFailure {
        rethrow;
      } catch (_) {
        // A row may have been removed elsewhere; keep clearing the rest.
      }
    }
  }

  Future<void> clearAll() async {
    final userId = _session.userId;
    if (userId.isEmpty) return;
    await _store.deleteWhere('app_notifications', {'user_id': userId});
  }

  /// Subscribes to inserts addressed to the current profile.
  ///
  /// Returns quietly when Realtime is unavailable (for example in the offline
  /// demo). The shell still refreshes the bell when the sheet opens.
  Future<void> startRealtime(
    void Function(AppNotification notification) onInsert,
  ) async {
    final client = _client;
    final userId = _session.userId;
    if (client == null || userId.isEmpty || !realtimeAvailable) return;
    await stopRealtime();

    _channel = client
        .channel('app-notifications:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'app_notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isEmpty) return;
            try {
              onInsert(
                AppNotification.fromJson(Map<String, dynamic>.from(record)),
              );
            } catch (_) {
              // Ignore malformed payloads; the next refresh will catch up.
            }
          },
        )
        .subscribe();
  }

  Future<void> stopRealtime() async {
    final client = _client;
    final channel = _channel;
    _channel = null;
    if (client == null || channel == null) return;
    await client.removeChannel(channel);
  }
}
