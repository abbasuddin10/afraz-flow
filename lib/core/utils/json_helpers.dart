import 'package:intl/intl.dart';

/// Defensive JSON coercion helpers.
///
/// Supabase returns Postgres numerics as `int` or `double`, timestamps as ISO
/// strings and booleans as `bool`. Local storage round-trips through JSON so
/// every value arrives as `num`, `String`, `bool` or `null`.
String asString(dynamic value, [String fallback = '']) {
  if (value == null) return fallback;
  if (value is String) return value;
  return value.toString();
}

String? asNullableString(dynamic value) {
  final text = asString(value).trim();
  return text.isEmpty ? null : text;
}

double asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  if (value is bool) return value ? 1 : 0;
  return double.tryParse(value.toString().replaceAll(',', '')) ?? fallback;
}

int asInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value.toString()) ?? fallback;
}

bool asBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final text = value.toString().toLowerCase();
  if (text == 'true' || text == '1' || text == 't') return true;
  if (text == 'false' || text == '0' || text == 'f') return false;
  return fallback;
}

DateTime asDate(dynamic value, [DateTime? fallback]) {
  final parsed = asDateOrNull(value);
  return parsed ?? fallback ?? DateTime.now();
}

DateTime? asDateOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value.toLocal();
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}

/// Serialises a timestamp for Supabase (`timestamptz`).
String toIso(DateTime? value) =>
    (value ?? DateTime.now()).toUtc().toIso8601String();

/// Serialises a calendar date for Supabase (`date`).
String toIsoDate(DateTime value) => DateFormat('yyyy-MM-dd').format(value);
