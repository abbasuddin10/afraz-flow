import '../../../../core/config/app_config.dart';

class RegisterBusinessInput {
  const RegisterBusinessInput({
    required this.ownerName,
    required this.businessName,
    required this.email,
    required this.password,
    required this.phone,
    required this.businessType,
    required this.currency,
    required this.taxRate,
    required this.lowStockThreshold,
  });

  final String ownerName;
  final String businessName;
  final String email;
  final String password;
  final String phone;
  final String businessType;
  final String currency;
  final double taxRate;
  final int lowStockThreshold;

  String get currencySymbol => AppConfig.symbolFor(currency);
}
