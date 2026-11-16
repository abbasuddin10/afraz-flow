import '../../../core/utils/json_helpers.dart';

/// One prior message sent to the assistant for conversation context.
class AssistantTurn {
  const AssistantTurn({required this.role, required this.content});

  final String role; // 'user' | 'assistant'
  final String content;

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Tabular rows returned by the read-only SQL query.
class AssistantTable {
  const AssistantTable({
    required this.columns,
    required this.rows,
    this.truncated = false,
  });

  final List<String> columns;
  final List<Map<String, dynamic>> rows;
  final bool truncated;

  bool get isEmpty => rows.isEmpty;
}

/// A complete assistant response: the conversational answer plus the exact
/// rows and SQL that produced it.
class AssistantReply {
  const AssistantReply({
    required this.answer,
    this.sql,
    this.table,
    this.followUps = const [],
    this.language,
    this.rowCount = 0,
  });

  final String answer;
  final String? sql;
  final AssistantTable? table;
  final List<String> followUps;
  final String? language;
  final int rowCount;

  factory AssistantReply.fromJson(Map<String, dynamic> json) {
    final rows = <Map<String, dynamic>>[];
    final rawRows = json['rows'];
    if (rawRows is List) {
      for (final row in rawRows) {
        if (row is Map) rows.add(Map<String, dynamic>.from(row));
      }
    }

    final rawColumns = json['columns'];
    final columns = rawColumns is List && rawColumns.isNotEmpty
        ? rawColumns.map((column) => column.toString()).toList()
        : rows.isNotEmpty
        ? rows.first.keys.toList()
        : <String>[];

    final followUps = <String>[];
    final rawFollowUps = json['follow_ups'];
    if (rawFollowUps is List) {
      for (final item in rawFollowUps) {
        final text = asString(item).trim();
        if (text.isNotEmpty) followUps.add(text);
      }
    }

    return AssistantReply(
      answer: asString(json['answer']).trim(),
      sql: asNullableString(json['sql']),
      table: rows.isEmpty
          ? null
          : AssistantTable(
              columns: columns,
              rows: rows,
              truncated: asBool(json['truncated']),
            ),
      followUps: followUps.take(3).toList(growable: false),
      language: asNullableString(json['language']),
      rowCount: asInt(json['row_count'], rows.length),
    );
  }
}

enum AssistantMessageStatus { complete, pending, failed }

/// A single bubble in the chat transcript.
class AssistantMessage {
  AssistantMessage({
    required this.id,
    required this.isUser,
    required this.text,
    required this.createdAt,
    this.reply,
    this.status = AssistantMessageStatus.complete,
    this.error,
    this.isWelcome = false,
  });

  static int _sequence = 0;

  static String _nextId() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_sequence++}';

  final String id;
  final bool isUser;
  final String text;
  final AssistantReply? reply;
  final AssistantMessageStatus status;
  final String? error;
  final bool isWelcome;
  final DateTime createdAt;

  bool get isPending => status == AssistantMessageStatus.pending;
  bool get hasFailed => status == AssistantMessageStatus.failed;

  factory AssistantMessage.intro(String text) => AssistantMessage(
    id: _nextId(),
    isUser: false,
    text: text,
    createdAt: DateTime.now(),
    isWelcome: true,
  );

  factory AssistantMessage.user(String text) => AssistantMessage(
    id: _nextId(),
    isUser: true,
    text: text,
    createdAt: DateTime.now(),
  );

  factory AssistantMessage.pending() => AssistantMessage(
    id: _nextId(),
    isUser: false,
    text: '',
    createdAt: DateTime.now(),
    status: AssistantMessageStatus.pending,
  );

  factory AssistantMessage.assistant(AssistantReply reply) => AssistantMessage(
    id: _nextId(),
    isUser: false,
    text: reply.answer,
    reply: reply,
    createdAt: DateTime.now(),
  );

  factory AssistantMessage.failure(String error) => AssistantMessage(
    id: _nextId(),
    isUser: false,
    text: '',
    error: error,
    createdAt: DateTime.now(),
    status: AssistantMessageStatus.failed,
  );
}
