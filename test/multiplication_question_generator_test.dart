import 'package:flutter_test/flutter_test.dart';
import 'package:hoczita_app/features/game/utils/multiplication_question_generator.dart';

void main() {
  group('MultiplicationQuestionGenerator Tests', () {
    test('Easy mode generates 10 questions with format a x b = ?', () {
      final questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 3,
        level: MultiplicationLevel.easy,
      );

      expect(questions.length, 10);
      for (final q in questions) {
        expect(q.level, MultiplicationLevel.easy);
        expect(q.factorA, 3);
        expect(q.correctResult, q.factorA * q.factorB);
        expect(q.questionText, '${q.factorA} × ${q.factorB} = ?');
        expect(q.options.length, 4);
        expect(q.options.map((o) => o.value), contains(q.correctResult));
      }
    });

    test('Medium mode generates 10 fill-in-the-blank questions', () {
      final questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 5,
        level: MultiplicationLevel.medium,
      );

      expect(questions.length, 10);
      for (final q in questions) {
        expect(q.level, MultiplicationLevel.medium);
        expect(q.options.length, 4);
        // Correct result should be either factorA or factorB
        expect(q.correctResult == q.factorA || q.correctResult == q.factorB, isTrue);
        expect(q.options.map((o) => o.value), contains(q.correctResult));
      }
    });

    test('Hard mode generates rich real-world word problems', () {
      final questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 4,
        level: MultiplicationLevel.hard,
      );

      expect(questions.length, 10);
      for (final q in questions) {
        expect(q.level, MultiplicationLevel.hard);
        expect(q.options.length, 4);
        expect(q.questionText.isNotEmpty, isTrue);
        expect(q.correctDisplay.isNotEmpty, isTrue);
        expect(q.ttsPrompt.isNotEmpty, isTrue);
        expect(q.options.map((o) => o.value), contains(q.correctResult));
      }
    });

    test('Mixed table (tableNumber: 0) uses tables from 2 to 9', () {
      final questions = MultiplicationQuestionGenerator.generateQuestions(
        tableNumber: 0,
        level: MultiplicationLevel.easy,
      );

      expect(questions.length, 10);
      for (final q in questions) {
        expect(q.factorA, inInclusiveRange(2, 9));
        expect(q.factorB, inInclusiveRange(1, 10));
      }
    });
  });
}
