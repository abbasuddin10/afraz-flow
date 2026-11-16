import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Presentation-level formatting helpers. Money is formatted manually so a
/// tenant's configured symbol is always honoured across every platform locale.
class Formats {
  const Formats._();

  static final Random _random = Random();

  /// Active UI locale used for number/date formatting. Defaults to English
  /// (US) and is updated by [LanguageController] whenever the user switches
  /// language so that formatted values follow the selected language.
  static Locale locale = const Locale('en', 'US');

  static void setLocale(Locale value) {
    locale = value;
    try {
      initializeDateFormatting(_localeTag(value));
    } catch (_) {
      // Fall back to the previous symbols if a locale is not bundled.
    }
  }

  static String _localeTag(Locale value) {
    final country = value.countryCode;
    if (country == null || country.isEmpty) return value.languageCode;
    return '${value.languageCode}_$country';
  }

  static String get _localeName => _localeTag(locale);

  static String currency(
    num? value, {
    String symbol = 'Rs',
    int decimals = 0,
  }) {
    final amount = value ?? 0;
    final pattern = decimals > 0
        ? '#,##0.${'0' * decimals}'
        : '#,##0';
    final formatted = NumberFormat(pattern, _localeName).format(amount.abs());
    final sign = amount < 0 ? '-' : '';
    return '$sign$symbol $formatted';
  }

  /// Short scale label (1.2k, 2.50L, 3.00Cr). Reserved for tight chart scales —
  /// user-facing money should use [currency] so no digits are hidden.
  static String compactCurrency(num? value, {String symbol = 'Rs'}) {
    final amount = value ?? 0;
    final abs = amount.abs();
    final sign = amount < 0 ? '-' : '';
    if (abs >= 10000000) {
      return '$sign$symbol ${(abs / 10000000).toStringAsFixed(2)}Cr';
    }
    if (abs >= 100000) {
      return '$sign$symbol ${(abs / 100000).toStringAsFixed(2)}L';
    }
    if (abs >= 1000) {
      return '$sign$symbol ${(abs / 1000).toStringAsFixed(1)}k';
    }
    return '$sign$symbol ${NumberFormat('#,##0', _localeName).format(abs)}';
  }

  static String number(num? value, {int decimals = 0}) {
    final amount = value ?? 0;
    final pattern = decimals > 0 ? '#,##0.${'0' * decimals}' : '#,##0';
    return NumberFormat(pattern, _localeName).format(amount);
  }

  static String percent(num? value, {int decimals = 1}) =>
      '${(value ?? 0).toStringAsFixed(decimals)}%';

  static String date(DateTime? value) =>
      value == null ? '—' : DateFormat('dd MMM yyyy', _localeName).format(value);

  static String shortDate(DateTime? value) =>
      value == null ? '—' : DateFormat('dd MMM', _localeName).format(value);

  static String dateTime(DateTime? value) =>
      value == null ? '—' : DateFormat('dd MMM yyyy · hh:mm a', _localeName).format(value);

  static String time(DateTime? value) =>
      value == null ? '—' : DateFormat('hh:mm a', _localeName).format(value);

  static String dayLabel(DateTime value) =>
      DateFormat('EEE', _localeName).format(value);

  static String monthYear(DateTime value) =>
      DateFormat('MMMM yyyy', _localeName).format(value);

  static String relative(DateTime? value) {
    if (value == null) return '—';
    final now = DateTime.now();
    final diff = now.difference(value);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(value);
  }

  static double parseAmount(String? text) {
    if (text == null) return 0;
    return double.tryParse(text.replaceAll(',', '').trim()) ?? 0;
  }

  static String initials(String? name) {
    final parts = (name ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final value = parts.first;
      return value.length == 1
          ? value.toUpperCase()
          : value.substring(0, 2).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  /// Human-readable but collision-resistant. Invoice numbers are unique per
  /// tenant in the database, so two checkouts in the same second must not
  /// produce the same value: the timestamp is combined with a microsecond
  /// component and a random suffix.
  static String invoiceNumber(DateTime now, {int sequence = 0}) {
    final stamp = DateFormat('yyyyMMdd-HHmmss', _localeName).format(now);
    final unique = _uniqueSuffix(now);
    if (sequence <= 0) return 'INV-$stamp-$unique';
    return 'INV-$stamp-${sequence.toString().padLeft(2, '0')}-$unique';
  }

  static String orderNumber(DateTime now) =>
      'AF-${DateFormat('yyMMdd', _localeName).format(now)}-${_uniqueSuffix(now)}';

  static String _uniqueSuffix(DateTime now) {
    final micros = (now.microsecondsSinceEpoch % 46656)
        .toRadixString(36)
        .padLeft(3, '0');
    final random = _random.nextInt(46656).toRadixString(36).padLeft(3, '0');
    return '$micros$random';
  }

  static String sku(String name, int sequence) {
    final prefix = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(3, 'X')
        .substring(0, 3);
    return '$prefix-${sequence.toString().padLeft(4, '0')}';
  }

  static String fileStamp(DateTime now) =>
      DateFormat('yyyyMMdd-HHmmss', _localeName).format(now);
}
