import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../extensions/theme_extension.dart';
import '../services/data_cleanup_service.dart';
import '../providers/voice_recognition_provider.dart';
import 'package:provider/provider.dart';

class TestExitConfirmationDialog extends StatefulWidget {
  final VoidCallback onContinue;
  final VoidCallback onRestart;
  final VoidCallback onExit;
  final VoidCallback? onSaveAndExit;
  final bool hasCompletedTests;
  final String title;
  final String content;

  const TestExitConfirmationDialog({
    super.key,
    required this.onContinue,
    required this.onRestart,
    required this.onExit,
    this.onSaveAndExit,
    this.hasCompletedTests = false,
    this.title = 'Exit Test?',
    this.content = 'Your progress will be lost. What would you like to do?',
  });

  @override
  State<TestExitConfirmationDialog> createState() =>
      _TestExitConfirmationDialogState();
}

class _TestExitConfirmationDialogState
    extends State<TestExitConfirmationDialog> {
  bool _showConfirmation = false;
  String? _confirmAction; // 'restart' or 'exit'

  @override
  void initState() {
    super.initState();
    // Pause voice recognition immediately when dialog appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VoiceRecognitionProvider>().cancel();
    });
  }

  void _showConfirm(String action) {
    setState(() {
      _showConfirmation = true;
      _confirmAction = action;
    });
  }

  void _hideConfirm() {
    setState(() {
      _showConfirmation = false;
      _confirmAction = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Full Screen Blur
        Positioned.fill(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(color: Colors.black.withValues(alpha: 0.4)),
          ),
        ),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (Widget child, Animation<double> animation) {
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              );
            },
            child: _showConfirmation
                ? _buildConfirmationView()
                : _buildMainView(),
          ),
        ),
      ],
    );
  }

  Widget _buildMainView() {
    final mediaQuery = MediaQuery.of(context);
    final isLandscape = mediaQuery.orientation == Orientation.landscape;

    return Container(
      key: const ValueKey('main'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(isLandscape ? 20 : 28),
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
          child: isLandscape
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: context.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.pause_circle_filled_rounded,
                              color: context.primary,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Test Paused',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.content,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: context.textPrimary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildVoiceToggle(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildButton(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onContinue();
                            },
                            icon: Icons.play_arrow_rounded,
                            label: 'Continue Test',
                            isPrimary: true,
                          ),
                          const SizedBox(height: 8),
                          _buildButton(
                            onPressed: () => _showConfirm('restart'),
                            icon: Icons.refresh_rounded,
                            label: 'Restart Test',
                          ),
                          // Show Save & Exit if there are completed tests
                          if (widget.hasCompletedTests &&
                              widget.onSaveAndExit != null) ...[
                            const SizedBox(height: 8),
                            _buildButton(
                              onPressed: () => _showConfirm('saveAndExit'),
                              icon: Icons.save_rounded,
                              label: 'Save & Exit',
                              isSaveExit: true,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildButton(
                            onPressed: () => _showConfirm('exit'),
                            icon: Icons.logout_rounded,
                            label: widget.hasCompletedTests
                                ? 'Exit Without Saving'
                                : 'Exit Test',
                            isError: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium Icon Header
                    Container(
                      width: 64,
                      height: 64,
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
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Test Paused',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.content,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.textPrimary.withValues(alpha: 0.6),
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Voice Recognition Control
                    _buildVoiceToggle(),
                    const SizedBox(height: 24),
                    // Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onContinue();
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 24),
                          label: const Text('Continue Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: context.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _showConfirm('restart'),
                          icon: const Icon(Icons.refresh_rounded, size: 20),
                          label: const Text('Restart Test'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: context.warning.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                            foregroundColor: context.warning,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Show Save & Exit if there are completed tests
                        if (widget.hasCompletedTests &&
                            widget.onSaveAndExit != null)
                          OutlinedButton.icon(
                            onPressed: () => _showConfirm('saveAndExit'),
                            icon: const Icon(Icons.save_rounded, size: 20),
                            label: const Text('Save & Exit'),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: context.success.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                              foregroundColor: context.success,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        if (widget.hasCompletedTests &&
                            widget.onSaveAndExit != null)
                          const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => _showConfirm('exit'),
                          icon: const Icon(Icons.logout_rounded, size: 20),
                          label: Text(
                            widget.hasCompletedTests
                                ? 'Exit Without Saving'
                                : 'Exit & Lose Progress',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: context.error,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildVoiceToggle() {
    return Consumer<VoiceRecognitionProvider>(
      builder: (context, provider, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.primary.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (provider.isEnabled
                              ? context.primary
                              : context.textSecondary)
                          .withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  provider.isEnabled
                      ? Icons.mic_rounded
                      : Icons.mic_off_rounded,
                  color: provider.isEnabled
                      ? context.primary
                      : context.textSecondary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voice Recognition',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      provider.isEnabled ? 'Enabled' : 'Disabled',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.isEnabled
                            ? context.primary
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: provider.isEnabled,
                onChanged: (value) => provider.setEnabled(value),
                activeColor: context.primary,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    bool isPrimary = false,
    bool isError = false,
    bool isSaveExit = false,
  }) {
    if (isPrimary) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    final color = isSaveExit
        ? context.success
        : (isError ? context.error : context.warning);

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.3)),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildConfirmationView() {
    final isExit = _confirmAction == 'exit';
    final isSaveAndExit = _confirmAction == 'saveAndExit';
    final actionTitle = isSaveAndExit
        ? 'Save & Exit?'
        : (isExit ? 'Exit Test?' : 'Restart Test?');
    final actionSub = isSaveAndExit
        ? 'Completed tests will be saved. The current test in progress will not be saved.'
        : (isExit
              ? 'Are you sure you want to end this session? All progress will be lost.'
              : 'Are you sure you want to start over? Current progress will be reset.');
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      key: const ValueKey('confirm'),
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.all(isLandscape ? 20 : 28),
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
          child: isLandscape
              ? Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color:
                                  (isSaveAndExit
                                          ? context.success
                                          : (isExit
                                                ? context.error
                                                : context.warning))
                                      .withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isSaveAndExit
                                  ? Icons.save_rounded
                                  : (isExit
                                        ? Icons.dangerous_rounded
                                        : Icons.help_outline_rounded),
                              color: isSaveAndExit
                                  ? context.success
                                  : (isExit ? context.error : context.warning),
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            actionTitle,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            actionSub,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textPrimary.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton(
                            onPressed: () async {
                              if (isSaveAndExit) {
                                if (mounted) {
                                  Navigator.pop(context);
                                  widget.onSaveAndExit?.call();
                                }
                              } else if (isExit) {
                                await DataCleanupService.cleanupTestData(
                                  context,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  widget.onExit();
                                }
                              } else {
                                Navigator.pop(context);
                                widget.onRestart();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSaveAndExit
                                  ? context.success
                                  : (isExit ? context.error : context.warning),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSaveAndExit
                                  ? 'Yes, Save & Exit'
                                  : (isExit ? 'Yes, Exit' : 'Yes, Restart'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: _hideConfirm,
                            style: TextButton.styleFrom(
                              foregroundColor: context.textSecondary,
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: const Text(
                              'No, Go Back',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color:
                            (isSaveAndExit
                                    ? context.success
                                    : (isExit
                                          ? context.error
                                          : context.warning))
                                .withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSaveAndExit
                            ? Icons.save_rounded
                            : (isExit
                                  ? Icons.dangerous_rounded
                                  : Icons.help_outline_rounded),
                        color: isSaveAndExit
                            ? context.success
                            : (isExit ? context.error : context.warning),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      actionTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      actionSub,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary.withValues(alpha: 0.6),
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: _hideConfirm,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              foregroundColor: context.textSecondary,
                            ),
                            child: const Text(
                              'No, Go Back',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              if (isSaveAndExit) {
                                if (mounted) {
                                  Navigator.pop(context);
                                  widget.onSaveAndExit?.call();
                                }
                              } else if (isExit) {
                                await DataCleanupService.cleanupTestData(
                                  context,
                                );
                                if (mounted) {
                                  Navigator.pop(context);
                                  widget.onExit();
                                }
                              } else {
                                Navigator.pop(context);
                                widget.onRestart();
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isSaveAndExit
                                  ? context.success
                                  : (isExit ? context.error : context.warning),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              isSaveAndExit
                                  ? 'Yes, Save & Exit'
                                  : (isExit ? 'Yes, Exit' : 'Yes, Restart'),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
