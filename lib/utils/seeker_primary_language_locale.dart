import 'package:flutter/material.dart';

import 'ireland_language_catalog.dart';

/// Maps device/browser locale to catalog language names for seeker Tier A.
abstract final class SeekerPrimaryLanguageLocale {
  static String? fromLocale(Locale? locale) {
    if (locale == null) return null;
    final code = locale.languageCode.toLowerCase();

    final mapped = switch (code) {
      'en' => 'English',
      'es' => 'Spanish',
      'pt' => 'Portuguese',
      'ga' => 'Gaeilge',
      'pl' => 'Polish',
      'ro' => 'Romanian',
      'lt' => 'Lithuanian',
      'lv' => 'Latvian',
      'fr' => 'French',
      'de' => 'German',
      'it' => 'Italian',
      'ar' => 'Arabic',
      'ur' => 'Urdu',
      'hi' => 'Hindi',
      'te' => 'Telugu',
      'ta' => 'Tamil',
      'ml' => 'Malayalam',
      'bn' => 'Bengali',
      'pa' => 'Punjabi',
      'gu' => 'Gujarati',
      'kn' => 'Kannada',
      'mr' => 'Marathi',
      'zh' => 'Chinese (Mandarin)',
      'ru' => 'Russian',
      'uk' => 'Ukrainian',
      'bg' => 'Bulgarian',
      'hu' => 'Hungarian',
      'cs' => 'Czech',
      'sk' => 'Slovak',
      'nl' => 'Dutch',
      'tr' => 'Turkish',
      'fil' || 'tl' => 'Filipino',
      'vi' => 'Vietnamese',
      'th' => 'Thai',
      'ja' => 'Japanese',
      'ko' => 'Korean',
      'so' => 'Somali',
      'sw' => 'Swahili',
      'yo' => 'Yoruba',
      'ig' => 'Igbo',
      'am' => 'Amharic',
      'fa' => 'Persian',
      'ps' => 'Pashto',
      'bs' => 'Bosnian',
      'hr' => 'Croatian',
      'sr' => 'Serbian',
      'sq' => 'Albanian',
      'el' => 'Greek',
      'he' => 'Hebrew',
      'ne' => 'Nepali',
      'si' => 'Sinhala',
      _ => null,
    };

    if (mapped == null || !IrelandLanguageCatalog.all.contains(mapped)) {
      return null;
    }
    return mapped;
  }
}
