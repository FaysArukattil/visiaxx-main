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
import 'package:visiaxx/features/home/screens/main_navigation_screen.dart';
import 'package:visiaxx/features/home/screens/settings_screen.dart';
import 'package:visiaxx/features/practitioner/screens/practitioner_individual_tests_screen.dart';
import 'package:visiaxx/features/practitioner/screens/practitioner_main_navigation_screen.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/screens/splashscreen.dart';
import 'features/auth/screens/loginscreen.dart';
import 'features/auth/screens/registration_screen.dart';
import 'features/auth/screens/forgot_password_screen.dart';
// ignore: unused_import
import 'features/home/screens/home_screen.dart';
import 'features/quick_vision_test/screens/profile_selection_screen.dart';
import 'features/quick_vision_test/screens/questionnaire_screen.dart';
import 'features/quick_vision_test/screens/test_instructions_screen.dart';
import 'features/quick_vision_test/screens/visual_acuity_test_screen.dart';
import 'features/individual_tests/screens/standalone_visual_acuity_screen.dart';
import 'package:visiaxx/features/individual_tests/screens/standalone_color_vision_screen.dart';
import 'features/quick_vision_test/screens/color_vision_test_screen.dart';
import 'features/quick_vision_test/screens/amsler_grid_test_screen.dart';
import 'features/quick_vision_test/screens/quick_test_result_screen.dart';
import 'features/results/screens/my_results_screen.dart';
import 'features/practitioner/screens/practitioner_dashboard_screen.dart';
import 'features/practitioner/screens/practitioner_profile_selection_screen.dart';
import 'features/practitioner/screens/add_patient_questionnaire_screen.dart';
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
import 'features/individual_tests/screens/shadow_test_intro_screen.dart';
import 'features/individual_tests/screens/shadow_test_screen.dart';
import 'features/individual_tests/screens/stereopsis_test_instructions_screen.dart';
import 'features/individual_tests/screens/stereopsis_test_screen.dart';
import 'data/providers/shadow_test_provider.dart';
import 'data/providers/stereopsis_provider.dart';
import 'data/providers/eye_hydration_provider.dart';
import 'features/individual_tests/screens/eye_hydration_instructions_screen.dart';
import 'features/individual_tests/screens/eye_hydration_test_screen.dart';

// Providers
import 'data/providers/test_session_provider.dart';
import 'data/providers/eye_exercise_provider.dart';
import 'data/providers/locale_provider.dart';
import 'data/providers/family_member_provider.dart';
import 'data/providers/patient_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/network_connectivity_provider.dart';
import 'core/providers/voice_recognition_provider.dart';

