import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../../data/models/user_model.dart';

class NavigationUtils {
  static Future<void> navigateHome(BuildContext context) async {
    final role = await AuthService().getCurrentUserRole();
    if (!context.mounted) return;

    final route = role == UserRole.examiner ? '/practitioner-home' : '/home';

    Navigator.pushNamedAndRemoveUntil(context, route, (route) => false);
  }

  /// Get the home route name based on current user role
  static Future<String> getHomeRoute() async {
    final role = await AuthService().getCurrentUserRole();
    return role == UserRole.examiner ? '/practitioner-home' : '/home';
  }
}
