import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/l10n/l10n.dart';
import 'package:the_grids/core/utils/formatters.dart';
import 'package:the_grids/core/utils/validators.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final validators = Validators(l10n);

  group('normalizeIndianMobile', () {
    test('accepts common Indian formats', () {
      for (final input in [
        '9876543210',
        '98765 43210',
        '+91 98765-43210',
        '+919876543210',
        '919876543210',
        '09876543210',
        '(98765) 43210',
      ]) {
        expect(Validators.normalizeIndianMobile(input), '+919876543210', reason: input);
      }
    });

    test('rejects non-mobile or malformed numbers', () {
      for (final input in ['5876543210', '987654321', '98765432100', 'abcdefghij', '+1 9876543210', '']) {
        expect(Validators.normalizeIndianMobile(input), isNull, reason: input);
      }
    });
  });

  group('validators', () {
    test('required', () {
      expect(validators.required(null), l10n.validationRequired);
      expect(validators.required('   '), l10n.validationRequired);
      expect(validators.required('Lift'), isNull);
    });

    test('indianMobile', () {
      expect(validators.indianMobile(''), l10n.validationRequired);
      expect(validators.indianMobile('12345'), l10n.validationPhone);
      expect(validators.indianMobile('+91 98765 43210'), isNull);
    });

    test('amount', () {
      expect(validators.amount(''), l10n.validationRequired);
      expect(validators.amount('2500'), isNull);
      expect(validators.amount('₹2,500.50'), isNull);
      expect(validators.amount('0'), l10n.validationAmount);
      expect(validators.amount('-5'), l10n.validationAmount);
      expect(validators.amount('12.345'), l10n.validationAmount);
      expect(validators.amount('abc'), l10n.validationAmount);
      expect(validators.amount('100000001'), l10n.validationAmount);
    });
  });

  group('formatInr', () {
    test('uses Indian digit grouping and drops zero paise', () {
      expect(formatInr(2500), '₹2,500');
      expect(formatInr(150000), '₹1,50,000');
      expect(formatInr(1234.5), '₹1,234.50');
    });
  });
}
