// import 'package:flutter/foundation.dart';
// import '../models/patient_model.dart';
// import '../repositories/patient_repository.dart';

// /// Provider for managing patient data
// class PatientProvider with ChangeNotifier {
//   final PatientRepository _patientRepository;
  
//   List<PatientModel> _patients = [];
//   PatientModel? _currentPatient;
//   bool _isLoading = false;
//   String? _errorMessage;

//   PatientProvider(this._patientRepository);

//   // Getters
//   List<PatientModel> get patients => _patients;
//   PatientModel? get currentPatient => _currentPatient;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;

//   /// Add a new patient
//   Future<bool> addPatient(PatientModel patient) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       final addedPatient = await _patientRepository.addPatient(patient);
//       _patients.add(addedPatient);
//       _currentPatient = addedPatient;
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

//   /// Get all patients
//   Future<void> fetchPatients() async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _patients = await _patientRepository.getAllPatients();
//       _isLoading = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Get patient by ID
//   Future<void> fetchPatientById(String id) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _currentPatient = await _patientRepository.getPatientById(id);
//       _isLoading = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Update patient
//   Future<bool> updatePatient(PatientModel patient) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       await _patientRepository.updatePatient(patient);
//       final index = _patients.indexWhere((p) => p.id == patient.id);
//       if (index != -1) {
//         _patients[index] = patient;
//       }
//       _currentPatient = patient;
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

//   /// Set current patient
//   void setCurrentPatient(PatientModel patient) {
//     _currentPatient = patient;
//     notifyListeners();
//   }

//   /// Clear current patient
//   void clearCurrentPatient() {
//     _currentPatient = null;
//     notifyListeners();
//   }

//   /// Clear error message
//   void clearError() {
//     _errorMessage = null;
//     notifyListeners();
//   }
// }
