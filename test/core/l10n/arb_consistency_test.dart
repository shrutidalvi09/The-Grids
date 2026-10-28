import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:the_grids/core/l10n/app_language.dart';
import 'package:the_grids/core/l10n/l10n.dart';

/// Keeps every translation in step with the English template.
void main() {
  Map<String, dynamic> readArb(String code) => jsonDecode(
        File('lib/l10n/app_$code.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  final template = readArb('en');

  test('every app language has a generated locale', () {
    final supported = AppLocalizations.supportedLocales.map((l) => l.languageCode).toSet();
    expect(supported, AppLanguage.values.map((l) => l.code).toSet());
  });

  for (final language in AppLanguage.values.where((l) => l != AppLanguage.english)) {
    test('${language.englishName} has exactly the English keys', () {
      final arb = readArb(language.code);
      expect(messageKeys(arb), messageKeys(template));
    });

    test('${language.englishName} keeps every placeholder', () {
      final arb = readArb(language.code);
      final placeholder = RegExp(r'\{(\w+)[,}]');
      for (final key in messageKeys(template)) {
        final expected = placeholder.allMatches(template[key] as String).map((m) => m[1]).toSet();
        final actual = placeholder.allMatches(arb[key] as String).map((m) => m[1]).toSet();
        expect(actual, expected, reason: '${language.code}.$key');
      }
    });
  }

  test('brand name is never translated', () {
    for (final language in AppLanguage.values) {
      expect(readArb(language.code)['appTitle'], 'The Grids', reason: language.code);
    }
  });
}
