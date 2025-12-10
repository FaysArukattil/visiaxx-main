// import 'package:flutter/foundation.dart';
// import '../models/user_model.dart';
// import '../repositories/auth_repository.dart';

// /// Provider for managing authentication state
// class AuthProvider with ChangeNotifier {
//   final AuthRepository _authRepository;
  
//   UserModel? _currentUser;
//   bool _isLoading = false;
//   String? _errorMessage;

//   AuthProvider(this._authRepository);

//   // Getters
//   UserModel? get currentUser => _currentUser;
//   bool get isLoading => _isLoading;
//   String? get errorMessage => _errorMessage;
//   bool get isAuthenticated => _currentUser != null;

//   /// Sign in with email and password
//   Future<bool> signIn(String email, String password) async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _currentUser = await _authRepository.signIn(email, password);
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

//   /// Sign in with Google
//   Future<bool> signInWithGoogle() async {
//     _isLoading = true;
//     _errorMessage = null;
//     notifyListeners();

//     try {
//       _currentUser = await _authRepository.signInWithGoogle();
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

//   /// Sign out
//   Future<void> signOut() async {
//     _isLoading = true;
//     notifyListeners();

//     try {
//       await _authRepository.signOut();
//       _currentUser = null;
//       _errorMessage = null;
//       _isLoading = false;
//       notifyListeners();
//     } catch (e) {
//       _errorMessage = e.toString();
//       _isLoading = false;
//       notifyListeners();
//     }
//   }

//   /// Clear error message
//   void clearError() {
//     _errorMessage = null;
//     notifyListeners();
//   }
// }
