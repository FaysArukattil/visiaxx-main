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

  void _handleAnswer(bool perceived3D) {
    final stereopsisProvider = context.read<StereopsisProvider>();
    final sessionProvider = context.read<TestSessionProvider>();

    stereopsisProvider.submitAnswer(perceived3D);

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
                      'Does this ball appear in 3D?',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 18, // Reduced from 20
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4), // Reduced from 8
                  Text(
                    'Tap the button that matches your perception',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13, // Reduced from 14
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Single Circle View
                  Expanded(
                    child: Center(
                      child: provider.is3DInCurrentRound
                          ? _StereopsisCircle(
                              arc: provider.currentArc,
                              hasDepth: true,
                            )
                          : const _StereopsisCircle(hasDepth: false),
                    ),
                  ),

                  // Choice Buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildChoiceButton(
                            label: 'APPEARS FLAT',
                            icon: Icons.unfold_less_rounded,
                            onPressed: () => _handleAnswer(false),
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildChoiceButton(
                            label: 'PERCEIVED 3D',
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
      height: 48, // Further reduced height to prevent overflow
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero, // Remove internal padding
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Row(
          // Changed from Column to Row for more horizontal space/less vertical
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Anaglyph circle widget with dynamic 3D depth effect
class _StereopsisCircle extends StatelessWidget {
  final bool hasDepth;
  final int arc;

  const _StereopsisCircle({this.hasDepth = false, this.arc = 400});

  @override
  Widget build(BuildContext context) {
    // Aggressive separation for better 3D effect perception
    // ARC 400 -> 16px, ARC 200 -> 8px, ARC 100 -> 4px, ARC 40 -> 2px
    final double separation = hasDepth ? (arc / 25.0).clamp(1.5, 20.0) : 0.0;

    return Center(
      child: CustomPaint(
        size: const Size(200, 200),
        painter: _AnaglyphBallPainter(separation: separation),
      ),
    );
  }
}

class _AnaglyphBallPainter extends CustomPainter {
  final double separation;

  _AnaglyphBallPainter({required this.separation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.42;

    // Background shadow
    if (separation > 2) {
      final shadowPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.5)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + separation);
      canvas.drawCircle(
        center + Offset(0, 8 + separation),
        radius,
        shadowPaint,
      );
    }

    // Save layer to handle blending modes correctly
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // 1. Right Eye Layer (Cyan)
    final cyanPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF00FFFF),
              const Color(0xFF00AAAA),
              Colors.black,
            ],
            stops: const [0.0, 0.7, 1.0],
            center: const Alignment(-0.35, -0.35),
          ).createShader(
            Rect.fromCircle(
              center: center.translate(-separation, 0),
              radius: radius,
            ),
          );
    canvas.drawCircle(center.translate(-separation, 0), radius, cyanPaint);

    // 2. Left Eye Layer (Red)
    final redPaint = Paint()
      ..blendMode = BlendMode
          .screen // Combine Red + Cyan -> White highlights
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFFFF0000),
              const Color(0xFFAA0000),
              Colors.black,
            ],
            stops: const [0.0, 0.7, 1.0],
            center: const Alignment(-0.35, -0.35),
          ).createShader(
            Rect.fromCircle(
              center: center.translate(separation, 0),
              radius: radius,
            ),
          );
    canvas.drawCircle(center.translate(separation, 0), radius, redPaint);

    canvas.restore();

    // 3. Subtle highlight to unite the layers
    final highlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: 0.2), Colors.transparent],
        stops: const [0.0, 0.6],
        center: const Alignment(-0.4, -0.4),
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _AnaglyphBallPainter oldDelegate) =>
      oldDelegate.separation != separation;
}
