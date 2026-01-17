import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../quick_vision_test/screens/color_vision_test_screen.dart';

/// Entry point for Color Vision individual test
class StandaloneColorVisionScreen extends StatelessWidget {
  const StandaloneColorVisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TestSessionProvider>(context, listen: false);
    final authService = AuthService();

    // Initialize individual test mode - only if profile not already set (e.g., by practitioner)
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (provider.profileId.isEmpty) {
        final user = await authService.getUserData(authService.currentUserId!);
        if (user != null) {
          provider.selectSelfProfile(
            user.id,
            user.fullName,
            user.age,
            user.sex,
          );
        }
      }
      provider.startIndividualTest('color_vision');
    });

    // Navigate to the standard test - it will automatically stop after color vision
    return const ColorVisionTestScreen();
  }
}
