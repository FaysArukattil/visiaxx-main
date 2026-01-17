import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../comprehensive_test/screens/mobile_refractometry_instructions_screen.dart';
import '../../../core/services/auth_service.dart';

class StandaloneMobileRefractometryScreen extends StatelessWidget {
  const StandaloneMobileRefractometryScreen({super.key});

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
      provider.startIndividualTest('mobile_refractometry');
    });

    return MobileRefractometryInstructionsScreen(
      onContinue: () {
        Navigator.pushReplacementNamed(
          context,
          '/mobile-refractometry-test',
          arguments: {'showInitialInstructions': false},
        );
      },
    );
  }
}
