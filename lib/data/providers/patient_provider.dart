import 'package:flutter/foundation.dart';
import '../../core/services/patient_service.dart';
import '../models/patient_model.dart';

/// Provider for managing patient data for practitioners with caching/background loading
class PatientProvider with ChangeNotifier {
  final PatientService _patientService = PatientService();

  List<PatientModel> _patients = [];
  PatientModel? _currentPatient;
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasInitialLoad = false;

  // Getters
  List<PatientModel> get patients => _patients;
  PatientModel? get currentPatient => _currentPatient;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasInitialLoad => _hasInitialLoad;

  /// Load patients with background refresh logic
  Future<void> fetchPatients(
    String practitionerId, {
    bool forceRefresh = false,
  }) async {
    if (_hasInitialLoad && !forceRefresh) {
      // Refresh in background if already has data
      _getBackgroundRefresh(practitionerId);
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final members = await _patientService.getPatients(practitionerId);
      _patients = members;
      _hasInitialLoad = true;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PatientProvider] ❌ Error loading patients: $e');
      _errorMessage = 'Failed to load patients. Please check your connection.';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Perform a background refresh without showing loading state
  Future<void> _getBackgroundRefresh(String practitionerId) async {
    try {
      final members = await _patientService.getPatients(practitionerId);

      // Only notify if data actually changed
      if (_hasChanges(members)) {
        _patients = members;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[PatientProvider] Background refresh error: $e');
    }
  }

  bool _hasChanges(List<PatientModel> newList) {
    if (newList.length != _patients.length) return true;
    for (int i = 0; i < newList.length; i++) {
      // Simple equality check for basic fields; could be more robust
      if (newList[i].id != _patients[i].id ||
          newList[i].firstName != _patients[i].firstName ||
          newList[i].age != _patients[i].age) {
        return true;
      }
    }
    return false;
  }

  /// Add a new patient instantly (Optimistic UI)
  void addOptimistic(PatientModel patient) {
    _patients.insert(0, patient);
    _currentPatient = patient;
    notifyListeners();
  }

  /// Update a patient instantly
  void updateOptimistic(PatientModel patient) {
    final index = _patients.indexWhere((p) => p.id == patient.id);
    if (index != -1) {
      _patients[index] = patient;
    }
    _currentPatient = patient;
    notifyListeners();
  }

  /// Remove a patient instantly
  void removeOptimistic(String id) {
    _patients.removeWhere((p) => p.id == id);
    if (_currentPatient?.id == id) _currentPatient = null;
    notifyListeners();
  }

  /// Set current patient
  void setCurrentPatient(PatientModel patient) {
    _currentPatient = patient;
    notifyListeners();
  }

  /// Clear current patient
  void clearCurrentPatient() {
    _currentPatient = null;
    notifyListeners();
  }

  /// Clear the cache on logout
  void clear() {
    _patients = [];
    _currentPatient = null;
    _hasInitialLoad = false;
    _errorMessage = null;
    notifyListeners();
  }
}
