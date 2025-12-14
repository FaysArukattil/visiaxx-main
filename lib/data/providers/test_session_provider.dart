import 'package:flutter/material.dart';
import '../../data/models/family_member_model.dart';
import '../../data/models/questionnaire_model.dart';
import '../../data/models/visiual_acuity_result.dart';
import '../../data/models/color_vision_result.dart';
import '../../data/models/amsler_grid_result.dart';
import '../../data/models/test_result_model.dart';
import '../models/short_distance_result.dart';

/// Provider for managing test session state
class TestSessionProvider extends ChangeNotifier {
  // Profile selection
  String _profileType = 'self'; // 'self' or 'family'
  String _profileId = '';
  String _profileName = '';
  FamilyMemberModel? _selectedFamilyMember;

  // Questionnaire
  QuestionnaireModel? _questionnaire;

  // Test results
  VisualAcuityResult? _visualAcuityRight;
  VisualAcuityResult? _visualAcuityLeft;
  ColorVisionResult? _colorVision;
  AmslerGridResult? _amslerGridRight;
  AmslerGridResult? _amslerGridLeft;
  ShortDistanceResult? _shortDistance;

  // Current test state
  String _currentEye = 'right';
  bool _isTestInProgress = false;
  DateTime? _testStartTime;

  // Getters
  String get profileType => _profileType;
  String get profileId => _profileId;
  String get profileName => _profileName;
  FamilyMemberModel? get selectedFamilyMember => _selectedFamilyMember;
  QuestionnaireModel? get questionnaire => _questionnaire;
  VisualAcuityResult? get visualAcuityRight => _visualAcuityRight;
  VisualAcuityResult? get visualAcuityLeft => _visualAcuityLeft;
  ColorVisionResult? get colorVision => _colorVision;
  AmslerGridResult? get amslerGridRight => _amslerGridRight;
  AmslerGridResult? get amslerGridLeft => _amslerGridLeft;
  String get currentEye => _currentEye;
  bool get isTestInProgress => _isTestInProgress;
  ShortDistanceResult? get shortDistance => _shortDistance;

  /// Set profile for self-testing
  void selectSelfProfile(String userId, String userName) {
    _profileType = 'self';
    _profileId = userId;
    _profileName = userName;
    _selectedFamilyMember = null;
    notifyListeners();
  }

  /// Set profile for family member testing
  void selectFamilyMember(FamilyMemberModel member) {
    _profileType = 'family';
    _profileId = member.id;
    _profileName = member.firstName;
    _selectedFamilyMember = member;
    notifyListeners();
  }

  /// Set questionnaire data
  void setQuestionnaire(QuestionnaireModel questionnaire) {
    _questionnaire = questionnaire;
    notifyListeners();
  }

  /// Start a new test session
  void startTest() {
    _isTestInProgress = true;
    _testStartTime = DateTime.now();
    _currentEye = 'right';
    notifyListeners();
  }

  /// Switch to testing the other eye
  void switchEye() {
    _currentEye = _currentEye == 'right' ? 'left' : 'right';
    notifyListeners();
  }

  /// Set visual acuity result for current eye
  void setVisualAcuityResult(VisualAcuityResult result) {
    if (_currentEye == 'right') {
      _visualAcuityRight = result;
    } else {
      _visualAcuityLeft = result;
    }
    notifyListeners();
  }

  /// Set color vision result
  void setColorVisionResult(ColorVisionResult result) {
    _colorVision = result;
    notifyListeners();
  }

  /// Set Amsler grid result for current eye
  void setAmslerGridResult(AmslerGridResult result) {
    if (_currentEye == 'right') {
      _amslerGridRight = result;
    } else {
      _amslerGridLeft = result;
    }
    notifyListeners();
  }

  void setShortDistanceResult(ShortDistanceResult result) {
    _shortDistance = result;
    notifyListeners();
    debugPrint(
      '✅ [TestSessionProvider] Short distance result saved: ${result.toMap()}',
    );
  }

  /// Get overall test status
  TestStatus getOverallStatus() {
    return TestResultModel.calculateOverallStatus(
      vaRight: _visualAcuityRight,
      vaLeft: _visualAcuityLeft,
      colorVision: _colorVision,
      amslerRight: _amslerGridRight,
      amslerLeft: _amslerGridLeft,
    );
  }

  /// Get recommendation text
  String getRecommendation() {
    return TestResultModel.generateRecommendation(getOverallStatus());
  }

  /// Check if all tests are complete
  bool get areAllTestsComplete {
    return _visualAcuityRight != null &&
        _visualAcuityLeft != null &&
        _shortDistance != null &&
        _colorVision != null &&
        _amslerGridRight != null &&
        _amslerGridLeft != null;
  }

  /// Get test duration in seconds
  int get testDurationSeconds {
    if (_testStartTime == null) return 0;
    return DateTime.now().difference(_testStartTime!).inSeconds;
  }

  /// Build complete test result model
  TestResultModel buildTestResult(String userId) {
    final overallStatus = getOverallStatus();
    final recommendation = getRecommendation();
    final result = TestResultModel(
      id: '', // Will be set by Firestore
      userId: userId,
      profileId: _profileId,
      profileName: _profileName,
      profileType: _profileType,
      timestamp: DateTime.now(),
      testType: 'quick',
      questionnaire: _questionnaire,
      visualAcuityRight: _visualAcuityRight,
      visualAcuityLeft: _visualAcuityLeft,
      shortDistance: _shortDistance,
      colorVision: _colorVision,
      amslerGridRight: _amslerGridRight,
      amslerGridLeft: _amslerGridLeft,
      overallStatus: getOverallStatus(),
      recommendation: getRecommendation(),
    );
    debugPrint(
      '✅ [TestSessionProvider] Built test result with short distance: ${result.shortDistance != null}',
    );
    return result;
  }

  /// Reset the test session
  void reset() {
    _profileType = 'self';
    _profileId = '';
    _profileName = '';
    _selectedFamilyMember = null;
    _questionnaire = null;
    _visualAcuityRight = null;
    _visualAcuityLeft = null;
    _shortDistance = null;
    _colorVision = null;
    _amslerGridRight = null;
    _amslerGridLeft = null;
    _currentEye = 'right';
    _isTestInProgress = false;
    _testStartTime = null;

    notifyListeners();
  }
}
