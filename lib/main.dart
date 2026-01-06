import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/features/eye_care_tips/screens/eye_care_tips_screen.dart';
import 'package:visiaxx/features/eye_exercises/screens/eye_exercise_reels_screen.dart';
import 'package:visiaxx/features/results/screens/speech_log_viewer_screen.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splashscreen.dart';
import 'features/auth/screens/loginscreen.dart';
import 'features/auth/screens/registration_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/quick_vision_test/screens/profile_selection_screen.dart';
import 'features/quick_vision_test/screens/questionnaire_screen.dart';
import 'features/quick_vision_test/screens/test_instructions_screen.dart';
import 'features/quick_vision_test/screens/visual_acuity_test_screen.dart';
import 'features/quick_vision_test/screens/color_vision_test_screen.dart';
import 'features/quick_vision_test/screens/amsler_grid_test_screen.dart';
import 'features/quick_vision_test/screens/quick_test_result_screen.dart';
import 'features/results/screens/my_results_screen.dart';
import 'features/practitioner/screens/practitioner_dashboard_screen.dart';
import 'features/practitioner/screens/practitioner_home_screen.dart';
import 'features/practitioner/screens/practitioner_profile_selection_screen.dart';
import 'features/practitioner/screens/practitioner_results_screen.dart';
import '/core/utils/app_logger.dart';
import 'features/quick_vision_test/screens/cover_left_eye_instruction_screen.dart';
import 'features/quick_vision_test/screens/cover_right_eye_instruction_screen.dart';
import 'features/quick_vision_test/screens/both_eyes_open_instruction_screen.dart';
import 'features/quick_vision_test/screens/short_distance_test_screen.dart';
import 'features/comprehensive_test/screens/pelli_robson_test_screen.dart';
import 'features/comprehensive_test/screens/comprehensive_intro_screen.dart';
import 'features/quick_vision_test/screens/quick_test_intro_screen.dart';

// Providers
import 'data/providers/test_session_provider.dart';
import 'data/providers/eye_exercise_provider.dart';

// AWS Credentials Manager
import 'core/services/aws_credentials_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI FIRST
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (keep this)
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AppLogger.initialize();

  // Initialize AWS credentials from Firebase Remote Config
  debugPrint('[VisiAxx] 🔄 Loading AWS credentials...');
  final awsInitialized = await AWSCredentials.initialize();
  if (awsInitialized) {
    debugPrint('[VisiAxx] ✅ AWS credentials loaded successfully');
  } else {
    debugPrint(
      '[VisiAxx] ⚠️ AWS credentials failed to load - will use Firebase only',
    );
  }

  runApp(const VisiaxApp());
}

class VisiaxApp extends StatelessWidget {
  const VisiaxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TestSessionProvider()),
        ChangeNotifierProvider(create: (_) => EyeExerciseProvider()),
      ],
      child: MaterialApp(
        title: 'Visiaxx - Digital Eye Clinic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/',
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/home': (context) => const HomeScreen(),
          '/quick-test': (context) => const QuickTestIntroScreen(),
          '/profile-selection': (context) => const ProfileSelectionScreen(),
          '/questionnaire': (context) => const QuestionnaireScreen(),
          '/test-instructions': (context) => const TestInstructionsScreen(),
          '/visual-acuity-test': (context) => const VisualAcuityTestScreen(),
          '/color-vision-test': (context) => const ColorVisionTestScreen(),
          '/amsler-grid-test': (context) => const AmslerGridTestScreen(),
          '/quick-test-result': (context) => const QuickTestResultScreen(),
          '/my-results': (context) => const MyResultsScreen(),
          '/speech-logs': (context) => const SpeechLogViewerScreen(),
          '/practitioner-dashboard': (context) =>
              const PractitionerDashboardScreen(),
          '/practitioner-home': (context) => const PractitionerHomeScreen(),
          '/practitioner-profile-selection': (context) =>
              const PractitionerProfileSelectionScreen(),
          '/practitioner-results': (context) =>
              const PractitionerResultsScreen(),
          '/cover-left-eye-instruction': (context) =>
              const CoverLeftEyeInstructionScreen(),
          '/cover-right-eye-instruction': (context) =>
              const CoverRightEyeInstructionScreen(),
          '/both-eyes-open-instruction': (context) =>
              const BothEyesOpenInstructionScreen(),
          '/short-distance-test': (context) => const ShortDistanceTestScreen(),
          '/comprehensive-test': (context) => const ComprehensiveIntroScreen(),
          '/pelli-robson-test': (context) => const PelliRobsonTestScreen(),
          '/eye-exercises': (context) => const EyeExerciseReelsScreen(),
          '/eye-care-tips': (context) => const EyeCareTipsScreen(),
        },
      ),
    );
  }
}
