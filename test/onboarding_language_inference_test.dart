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
    test('Telugu suggests Tamil and Hindi only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Telugu'),
        ['Tamil', 'Hindi'],
      );
    });

    test('Tamil suggests Telugu and Malayalam only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Tamil'),
        ['Telugu', 'Malayalam'],
      );
    });

    test('Malayalam suggests Tamil and Telugu only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Malayalam'),
        ['Tamil', 'Telugu'],
      );
    });

    test('Kannada suggests Telugu and Tamil only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Kannada'),
        ['Telugu', 'Tamil'],
      );
    });

    test('Hindi suggests Punjabi and Urdu only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Hindi'),
        ['Punjabi', 'Urdu'],
      );
    });

    test('Portuguese suggests Spanish and French only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Portuguese'),
        ['Spanish', 'French'],
      );
    });

    test('Spanish suggests Portuguese and French only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Spanish'),
        ['Portuguese', 'French'],
      );
    });

    test('Bengali suggests Hindi and Assamese only', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Bengali'),
        ['Hindi', 'Assamese'],
      );
    });

    test('English primary returns no chip wall', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('English'),
        isEmpty,
      );
    });

    test('unknown primary returns no chip wall', () {
      expect(
        OnboardingLanguageInference.suggestedLanguagesFor('Swahili'),
        isEmpty,
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
