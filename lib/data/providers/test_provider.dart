// import 'package:flutter/foundation.dart';
// import '../models/test_result_model.dart';
// import '../repositories/test_result_repository.dart';

// /// Provider for managing test results
// class TestProvider with ChangeNotifier {
//   final TestResultRepository _testResultRepository;
  
//   List<TestResultModel> _testResults = [];
//   TestResultModel? _currentTestResult;
//   bool _isLoading = false;
//   String? _errorMessage;

//   TestProvider(this._testResultRepository);

//   // Getters
//   List<TestResultModel> get testResults => _testResults;
//   TestResultModel? get currentTestResult => _currentTestResult;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;

//   /// Save test result
//   Future<bool> saveTestResult(TestResultModel testResult) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       final savedResult = await _testResultRepository.saveTestResult(testResult);
//       _testResults.insert(0, savedResult);
//       _currentTestResult = savedResult;
//       _isLoading = false;
//       notifyListeners();
//       return true;
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//       return false;
//     }
//   }

//   /// Fetch all test results for a patient
//   Future<void> fetchTestResultsByPatient(String patientId) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _testResults = await _testResultRepository.getTestResultsByPatient(patientId);
//       _isLoading = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Fetch test result by ID
//   Future<void> fetchTestResultById(String id) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _currentTestResult = await _testResultRepository.getTestResultById(id);
//       _isLoading = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Set current test result
//   void setCurrentTestResult(TestResultModel testResult) {
//     _currentTestResult = testResult;
//     notifyListeners();
//   }

//   /// Clear current test result
//   void clearCurrentTestResult() {
//     _currentTestResult = null;
//     notifyListeners();
//   }

//   /// Clear all test results
//   void clearTestResults() {
//     _testResults = [];
//     _currentTestResult = null;
//     notifyListeners();
//   }

//   /// Clear error message
//   void clearError() {
//     _errorMessage = null;
//     notifyListeners();
//   }
// }
