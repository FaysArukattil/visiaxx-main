import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../comprehensive_test/screens/pelli_robson_instructions_screen.dart';
import '../../../core/services/auth_service.dart';

class StandaloneContrastSensitivityScreen extends StatelessWidget {
  const StandaloneContrastSensitivityScreen({super.key});

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
      provider.startOrResumeTest('contrast_sensitivity');
    });

    return PelliRobsonInstructionsScreen(
      testMode: 'short',
      onContinue: () {
        Navigator.pushReplacementNamed(
          context,
          '/pelli-robson-test',
          arguments: {'showInitialInstructions': false},
        );
      },
    );
  }
}
