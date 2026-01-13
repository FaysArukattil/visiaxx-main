// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:visiaxx/data/models/mobile_refractometry_result.dart';
import '../../data/models/family_member_model.dart';
import '../../data/models/patient_model.dart';
import '../../data/models/questionnaire_model.dart';
import '../../data/models/visiual_acuity_result.dart';
import '../../data/models/color_vision_result.dart';
import '../../data/models/amsler_grid_result.dart';
import '../../data/models/test_result_model.dart';
import '../../data/models/pelli_robson_result.dart';
import '../models/short_distance_result.dart';

/// Provider for managing test session state
class TestSessionProvider extends ChangeNotifier {
  // Profile selection
  String _profileType = 'self'; // 'self', 'family', or 'patient'
  String _profileId = '';
  String _profileName = '';
  int? _profileAge;
  String? _profileSex;
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
  PelliRobsonResult? _pelliRobson;
  MobileRefractometryResult? _mobileRefractometry;

  // Current test state
  String _currentEye = 'right';
  bool _isTestInProgress = false;
  DateTime? _testStartTime;

  // Comprehensive test mode flag
  bool _isComprehensiveTest = false;

  bool _shouldShowReviewDialog = false;

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
  PelliRobsonResult? get pelliRobson => _pelliRobson;
  MobileRefractometryResult? get mobileRefractometry => _mobileRefractometry;
  int? get profileAge => _profileAge;
  bool get isComprehensiveTest => _isComprehensiveTest;
  bool get shouldShowReviewDialog => _shouldShowReviewDialog;
  String? get profileSex => _profileSex;

  /// Set profile for self-testing
  void selectSelfProfile(
    String userId,
    String userName, [
    int? age,
    String? sex,
  ]) {
    _profileType = 'self';
    _profileId = userId;
    _profileName = userName;
    _profileAge = age;
    _profileSex = sex;
    _selectedFamilyMember = null;
    notifyListeners();
  }

  /// Set profile for family member testing
  void selectFamilyMember(FamilyMemberModel member) {
    _profileType = 'family';
    _profileId = member.id;
    _profileName = member.firstName;
    _profileAge = member.age;
    _profileSex = member.sex;
    _selectedFamilyMember = member;
    notifyListeners();
  }

  void setShouldShowReviewDialog(bool value) {
    _shouldShowReviewDialog = value;
    notifyListeners();
  }

  /// Set profile for patient testing (practitioner mode)
  void selectPatientProfile(PatientModel patient) {
    _profileType = 'patient';
    _profileId = patient.id;
    _profileName = patient.fullName;
    _profileAge = patient.age;
    _profileSex = patient.sex;
    _selectedFamilyMember = null;
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

  /// Start a comprehensive test session
  void startComprehensiveTest() {
    _isComprehensiveTest = true;
    startTest();
  }

  /// Start a quick test session
  void startQuickTest() {
    _isComprehensiveTest = false;
    startTest();
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

  /// Set Pelli-Robson result
  void setPelliRobsonResult(PelliRobsonResult result) {
    _pelliRobson = result;
    notifyListeners();
    debugPrint(
      '✅ [TestSessionProvider] Pelli-Robson result saved: ${result.overallCategory}',
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
      pelliRobson: _pelliRobson,
      mobileRefractometry: _mobileRefractometry,
    );
  }

  /// Get recommendation text
  String getRecommendation() {
    return TestResultModel.generateRecommendation(getOverallStatus());
  }

  /// Check if all tests are complete (depends on test mode)
  bool get areAllTestsComplete {
    final quickTestsComplete =
        _visualAcuityRight != null &&
        _visualAcuityLeft != null &&
        _shortDistance != null &&
        _colorVision != null &&
        _amslerGridRight != null &&
        _amslerGridLeft != null;

    if (_isComprehensiveTest) {
      return quickTestsComplete &&
          _pelliRobson != null &&
          _mobileRefractometry != null;
    }
    return quickTestsComplete;
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

    // ✅ CRITICAL FIX: Generate unique ID based on timestamp to ensure
    // each test's Amsler images are stored separately in AWS S3
    final uniqueId = DateTime.now().millisecondsSinceEpoch.toString();

    final result = TestResultModel(
      id: uniqueId, // Unique ID for AWS S3 image naming
      userId: userId,
      profileId: _profileId,
      profileName: _profileName,
      profileAge: _profileAge,
      profileSex: _profileSex,
      profileType: _profileType,
      timestamp: DateTime.now(),
      testType: _isComprehensiveTest ? 'comprehensive' : 'quick',
      questionnaire: _questionnaire,
      visualAcuityRight: _visualAcuityRight,
      visualAcuityLeft: _visualAcuityLeft,
      shortDistance: _shortDistance,
      colorVision: _colorVision,
      amslerGridRight: _amslerGridRight,
      amslerGridLeft: _amslerGridLeft,
      pelliRobson: _pelliRobson,
      mobileRefractometry: _mobileRefractometry,
      overallStatus: getOverallStatus(),
      recommendation: getRecommendation(),
    );
    debugPrint(
      '✅ [TestSessionProvider] Built test result with ID: $uniqueId, pelli-robson: ${result.pelliRobson != null}',
    );
    return result;
  }

  /// Reset the test session
  void reset() {
    _profileType = 'self';
    _profileId = '';
    _profileName = '';
    _profileAge = null;
    _profileSex = null;
    _selectedFamilyMember = null;
    _questionnaire = null;
    resetAllResults();
    _currentEye = 'right';
    _isTestInProgress = false;
    _testStartTime = null;
    _isComprehensiveTest = false;

    notifyListeners();
  }

  void resetAllResults() {
    _visualAcuityRight = null;
    _visualAcuityLeft = null;
    _shortDistance = null;
    _colorVision = null;
    _amslerGridRight = null;
    _amslerGridLeft = null;
    _pelliRobson = null;
    _mobileRefractometry = null;
    notifyListeners();
  }

  void resetVisualAcuity() {
    _visualAcuityRight = null;
    _visualAcuityLeft = null;
    notifyListeners();
  }

  void resetVisualAcuityLeft() {
    _visualAcuityLeft = null;
    notifyListeners();
  }

  void resetAmslerGrid() {
    _amslerGridRight = null;
    _amslerGridLeft = null;
    notifyListeners();
  }

  void resetAmslerGridLeft() {
    _amslerGridLeft = null;
    notifyListeners();
  }

  void resetColorVision() {
    _colorVision = null;
    notifyListeners();
  }

  void resetShortDistance() {
    _shortDistance = null;
    notifyListeners();
  }

  void resetPelliRobson() {
    _pelliRobson = null;
    notifyListeners();
  }

  void setMobileRefractometryResult(MobileRefractometryResult result) {
    _mobileRefractometry = result;
    notifyListeners();
    debugPrint(
      '✅ [TestSessionProvider] Mobile Refractometry result saved for ${result.rightEye != null ? "right" : ""}${result.leftEye != null ? " left" : ""} eye',
    );
  }

  void resetMobileRefractometry() {
    _mobileRefractometry = null;
    notifyListeners();
  }
}
