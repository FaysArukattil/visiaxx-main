import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
import '../../../core/services/auth_service.dart';

class StandaloneReadingTestScreen extends StatelessWidget {
  const StandaloneReadingTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TestSessionProvider>(context, listen: false);
    final authService = AuthService();

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
      provider.startIndividualTest('reading_test');
    });

    return BothEyesOpenInstructionScreen(
      onContinue: () {
        Navigator.pushReplacementNamed(context, '/short-distance-test');
      },
    );
  }
}
