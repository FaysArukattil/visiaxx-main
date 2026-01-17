import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:visiaxx/core/services/notification_service.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'package:visiaxx/core/widgets/network_indicator_widget.dart';
import 'package:visiaxx/features/eye_care_tips/screens/eye_care_tips_screen.dart';
import 'package:visiaxx/features/eye_exercises/screens/eye_exercise_reels_screen.dart';
import 'package:visiaxx/features/home/screens/settings_screen.dart';
import 'package:visiaxx/features/results/screens/speech_log_viewer_screen.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splashscreen.dart';
import 'features/auth/screens/loginscreen.dart';
import 'features/auth/screens/registration_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/quick_vision_test/screens/profile_selection_screen.dart';
import 'features/quick_vision_test/screens/questionnaire_screen.dart';
import 'features/quick_vision_test/screens/test_instructions_screen.dart';
import 'features/quick_vision_test/screens/visual_acuity_test_screen.dart';
import 'features/individual_tests/screens/standalone_visual_acuity_screen.dart';
import 'features/individual_tests/screens/standalone_color_vision_screen.dart';
import 'features/individual_tests/screens/individual_tests_screen.dart';
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
import 'features/quick_vision_test/screens/reading_test_instructions_screen.dart';
import 'features/quick_vision_test/screens/short_distance_test_screen.dart';
import 'features/quick_vision_test/screens/short_distance_quick_result_screen.dart';
import 'features/comprehensive_test/screens/pelli_robson_test_screen.dart';
import 'features/comprehensive_test/screens/comprehensive_intro_screen.dart';
import 'features/quick_vision_test/screens/quick_test_intro_screen.dart';
import 'features/comprehensive_test/screens/mobile_refractometry_test_screen.dart';
import 'features/comprehensive_test/screens/comprehensive_result_screen.dart';
import 'features/comprehensive_test/screens/mobile_refractometry_quick_result_screen.dart';
import 'features/individual_tests/screens/standalone_amsler_grid_screen.dart';
import 'features/individual_tests/screens/standalone_reading_test_screen.dart';
import 'features/individual_tests/screens/standalone_contrast_sensitivity_screen.dart';
import 'features/individual_tests/screens/standalone_mobile_refractometry_screen.dart';

// Providers
import 'data/providers/test_session_provider.dart';
import 'data/providers/eye_exercise_provider.dart';
import 'data/providers/locale_provider.dart';
import 'core/providers/network_connectivity_provider.dart';

// AWS Credentials Manager
import 'core/services/aws_credentials_manager.dart';
import 'core/services/session_monitor_service.dart';

import 'core/constants/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI FIRST
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Set orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore persistence explicitly
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  await AppLogger.initialize();
  await NotificationService().initialize();

  // Initialize AWS credentials from Firebase Remote Config
  debugPrint('[VisiAxx] ”„ Loading AWS credentials...');
  final awsInitialized = await AWSCredentials.initialize();
  if (awsInitialized) {
    debugPrint('[VisiAxx] … AWS credentials loaded successfully');
  } else {
    debugPrint(
      '[VisiAxx]  ï¸ AWS credentials failed to load - will use Firebase only',
    );
  }

  runApp(const VisiaxApp());
}

class VisiaxApp extends StatefulWidget {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  const VisiaxApp({super.key});

  @override
  State<VisiaxApp> createState() => _VisiaxAppState();
}

class _VisiaxAppState extends State<VisiaxApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Preload animation in background after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadEyeAnimation();
    });
  }

  void _preloadEyeAnimation() {
    // Create an invisible overlay to preload the animation
    final overlay = OverlayEntry(
      builder: (context) => const Positioned(
        left: -1000, // Off-screen
        top: -1000,
        child: SizedBox(width: 1, height: 1, child: EyeLoader(size: 1)),
      ),
    );

    // Add overlay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final overlayState = Overlay.of(context);
        overlayState.insert(overlay);

        // Remove after animation is cached (500ms should be enough)
        Future.delayed(const Duration(milliseconds: 500), () {
          overlay.remove();
          debugPrint('[VisiAxx] … Eye animation preloaded');
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SessionMonitorService().stopMonitoring();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Update last active when user returns to app
      SessionMonitorService().updateLastActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NetworkConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => TestSessionProvider()),
        ChangeNotifierProvider(create: (_) => EyeExerciseProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        navigatorKey: VisiaxApp.navigatorKey,
        title: 'Visiaxx - Digital Eye Clinic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
        initialRoute: '/',
        builder: (context, child) {
          // Add network indicator to all screens
          return NetworkIndicatorWidget(
            child: child ?? const SizedBox.shrink(),
          );
        },
        routes: {
          '/': (context) => const SplashScreen(),
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegistrationScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
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
          '/practitioner-profile-selection': (context) {
            final args =
                ModalRoute.of(context)?.settings.arguments
                    as Map<String, dynamic>?;
            return PractitionerProfileSelectionScreen(
              isComprehensive: args?['comprehensive'] ?? false,
              testType: args?['testType'],
            );
          },
          '/practitioner-results': (context) =>
              const PractitionerResultsScreen(),
          '/cover-left-eye-instruction': (context) =>
              const CoverLeftEyeInstructionScreen(),
          '/cover-right-eye-instruction': (context) =>
              const CoverRightEyeInstructionScreen(),
          '/both-eyes-open-instruction': (context) =>
              const BothEyesOpenInstructionScreen(),
          '/short-distance-test': (context) => const ShortDistanceTestScreen(),
          '/short-distance-quick-result': (context) =>
              const ShortDistanceQuickResultScreen(),
          '/reading-test-instructions': (context) =>
              const ReadingTestInstructionsScreen(),
          '/comprehensive-test': (context) => const ComprehensiveIntroScreen(),
          '/pelli-robson-test': (context) => const PelliRobsonTestScreen(),
          '/eye-exercises': (context) => const EyeExerciseReelsScreen(),
          '/eye-care-tips': (context) => const EyeCareTipsScreen(),
          '/settings': (context) => const SettingsScreen(),
          '/mobile-refractometry-test': (context) =>
              const MobileRefractometryTestScreen(),
          '/comprehensive-result': (context) =>
              const ComprehensiveResultScreen(),
          '/mobile-refractometry-result': (context) =>
              const MobileRefractometryQuickResultScreen(),
          '/visual-acuity-standalone': (context) =>
              const StandaloneVisualAcuityScreen(),
          '/color-vision-standalone': (context) =>
              const StandaloneColorVisionScreen(),
          '/amsler-grid-standalone': (context) =>
              const StandaloneAmslerGridScreen(),
          '/reading-test-standalone': (context) =>
              const StandaloneReadingTestScreen(),
          '/contrast-sensitivity-standalone': (context) =>
              const StandaloneContrastSensitivityScreen(),
          '/mobile-refractometry-standalone': (context) =>
              const StandaloneMobileRefractometryScreen(),
          '/individual-tests': (context) => const IndividualTestsScreen(),
        },
      ),
    );
  }
}
