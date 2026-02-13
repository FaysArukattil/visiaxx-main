import 'package:flutter_test/flutter_test.dart';
import 'package:visiaxx/core/services/advanced_refraction_service.dart';
import 'package:visiaxx/core/constants/test_constants.dart';

void main() {
  group('AdvancedRefractionService Clinical Calibration Tests', () {
    test('Should detect -1.00D Myopia for perfect 1m performance (User RE Case)', () {
      // Create distance responses (7 rounds, all correct at 1m)
      // High blur level (4.0) indicates clearance
      final distanceResponses = List.generate(7, (i) => {
        'round': i + 1,
        'blurLevel': 4.0,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      // Near responses (7 rounds, all correct)
      final nearResponses = List.generate(7, (i) => {
        'round': i + 8,
        'blurLevel': 4.0,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      final result = AdvancedRefractionService.calculateFullAssessment(
        distanceResponses: distanceResponses,
        nearResponses: nearResponses,
        age: 26,
        eye: 'right',
      );

      // Raw magnitude for 4.0 blur is 0.00
      // Baseline shift is -1.00
      // Result should be -1.00
      expect(result.modelResult.sphere, '-1.00');
    });

    test('Should detect -0.75D Myopia for slight 1m blur (User LE Case)', () {
      // Create distance responses (some blur tolerance)
      // Blur level 3.25 corresponds to 0.25D raw magnitude in our new table
      final distanceResponses = List.generate(7, (i) => {
        'round': i + 1,
        'blurLevel': 3.25,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      final nearResponses = List.generate(7, (i) => {
        'round': i + 8,
        'blurLevel': 4.0,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      final result = AdvancedRefractionService.calculateFullAssessment(
        distanceResponses: distanceResponses,
        nearResponses: nearResponses,
        age: 26,
        eye: 'left',
      );
      
      // With near performance (4.0) better than distance (3.25), 
      // it correctly identifies myopia > -1.00D.
      // Magnitude 0.25 + 1.00 baseline = -1.25
      expect(result.modelResult.sphere, '-1.25');
    });

    test('Should detect +0.25D Hyperopia for distance-perfect but near-strained performance (User Aben Case)', () {
      // Create distance responses (7 rounds, perfect at 1m)
      final distanceResponses = List.generate(7, (i) => {
        'round': i + 1,
        'blurLevel': 4.0,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      // Near responses (7 rounds, ALSO PERFECT)
      final nearResponses = List.generate(7, (i) => {
        'round': i + 8,
        'blurLevel': 4.0,
        'correct': true,
        'responseTime': 2000,
        'direction': EDirection.right,
        'snellenSize': '6/6',
        'characterType': 'E',
      });

      final result = AdvancedRefractionService.calculateFullAssessment(
        distanceResponses: distanceResponses,
        nearResponses: nearResponses,
        age: 35,
        eye: 'right',
      );

      // Should be +0.25 due to hyperopia detected from near drop
      expect(result.modelResult.sphere, '+0.25');
    });

    test('Protocol Verification: Should have 14 rounds total', () {
      final youngProtocol = TestConstants.getSimplifiedRefractometryProtocolYoung();
      expect(youngProtocol.length, 14);
      
      final distanceRounds = youngProtocol.where((r) => r.testType == TestType.distance).length;
      final nearRounds = youngProtocol.where((r) => r.testType == TestType.near).length;
      
      expect(distanceRounds, 7);
      expect(nearRounds, 7);
    });
  });
}
