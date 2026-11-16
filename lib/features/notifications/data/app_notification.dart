import '../../../core/utils/json_helpers.dart';

/// An in-app notification addressed to a single profile. RLS keeps these
/// private, and Supabase Realtime streams new rows to the signed-in device.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.title,
    required this.body,
    required this.kind,
    this.referenceId,
    required this.dedupeKey,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String tenantId;
  final String userId;
  final String title;
  final String body;
  final String kind;
  final String? referenceId;
  final String dedupeKey;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;
  bool get isBriefing => kind == 'daily_briefing';

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: asString(json['id']),
        tenantId: asString(json['tenant_id']),
        userId: asString(json['user_id']),
        title: asString(json['title'], 'Notification'),
        body: asString(json['body']),
        kind: asString(json['kind'], 'general'),
        referenceId: asNullableString(json['reference_id']),
        dedupeKey: asString(json['dedupe_key']),
        readAt: asDateOrNull(json['read_at']),
        createdAt: asDate(json['created_at']),
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'tenant_id': tenantId,
    'user_id': userId,
    'title': title,
    'body': body,
    'kind': kind,
    'reference_id': referenceId,
    'dedupe_key': dedupeKey,
    'read_at': readAt == null ? null : toIso(readAt),
    'created_at': toIso(createdAt),
  };

  AppNotification copyWith({DateTime? readAt}) => AppNotification(
    id: id,
    tenantId: tenantId,
    userId: userId,
    title: title,
    body: body,
    kind: kind,
    referenceId: referenceId,
    dedupeKey: dedupeKey,
    readAt: readAt ?? this.readAt,
    createdAt: createdAt,
  );
}
