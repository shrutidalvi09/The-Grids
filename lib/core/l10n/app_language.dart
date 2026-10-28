import 'package:flutter/widgets.dart';

/// The languages the app ships with, shown by their native names so people
/// can find their own language whatever the current UI language is.
enum AppLanguage {
  english('en', 'English', 'English'),
  hindi('hi', 'हिन्दी', 'Hindi'),
  gujarati('gu', 'ગુજરાતી', 'Gujarati'),
  marathi('mr', 'मराठी', 'Marathi'),
  tamil('ta', 'தமிழ்', 'Tamil'),
  telugu('te', 'తెలుగు', 'Telugu'),
  kannada('kn', 'ಕನ್ನಡ', 'Kannada'),
  bengali('bn', 'বাংলা', 'Bengali');

  const AppLanguage(this.code, this.nativeName, this.englishName);

  final String code;
  final String nativeName;
  final String englishName;

  Locale get locale => Locale(code);

  static AppLanguage? fromCode(String? code) {
    for (final language in values) {
      if (language.code == code) return language;
    }
    return null;
  }
}
