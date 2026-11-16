import 'package:afraz_flow/core/utils/formatters.dart';
import 'package:afraz_flow/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Validators', () {
    test('required rejects blank values', () {
      expect(Validators.required(null), 'This field is required');
      expect(Validators.required('   '), 'This field is required');
      expect(Validators.required('Northwind'), isNull);
    });

    test('email accepts valid addresses and rejects malformed ones', () {
      expect(Validators.email('owner@afrazflow.app'), isNull);
      expect(Validators.email('first.last+billing@shop.co'), isNull);
      expect(Validators.email(''), 'Email is required');
      expect(Validators.email('not-an-email'), 'Enter a valid email address');
      expect(Validators.email('missing@domain'), isNotNull);
    });

    test('password requires length and mixed characters', () {
      expect(Validators.password('demo1234'), isNull);
      expect(Validators.password('short1'), 'Use at least 8 characters');
      expect(
        Validators.password('onlyletters'),
        'Include at least one letter and one number',
      );
    });

    test('phone is optional when requested', () {
      expect(Validators.phone('', optional: true), isNull);
      expect(Validators.phone(''), 'Phone number is required');
      expect(Validators.phone('+92 300 1234567'), isNull);
      expect(Validators.phone('abc'), 'Enter a valid phone number');
    });

    test('amount enforces positive numbers', () {
      expect(Validators.amount('1250.50'), isNull);
      expect(Validators.amount('0'), 'Amount must be greater than zero');
      expect(Validators.amount('0', allowZero: true), isNull);
      expect(Validators.amount('-4'), 'Amount cannot be negative');
      expect(Validators.amount('abc'), 'Enter a valid number');
    });

    test('quantity respects available stock', () {
      expect(Validators.quantity('3', max: 5), isNull);
      expect(Validators.quantity('6', max: 5), 'Only 5 in stock');
      expect(Validators.quantity(''), 'Quantity is required');
    });
  });

  group('Formats', () {
    test('currency uses the tenant symbol and thousands separators', () {
      expect(Formats.currency(1234567, symbol: 'Rs'), 'Rs 1,234,567');
      expect(
        Formats.currency(1234.5, symbol: r'$', decimals: 2),
        r'$ 1,234.50',
      );
      expect(Formats.currency(-250, symbol: 'AED'), '-AED 250');
    });

    test('compact currency uses local scale suffixes', () {
      expect(Formats.compactCurrency(1500, symbol: 'Rs'), 'Rs 1.5k');
      expect(Formats.compactCurrency(250000, symbol: 'Rs'), 'Rs 2.50L');
      expect(Formats.compactCurrency(30000000, symbol: 'Rs'), 'Rs 3.00Cr');
    });

    test('initials handle single and multiple names', () {
      expect(Formats.initials('Afraz Malik'), 'AM');
      expect(Formats.initials('Northwind'), 'NO');
      expect(Formats.initials('  '), '?');
    });

    test('sku is generated from the product name', () {
      expect(Formats.sku('Blue Shirt', 7), 'BLU-0007');
      expect(Formats.sku('A', 1), 'AXX-0001');
    });

    test('parseAmount tolerates separators and blanks', () {
      expect(Formats.parseAmount(' 1,250.75 '), 1250.75);
      expect(Formats.parseAmount(null), 0);
      expect(Formats.parseAmount('oops'), 0);
    });
  });
}
