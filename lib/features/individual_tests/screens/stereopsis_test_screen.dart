import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/stereopsis_provider.dart';
import '../../../data/providers/test_session_provider.dart';

class StereopsisTestScreen extends StatefulWidget {
  const StereopsisTestScreen({super.key});

  @override
  State<StereopsisTestScreen> createState() => _StereopsisTestScreenState();
}

class _StereopsisTestScreenState extends State<StereopsisTestScreen> {
  @override
  void initState() {
    super.initState();
    // Reset state synchronously before first build
    context.read<StereopsisProvider>().reset();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TestSessionProvider>().startIndividualTest('stereopsis');
    });
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final provider = context.read<TestSessionProvider>();
        return TestExitConfirmationDialog(
          onContinue: () {
            // Just close the dialog
          },
          onRestart: () {
            provider.resetKeepProfile();
            context.read<StereopsisProvider>().reset();
            provider.startIndividualTest('stereopsis');
          },
          onExit: () async {
            await NavigationUtils.navigateHome(context);
          },
          hasCompletedTests: provider.hasAnyCompletedTest,
          onSaveAndExit: provider.hasAnyCompletedTest
              ? () {
                  Navigator.pushReplacementNamed(context, '/quick-test-result');
                }
              : null,
        );
      },
    );
  }

  void _handleAnswer(int selectedIndex) {
    final stereopsisProvider = context.read<StereopsisProvider>();
    final sessionProvider = context.read<TestSessionProvider>();

    stereopsisProvider.submitAnswer(selectedIndex);

    if (stereopsisProvider.isTestComplete) {
      // Store result and navigate to result screen
      final result = stereopsisProvider.createResult();
      sessionProvider.setStereopsisResult(result);
      Navigator.pushReplacementNamed(context, '/quick-test-result');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        backgroundColor: Colors.grey.shade900,
        appBar: AppBar(
          title: const Text('Stereopsis Test'),
          backgroundColor: Colors.grey.shade900,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: SafeArea(
          child: Consumer<StereopsisProvider>(
            builder: (context, provider, child) {
              return Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Round ${provider.currentRound + 1} of ${provider.totalRounds}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Score: ${provider.score}',
                              style: TextStyle(
                                color: context.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: provider.progress,
                          backgroundColor: Colors.grey.shade700,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            context.primary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      'Which circle pops out in 3D?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the circle that appears to float forward',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Circle grid
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 30,
                                mainAxisSpacing: 30,
                              ),
                          itemCount: 4,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _handleAnswer(index),
                              child: _StereopsisCircle(
                                hasDepth: index == provider.correctIndex,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Note
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.amber.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Make sure you are wearing the red-cyan glasses',
                            style: TextStyle(
                              color: Colors.amber.shade100,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Anaglyph circle widget with 3D depth effect
class _StereopsisCircle extends StatelessWidget {
  final bool hasDepth;

  const _StereopsisCircle({required this.hasDepth});

  @override
  Widget build(BuildContext context) {
    final double separation = hasDepth ? 8.0 : 1.5;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Background shadow for depth effect
        if (hasDepth)
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 25,
                  spreadRadius: 2,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
          ),

        // Cyan layer (for right eye)
        Transform.translate(
          offset: Offset(-separation, -separation / 2),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFF00FFFF,
              ).withValues(alpha: hasDepth ? 0.7 : 0.3),
              boxShadow: hasDepth
                  ? [
                      BoxShadow(
                        color: const Color(0xFF00FFFF).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),

        // Red layer (for left eye)
        Transform.translate(
          offset: Offset(separation, separation / 2),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(
                0xFFFF0000,
              ).withValues(alpha: hasDepth ? 0.7 : 0.3),
              boxShadow: hasDepth
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF0000).withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
        ),

        // Main circle
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.grey.shade400,
                Colors.grey.shade800,
                Colors.black,
              ],
              stops: const [0.0, 0.7, 1.0],
              center: const Alignment(-0.35, -0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),

        // Specular highlight
        Positioned(
          top: 15,
          left: 15,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.2),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.4, 1.0],
              ),
            ),
          ),
        ),

        // Subtle border
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
        ),
      ],
    );
  }
}
