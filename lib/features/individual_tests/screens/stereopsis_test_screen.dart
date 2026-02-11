import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/widgets/test_exit_confirmation_dialog.dart';
import '../../../data/providers/stereopsis_provider.dart';
import '../../../data/providers/test_session_provider.dart';

/// Data class for each stereopsis test image
// Image class is now in StereopsisProvider

class StereopsisTestScreen extends StatefulWidget {
  const StereopsisTestScreen({super.key});

  @override
  State<StereopsisTestScreen> createState() => _StereopsisTestScreenState();
}

class _StereopsisTestScreenState extends State<StereopsisTestScreen> {
  @override
  void initState() {
    super.initState();
    // Defer to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StereopsisProvider>().reset();
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
          onContinue: () {},
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

  void _handleAnswer(bool perceived3D) {
    final stereopsisProvider = context.read<StereopsisProvider>();
    final sessionProvider = context.read<TestSessionProvider>();

    stereopsisProvider.submitAnswer(perceived3D);

    if (stereopsisProvider.isTestComplete) {
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
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text('Stereopsis Test'),
          backgroundColor: Colors.black,
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
              if (provider.testImages.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              final currentImage = provider.currentImage;
              final description =
                  'Image ${provider.currentRound + 1} of ${provider.totalRounds}';

              return Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              description,
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
                          backgroundColor: Colors.grey.shade800,
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
                      'Does this image appear in 3D?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Look through your red-cyan glasses',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Anaglyph 3D Image
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          currentImage.assetPath,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white54,
                                    size: 64,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Image not found',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Choice Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildChoiceButton(
                            label: 'FLAT',
                            icon: Icons.crop_square_rounded,
                            onPressed: () => _handleAnswer(false),
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildChoiceButton(
                            label: '3D',
                            icon: Icons.view_in_ar_rounded,
                            onPressed: () => _handleAnswer(true),
                            color: context.primary,
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

  Widget _buildChoiceButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
