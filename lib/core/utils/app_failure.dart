import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-presentable failure. Every repository/controller boundary converts
/// low-level exceptions into an [AppFailure] so the UI never leaks stack traces.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code, this.isNetwork = false});

  final String message;
  final String? code;
  final bool isNetwork;

  /// Maps SDK/plugin exceptions to friendly copy.
  factory AppFailure.from(Object error, [StackTrace? stackTrace]) {
    if (error is AppFailure) return error;
    if (error is AuthException) {
      return AppFailure(
        _authMessage(error),
        code: error.statusCode,
        isNetwork: error.statusCode == null,
      );
    }
    if (error is PostgrestException) {
      final code = error.code;
      if (code == '23505') {
        return AppFailure(
          'That record already exists. Try a different name, SKU or barcode.',
          code: code,
        );
      }
      if (code == '23503') {
        return AppFailure(
          'This record is referenced elsewhere and cannot be changed.',
          code: code,
        );
      }
      if (code == '42501' || code == '42P01' || code == 'PGRST301') {
        return AppFailure(
          'You do not have permission to perform this action.',
          code: code,
        );
      }
      return AppFailure(error.message, code: code);
    }
    final text = error.toString();
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('ClientException') ||
        text.contains('Connection refused')) {
      return const AppFailure(
        'No connection. Check your internet and try again.',
        isNetwork: true,
      );
    }
    if (text.contains('MissingPluginException')) {
      return const AppFailure(
        'This feature is not available on this platform.',
      );
    }
    return AppFailure(text.replaceFirst('Exception: ', ''));
  }

  static String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (message.contains('email not confirmed')) {
      return 'Please confirm your email address, then sign in.';
    }
    if (message.contains('user already registered')) {
      return 'An account with this email already exists.';
    }
    if (message.contains('password should be at least')) {
      return 'Password is too short. Use at least 8 characters.';
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (message.contains('signups not allowed')) {
      return 'New registrations are disabled for this project.';
    }
    return error.message;
  }

  @override
  String toString() => message;
}

/// Thrown when Supabase Auth created the account but requires the user to
/// confirm their email before a session is issued. The organization is created
/// automatically on the first successful sign-in.
class ConfirmationRequired implements Exception {
  const ConfirmationRequired(this.email);

  final String email;

  @override
  String toString() =>
      'Account created. Check your inbox to confirm your email, then sign in.';
}
