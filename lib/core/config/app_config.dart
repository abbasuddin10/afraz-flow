import 'package:flutter/material.dart';

/// Build-time and product configuration for Afraz Flow.
///
/// Supabase credentials are injected at build time and never committed:
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
/// When they are absent the app starts in fully functional local demo mode.
class AppConfig {
  const AppConfig._();

  static const String appName = 'Afraz Flow';
  static const String packageName = 'com.afrazstudio.flow';
  static const String version = '1.0.0';
  static const String supportEmail = 'support@afrazstudio.com';

  // Values can be overridden at build time, e.g.
  //   flutter build apk --release \
  //     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
  //     --dart-define=SUPABASE_ANON_KEY=<anon-or-publishable-key>
  // The defaults below are the published project credentials. They are safe to
  // ship: RLS is the security boundary, not the anon key.
  /// Public URL of the hosted web app. Used for Supabase email-confirmation
  /// redirects (signUp emailRedirectTo) and must be allow-listed in the
  /// Supabase Dashboard (Authentication → URL Configuration).
  ///
  /// Override at build time:
  ///   --dart-define=APP_URL=https://your-user.github.io/afraz-flow/
  static const String appUrl = String.fromEnvironment(
    'APP_URL',
    defaultValue: 'https://abbasuddin10.github.io/afraz-flow/',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://jryuyaehhpfbxpvrzdeg.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_3aj1fk_0taF5ZmUUzEDqqg_WcvRDAd6',
  );

  static bool get hasSupabase {
    final url = supabaseUrl.trim();
    final key = supabaseAnonKey.trim();
    return url.startsWith('https://') &&
        key.isNotEmpty &&
        !url.contains('YOUR-PROJECT');
  }

  static const String demoEmail = 'demo@afrazflow.app';
  static const String demoPassword = 'demo1234';
  static const String demoBusinessName = 'Northwind Traders';

  static const List<String> businessTypes = [
    'Retail & General Store',
    'Grocery & Supermarket',
    'Pharmacy',
    'Restaurant & Café',
    'Electronics',
    'Fashion & Apparel',
    'Wholesale & Distribution',
    'Services',
    'Other',
  ];

  static const List<String> currencies = [
    'PKR',
    'USD',
    'EUR',
    'GBP',
    'AED',
    'SAR',
    'INR',
    'BDT',
    'MYR',
    'CAD',
    'AUD',
  ];

  static const Map<String, String> currencySymbols = {
    'PKR': 'Rs',
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'AED': 'AED',
    'SAR': 'SAR',
    'INR': '₹',
    'BDT': '৳',
    'MYR': 'RM',
    'CAD': r'C$',
    'AUD': r'A$',
  };

  static String symbolFor(String currency) =>
      currencySymbols[currency] ?? currency;

  /// Languages the UI can be switched to at runtime.
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'),
    Locale('bn', 'BD'),
    Locale('hi', 'IN'),
    Locale('ur', 'PK'),
    Locale('ar', 'SA'),
    Locale('es', 'ES'),
    Locale('fr', 'FR'),
    Locale('de', 'DE'),
    Locale('zh', 'CN'),
    Locale('ja', 'JP'),
  ];

  /// Common stock/sale units. Products pick their own unit from this list (or
  /// any custom value), so a single business can sell pieces, kilograms, grams,
  /// litres, etc. without one global setting.
  static const List<String> units = [
    'pcs',
    'kg',
    'g',
    'lb',
    'oz',
    'L',
    'ml',
    'box',
    'pack',
    'bag',
    'bottle',
    'can',
    'dozen',
    'bar',
    'tube',
    'meter',
    'cm',
  ];

  /// IANA timezones offered for the daily briefing schedule. Keeping a curated
  /// list avoids a platform-specific timezone database dependency while still
  /// covering the regions Afraz Flow businesses operate in.
  static const List<String> briefingTimezones = [
    'Asia/Karachi',
    'Asia/Dhaka',
    'Asia/Kolkata',
    'Asia/Dubai',
    'Asia/Riyadh',
    'Asia/Kuala_Lumpur',
    'Asia/Jakarta',
    'Asia/Singapore',
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/Istanbul',
    'Africa/Cairo',
    'America/New_York',
    'America/Chicago',
    'America/Los_Angeles',
    'America/Toronto',
    'America/Sao_Paulo',
    'Australia/Sydney',
    'UTC',
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'bn': 'বাংলা (Bangla)',
    'hi': 'हिन्दी (Hindi)',
    'ur': 'اردو (Urdu)',
    'ar': 'العربية (Arabic)',
    'es': 'Español (Spanish)',
    'fr': 'Français (French)',
    'de': 'Deutsch (German)',
    'zh': '中文 (Chinese)',
    'ja': '日本語 (Japanese)',
  };

  static String languageName(Locale locale) =>
      languageNames[locale.languageCode] ?? locale.languageCode;
}
