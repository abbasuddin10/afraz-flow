/// Shared form validators used by every module.
class Validators {
  const Validators._();

  static final RegExp _email = RegExp(
    r'^[\w.!#$%&’*+/=?^`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
    r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
  );
  static final RegExp _phone = RegExp(r'^[+]?[0-9\s\-()]{7,20}$');

  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (!_email.hasMatch(text)) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? value) {
    final text = value ?? '';
    if (text.isEmpty) return 'Password is required';
    if (text.length < 8) return 'Use at least 8 characters';
    if (!text.contains(RegExp(r'[A-Za-z]')) ||
        !text.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    return null;
  }

  static String? phone(String? value, {bool optional = false}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return optional ? null : 'Phone number is required';
    if (!_phone.hasMatch(text)) return 'Enter a valid phone number';
    return null;
  }

  static String? amount(
    String? value, {
    bool allowZero = false,
    String field = 'Amount',
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$field is required';
    final parsed = double.tryParse(text.replaceAll(',', ''));
    if (parsed == null) return 'Enter a valid number';
    if (parsed < 0) return '$field cannot be negative';
    if (!allowZero && parsed == 0) return '$field must be greater than zero';
    return null;
  }

  static String? quantity(String? value, {double? max}) {
    final error = amount(value, field: 'Quantity');
    if (error != null) return error;
    final parsed = double.parse(value!.trim());
    if (max != null && parsed > max) {
      return 'Only ${max.toStringAsFixed(max % 1 == 0 ? 0 : 2)} in stock';
    }
    return null;
  }

  static String? maxLength(String? value, int max, {String field = 'Value'}) {
    if ((value ?? '').trim().length > max) {
      return '$field must be $max characters or fewer';
    }
    return null;
  }
}
