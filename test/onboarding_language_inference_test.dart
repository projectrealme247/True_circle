import 'package:flutter_test/flutter_test.dart';
import 'package:true_circle/utils/onboarding_language_inference.dart';

void main() {
  group('fluentCompanionsFor', () {
    test('Bengali infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Bengali'),
        ['English', 'Hindi', 'Assamese'],
      );
    });

    test('Telugu infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Telugu'),
        ['English', 'Tamil', 'Hindi', 'Malayalam'],
      );
    });

    test('Hindi infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Hindi'),
        ['English', 'Urdu', 'Punjabi', 'Gujarati'],
      );
    });

    test('Spanish infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Spanish'),
        ['English', 'Portuguese', 'Italian', 'French'],
      );
    });

    test('Portuguese infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Portuguese'),
        ['English', 'Spanish', 'Italian'],
      );
    });

    test('French infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('French'),
        ['English', 'Spanish', 'Italian', 'German'],
      );
    });

    test('Ukrainian infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Ukrainian'),
        ['English', 'Russian', 'Polish'],
      );
    });

    test('Polish infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Polish'),
        ['English', 'Ukrainian', 'Russian', 'Czech'],
      );
    });

    test('Mandarin alias infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Mandarin'),
        ['English', 'Chinese (Cantonese)', 'Japanese'],
      );
    });

    test('Cantonese alias infers English first, then proximity cluster', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Cantonese'),
        ['English', 'Chinese (Mandarin)'],
      );
    });

    test('unmapped primary still infers English only', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('Arabic'),
        ['English'],
      );
    });

    test('English primary keeps English in fluent state list', () {
      expect(
        OnboardingLanguageInference.fluentCompanionsFor('English'),
        ['English'],
      );
    });
  });

  group('suggestedLanguagesFor', () {
    test('Tamil suggests Irish South Asian companion cluster', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Tamil'),
        ['English', 'Malayalam', 'Telugu', 'Kannada', 'Hindi'],
      );
    });

    test('Polish suggests Eastern European companions', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Polish'),
        ['English', 'Ukrainian', 'Russian'],
      );
    });

    test('unknown primary falls back to English only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Swahili'),
        ['English'],
      );
    });
  });

  group('withEnglishFoundation', () {
    test('adds English when absent', () {
      expect(
        OnboardingLanguageInference.withEnglishFoundation(['Bengali', 'Hindi']),
        ['Bengali', 'Hindi', 'English'],
      );
    });

    test('does not duplicate English', () {
      expect(
        OnboardingLanguageInference.withEnglishFoundation([
          'English',
          'Bengali',
        ]),
        ['English', 'Bengali'],
      );
    });
  });
}