// AWS Credentials Manager
import 'core/services/aws_credentials_manager.dart';
import 'core/services/session_monitor_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // main() logic...
  // Initial system UI will be handled by MaterialApp or after build

  // Set orientations
  // Set orientations - Allow all orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable Firestore persistence explicitly
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Initialize services in background to not block main thread
  AppLogger.initialize().then((_) {
    NotificationService().initialize();

    // Initialize AWS credentials in background
    debugPrint('[VisiAxx] ... Loading AWS credentials in background...');
    AWSCredentials.initialize().then((awsInitialized) {
      if (awsInitialized) {
        debugPrint('[VisiAxx] ... AWS credentials loaded successfully');
      } else {
        debugPrint(
          '[VisiAxx] AWS credentials failed to load - will use Firebase only',
        );
      }
    });
  });

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
        try {
          final overlayState = Overlay.maybeOf(context);
          if (overlayState != null) {
            overlayState.insert(overlay);

            // Remove after animation is cached (500ms should be enough)
            Future.delayed(const Duration(milliseconds: 500), () {
              overlay.remove();
              debugPrint('[VisiAxx] ... Eye animation preloaded');
            });
          }
        } catch (e) {
          debugPrint('[VisiAxx] Preload skipped: Overlay not ready');
        }
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
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => VoiceRecognitionProvider()),
        ChangeNotifierProvider(create: (_) => FamilyMemberProvider()),
        ChangeNotifierProvider(create: (_) => PatientProvider()),
        ChangeNotifierProvider(create: (_) => ShadowTestProvider()),
        ChangeNotifierProvider(create: (_) => StereopsisProvider()),
        ChangeNotifierProvider(create: (_) => EyeHydrationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: VisiaxApp.navigatorKey,
            title: 'Visiaxx - Digital Eye Clinic',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme(themeProvider.primaryColor),
            darkTheme: AppTheme.darkTheme(themeProvider.primaryColor),
            themeMode: themeProvider.themeMode,
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
              '/home': (context) => const MainNavigationScreen(),
              '/quick-test': (context) => const QuickTestIntroScreen(),
              '/profile-selection': (context) => const ProfileSelectionScreen(),
              '/questionnaire': (context) => const QuestionnaireScreen(),
              '/test-instructions': (context) => const TestInstructionsScreen(),
              '/visual-acuity-test': (context) =>
                  const VisualAcuityTestScreen(),
              '/color-vision-test': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return ColorVisionTestScreen(
                  showInitialInstructions:
                      args?['showInitialInstructions'] ?? true,
                );
              },
              '/amsler-grid-test': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return AmslerGridTestScreen(
                  showInitialInstructions:
                      args?['showInitialInstructions'] ?? true,
                );
              },
              '/quick-test-result': (context) => const QuickTestResultScreen(),
              '/my-results': (context) => const MyResultsScreen(),
              '/practitioner-dashboard': (context) =>
                  const PractitionerDashboardScreen(),
              '/practitioner-home': (context) =>
                  const PractitionerMainNavigationScreen(),
              '/practitioner-individual-tests': (context) =>
                  const IndividualTestsScreen(),
              '/practitioner-profile-selection': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return PractitionerProfileSelectionScreen(
                  isComprehensive: args?['comprehensive'] ?? false,
                  testType: args?['testType'],
                );
              },
              '/cover-left-eye-instruction': (context) =>
                  const CoverLeftEyeInstructionScreen(),
              '/cover-right-eye-instruction': (context) =>
                  const CoverRightEyeInstructionScreen(),
              '/both-eyes-open-instruction': (context) =>
                  const BothEyesOpenInstructionScreen(),
              '/short-distance-test': (context) =>
                  const ShortDistanceTestScreen(),
              '/short-distance-quick-result': (context) =>
                  const ShortDistanceQuickResultScreen(),
              '/reading-test-instructions': (context) =>
                  const ReadingTestInstructionsScreen(),
              '/comprehensive-test': (context) =>
                  const ComprehensiveIntroScreen(),
              '/pelli-robson-test': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return PelliRobsonTestScreen(
                  showInitialInstructions:
                      args?['showInitialInstructions'] ?? true,
                );
              },
              '/eye-exercises': (context) => const EyeExerciseReelsScreen(),
              '/eye-care-tips': (context) => const EyeCareTipsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/mobile-refractometry-test': (context) {
                final args =
                    ModalRoute.of(context)?.settings.arguments
                        as Map<String, dynamic>?;
                return MobileRefractometryTestScreen(
                  showInitialInstructions:
                      args?['showInitialInstructions'] ?? true,
                );
              },
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
              '/shadow-test-intro': (context) => const ShadowTestIntroScreen(),
              '/shadow-test-main': (context) => const ShadowTestScreen(),
              '/add-patient-questionnaire': (context) =>
                  const AddPatientQuestionnaireScreen(),
              '/stereopsis-test-intro': (context) =>
                  const StereopsisTestInstructionsScreen(),
              '/stereopsis-test': (context) => const StereopsisTestScreen(),
              '/eye-hydration-test-intro': (context) =>
                  const EyeHydrationInstructionsScreen(),
              '/eye-hydration-test': (context) =>
                  const EyeHydrationTestScreen(),
            },
          );
        },
      ),
    );
  }
}
