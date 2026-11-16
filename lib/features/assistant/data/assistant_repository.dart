import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/app_services.dart';
import '../../../core/utils/app_failure.dart';
import '../../../core/utils/formatters.dart';
import 'assistant_models.dart';

/// Talks to the `ai-assistant` Edge Function.
///
/// Gemini and the database credentials live entirely on the server. The client
/// only sends the question (plus a little context) and receives an answer, the
/// generated read-only SQL and the rows it produced.
class AssistantRepository {
  AssistantRepository(this._session, {SupabaseClient? client})
    : _client = client;

  final SessionService _session;
  final SupabaseClient? _client;

  bool get isAvailable => !_session.isDemo && _client != null;

  Future<AssistantReply> ask(
    String question, {
    List<AssistantTurn> history = const [],
  }) async {
    if (!isAvailable) {
      throw const AppFailure(
        'The AI assistant needs a cloud workspace. Sign in to Supabase and '
        'deploy the ai-assistant function to use it.',
      );
    }
    final client = _client!;
    final tenantId = _session.requireTenantId();
    final now = DateTime.now();

    try {
      final response = await client.functions.invoke(
        'ai-assistant',
        body: {
          'tenant_id': tenantId,
          'message': question,
          'history': history.map((turn) => turn.toJson()).toList(),
          'today': _dateOnly(now),
          'timezone': now.timeZoneName,
          'utc_offset_minutes': now.timeZoneOffset.inMinutes,
          'locale': Formats.locale.toLanguageTag(),
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw AppFailure(
          _functionError(response.data, response.status),
        );
      }

      final data = _decode(response.data);
      if (data['error'] != null) {
        throw AppFailure(_functionError(data, response.status));
      }
      return AssistantReply.fromJson(data);
    } on FunctionException catch (error) {
      throw AppFailure(_functionError(error.details, error.status));
    } on AppFailure {
      rethrow;
    } catch (error) {
      throw AppFailure.from(error);
    }
  }

  static String _dateOnly(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Map<String, dynamic> _decode(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const AppFailure('The assistant returned an unexpected response.');
  }

  String _functionError(dynamic details, int status) {
    dynamic data = details;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        // Keep the raw string below.
      }
    }
    if (data is Map) {
      final error = data['error']?.toString().trim() ?? '';
      final detail = data['detail']?.toString().trim() ?? '';
      if (error.isNotEmpty) {
        return detail.isEmpty ? error : '$error\n$detail';
      }
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return 'The assistant could not respond ($status). '
        'Make sure the ai-assistant Edge Function is deployed.';
  }
}
