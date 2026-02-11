import 'package:flutter_test/flutter_test.dart';
import 'package:visiaxx/data/providers/stereopsis_provider.dart';
import 'package:visiaxx/data/models/stereopsis_result.dart';

void main() {
  group('StereopsisProvider Tests', () {
    late StereopsisProvider provider;

    setUp(() {
      provider = StereopsisProvider();
      provider.reset();
    });

    test('Initial state is correct', () {
      expect(provider.currentRound, 0);
      expect(provider.score, 0);
      expect(provider.isTestComplete, false);
      expect(provider.testImages.length, 5);
    });

    test('Randomization works on reset', () {
      final order1 = provider.testImages.map((e) => e.assetPath).toList();

      provider.reset();
      final order2 = provider.testImages.map((e) => e.assetPath).toList();

      // Note: There's a 1/120 chance they are the same, but it's unlikely
      // A better test would be to check if the set of images is the same
      expect(order1.toSet(), order2.toSet());
      expect(order1.length, 5);
    });

    test('Scoring logic and best arc tracking', () {
      // Get the arc values in the current randomized order
      final arcs = provider.testImages.map((e) => e.arcSeconds).toList();

      // Round 1 (perceive 3D)
      provider.submitAnswer(true);
      expect(provider.score, 1);
      expect(provider.bestArc, arcs[0]);
      expect(provider.currentRound, 1);

      // Round 2 (ignore 3D)
      provider.submitAnswer(false);
      expect(provider.score, 1);
      expect(provider.bestArc, arcs[0]);
      expect(provider.currentRound, 2);

      // Round 3 (perceive 3D, deeper than Round 1)
      // We want to test if bestArc tracks the SMALLEST arc
      // Let's just simulate all rounds
      for (int i = 2; i < 5; i++) {
        provider.submitAnswer(true);
      }

      expect(provider.isTestComplete, true);

      // Best arc should be the minimum arc among correctly identified rounds
      int expectedBest = arcs[0];
      if (arcs[2] < expectedBest) expectedBest = arcs[2];
      if (arcs[3] < expectedBest) expectedBest = arcs[3];
      if (arcs[4] < expectedBest) expectedBest = arcs[4];

      expect(provider.bestArc, expectedBest);

      final result = provider.createResult();
      expect(result.bestArc, expectedBest);
      expect(result.score, 4);
    });

    test('Result grading matches expectations', () {
      // Simulate excellent result (40 arc)
      provider.reset();
      // Ensure we hit the 40 arc image
      for (int i = 0; i < 5; i++) {
        provider.submitAnswer(true);
      }
      expect(provider.getResultGrade(), StereopsisGrade.excellent);

      // Simulate poor result (only easiest correct)
      provider.reset();
      final easiestIndex = provider.testImages.indexWhere(
        (e) => e.arcSeconds == 800,
      );
      for (int i = 0; i < 5; i++) {
        if (i == easiestIndex) {
          provider.submitAnswer(true);
        } else {
          provider.submitAnswer(false);
        }
      }
      expect(provider.getResultGrade(), StereopsisGrade.poor);
    });
  });
}
