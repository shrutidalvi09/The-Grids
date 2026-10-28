import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Indian-grouped rupee amount, e.g. `formatInr(150000)` → "₹1,50,000".
/// Paise are shown only when the amount isn't a whole number of rupees.
String formatInr(num rupees) {
  final hasPaise = rupees != rupees.truncate();
  return NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: hasPaise ? 2 : 0,
  ).format(rupees);
}

/// Amounts from the API are integer paise.
String formatPaise(int paise) => formatInr(paise / 100);

String _locale(BuildContext context) => Localizations.localeOf(context).toLanguageTag();

/// "5:30 PM" (or the locale's equivalent).
String formatTime(BuildContext context, DateTime time) => DateFormat.jm(_locale(context)).format(time);

/// "27 Oct 2026".
String formatDate(BuildContext context, DateTime date) => DateFormat.yMMMd(_locale(context)).format(date);

/// "Tue, 27 Oct".
String formatDayShort(BuildContext context, DateTime date) => DateFormat.MMMEd(_locale(context)).format(date);

/// "27 Oct".
String formatDayMonth(BuildContext context, DateTime date) => DateFormat.MMMd(_locale(context)).format(date);

/// "5:00 PM – 6:00 PM".
String formatTimeRange(BuildContext context, DateTime start, DateTime end) =>
    '${formatTime(context, start)} – ${formatTime(context, end)}';

bool isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// "AK" for "Asha Kulkarni", "R" for "Riya".
String initialsOf(String name) {
  final parts = name.replaceAll(RegExp(r'^(Dr|Mr|Mrs|Ms)\.?\s+'), '').trim().split(RegExp(r'\s+'));
  final letters = parts.where((p) => p.isNotEmpty).take(2).map((p) => p.characters.first.toUpperCase());
  return letters.join();
}

/// "+91 98765 43210" from E.164 "+919876543210"; other numbers unchanged.
String formatPhone(String e164) {
  final match = RegExp(r'^\+91(\d{5})(\d{5})$').firstMatch(e164);
  return match == null ? e164 : '+91 ${match[1]} ${match[2]}';
}
