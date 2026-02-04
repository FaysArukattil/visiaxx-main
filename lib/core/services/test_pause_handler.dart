import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../extensions/theme_extension.dart';
import '../utils/navigation_utils.dart';

/// Global service to handle app pause/resume across all test screens
/// Provides consistent pause dialog and behavior throughout the app
class TestPauseHandler {
  // Singleton instance
  static final TestPauseHandler _instance = TestPauseHandler._internal();
  factory TestPauseHandler() => _instance;
  TestPauseHandler._internal();

  // Callbacks
  VoidCallback? _onPause;
  VoidCallback? _onResume;
  bool Function()? _shouldIgnorePause;
  String Function()? _getTestName;

  // State
  bool _isPaused = false;
  BuildContext? _context;

  /// Initialize with callbacks for current test
  void initialize({
    required BuildContext context,
    required VoidCallback onPause,
    required VoidCallback onResume,
    bool Function()? shouldIgnorePause,
    String Function()? getTestName,
  }) {
    _context = context;
    _onPause = onPause;
    _onResume = onResume;
    _shouldIgnorePause = shouldIgnorePause;
    _getTestName = getTestName;
    _isPaused = false;
  }

  void updateContext(BuildContext context) {
    _context = context;
  }

  /// Call this when app goes to background
  void handleAppPaused() {
    if (_shouldIgnorePause?.call() ?? false) {
      debugPrint('[TestPauseHandler] Ignoring pause (in initial phase)');
      return;
    }

    if (_isPaused) {
      debugPrint('[TestPauseHandler] Already paused, ignoring');
      return;
    }

    debugPrint('[TestPauseHandler] App paused - stopping test');
    _isPaused = true;
    _onPause?.call();
  }

  /// Call this when app comes back to foreground
  void handleAppResumed() {
    if (_context == null || !(_context as Element).mounted) {
      debugPrint('[TestPauseHandler] Context not available');
      return;
    }

    if (_shouldIgnorePause?.call() ?? false) {
      debugPrint('[TestPauseHandler] Ignoring resume (in initial phase)');
      return;
    }

    if (!_isPaused) {
      debugPrint('[TestPauseHandler] Not paused, ignoring resume');
      return;
    }

    // Show resume dialog after a brief delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_context != null && (_context as Element).mounted && _isPaused) {
        showPauseDialog();
      }
    });
  }

  /// Show the standardized pause dialog
  void showPauseDialog({String? reason}) {
    if (_context == null) return;

    final description =
        reason ?? 'The test was paused because the app was minimized.';

    showDialog(
      context: _context!,
      barrierDismissible: false,
      builder: (context) {
        final isLandscape =
            MediaQuery.of(context).orientation == Orientation.landscape;

        return Stack(
          children: [
            // Standardized Blur Background
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(color: Colors.black.withValues(alpha: 0.4)),
              ),
            ),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                constraints: BoxConstraints(maxWidth: isLandscape ? 600 : 400),
                decoration: ShapeDecoration(
                  color: context.surface.withValues(alpha: 0.98),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(isLandscape ? 24 : 32),
                    child: isLandscape
                        ? _buildLandscapeView(context, description)
                        : _buildPortraitView(context, description),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPortraitView(BuildContext context, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildIconHeader(context),
        const SizedBox(height: 24),
        _buildTitle(context),
        const SizedBox(height: 12),
        _buildDescription(context, description),
        const SizedBox(height: 32),
        _buildActionButtons(context, isVertical: true),
      ],
    );
  }

  Widget _buildLandscapeView(BuildContext context, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconHeader(context, size: 64),
              const SizedBox(height: 16),
              _buildTitle(context, fontSize: 22),
              const SizedBox(height: 8),
              _buildDescription(context, description),
            ],
          ),
        ),
        const SizedBox(width: 32),
        Expanded(child: _buildActionButtons(context, isVertical: true)),
      ],
    );
  }

  Widget _buildIconHeader(BuildContext context, {double size = 80}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.primary.withValues(alpha: 0.1),
        shape: BoxShape.circle,
        border: Border.all(
          color: context.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Icon(
        Icons.pause_circle_filled_rounded,
        color: context.primary,
        size: size * 0.55,
      ),
    );
  }

  Widget _buildTitle(BuildContext context, {double fontSize = 26}) {
    return Text(
      'Test Paused',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        color: context.textPrimary,
        letterSpacing: -0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDescription(BuildContext context, String description) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: context.textPrimary.withValues(alpha: 0.6),
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Would you like to continue?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textPrimary.withValues(alpha: 0.4),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, {bool isVertical = true}) {
    final buttons = [
      ElevatedButton(
        onPressed: () {
          Navigator.pop(context);
          _isPaused = false;
          _onResume?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Continue Test',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      const SizedBox(height: 12, width: 12),
      OutlinedButton(
        onPressed: () {
          _showExitConfirmation(context);
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: context.error,
          side: BorderSide(color: context.error.withValues(alpha: 0.3)),
          padding: const EdgeInsets.symmetric(vertical: 18),
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Exit Test',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    ];

    return isVertical
        ? Column(mainAxisSize: MainAxisSize.min, children: buttons)
        : Row(children: buttons.map((b) => Expanded(child: b)).toList());
  }

  void _showExitConfirmation(BuildContext dialogContext) {
    final testName = _getTestName?.call() ?? 'Test';

    showDialog(
      context: dialogContext,
      builder: (context) {
        return Stack(
          children: [
            // Darker overlay for confirmation
            Positioned.fill(child: Container(color: Colors.black26)),
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                constraints: const BoxConstraints(maxWidth: 340),
                padding: const EdgeInsets.all(28),
                decoration: ShapeDecoration(
                  color: context.surface,
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                  shadows: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: context.error.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_rounded,
                          color: context.error,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Exit $testName?',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: context.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your progress will be lost. Are you sure you want to exit?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: context.textPrimary.withValues(alpha: 0.6),
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                foregroundColor: context.textSecondary,
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                if (context.mounted) {
                                  Navigator.pop(context); // Close confirmation
                                  Navigator.pop(
                                    dialogContext,
                                  ); // Close pause dialog
                                  await NavigationUtils.navigateHome(_context!);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: context.error,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Yes, Exit',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Dispose/cleanup
  void dispose() {
    _onPause = null;
    _onResume = null;
    _shouldIgnorePause = null;
    _getTestName = null;
    _context = null;
    _isPaused = false;
  }
}
