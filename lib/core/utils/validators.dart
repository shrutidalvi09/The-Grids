import '../l10n/l10n.dart';

/// Form-field validators returning a localised error, or `null` when valid.
class Validators {
  const Validators(this._l10n);

  final AppLocalizations _l10n;

  static final _indianMobile = RegExp(r'^[6-9]\d{9}$');
  static final _amount = RegExp(r'^\d+(\.\d{1,2})?$');

  /// Largest amount accepted from a form (₹1 crore).
  static const maxAmount = 10000000;

  String? required(String? value) =>
      (value == null || value.trim().isEmpty) ? _l10n.validationRequired : null;

  String? indianMobile(String? value) {
    if (value == null || value.trim().isEmpty) return _l10n.validationRequired;
    return normalizeIndianMobile(value) == null ? _l10n.validationPhone : null;
  }

  String? amount(String? value) {
    if (value == null || value.trim().isEmpty) return _l10n.validationRequired;
    final cleaned = value.replaceAll(',', '').replaceAll('₹', '').trim();
    if (!_amount.hasMatch(cleaned)) return _l10n.validationAmount;
    final parsed = double.parse(cleaned);
    if (parsed <= 0 || parsed > maxAmount) return _l10n.validationAmount;
    return null;
  }

  /// Accepts "98765 43210", "+91 98765-43210", "09876543210" etc. and returns
  /// E.164 ("+919876543210"), or `null` if it isn't an Indian mobile number.
  static String? normalizeIndianMobile(String input) {
    var digits = input.replaceAll(RegExp(r'[\s\-()]'), '');
    if (digits.startsWith('+91')) {
      digits = digits.substring(3);
    } else if (digits.length == 12 && digits.startsWith('91')) {
      digits = digits.substring(2);
    } else if (digits.length == 11 && digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return _indianMobile.hasMatch(digits) ? '+91$digits' : null;
  }
}
