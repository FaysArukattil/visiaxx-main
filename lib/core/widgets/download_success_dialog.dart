import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../../core/constants/app_colors.dart';

class DownloadSuccessDialog extends StatefulWidget {
  final String filePath;
  final String fileName;

  const DownloadSuccessDialog({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  State<DownloadSuccessDialog> createState() => _DownloadSuccessDialogState();
}

class _DownloadSuccessDialogState extends State<DownloadSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkmarkAnimation;

  bool _isSaving = false;
  bool _isSharing = false;
  bool _isOpening = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    _checkmarkAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _location {
    if (widget.filePath.contains('/Download')) {
      return 'Downloads Folder';
    } else if (widget.filePath.contains('/Documents')) {
      return 'Documents Folder';
    } else {
      return 'App Storage';
    }
  }

  String get _locationIcon {
    if (widget.filePath.contains('/Download')) {
      return '📥';
    } else if (widget.filePath.contains('/Documents')) {
      return '📄';
    } else {
      return '📱';
    }
  }

  Future<void> _saveToCustomLocation() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final pdfBytes = await File(widget.filePath).readAsBytes();

      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: widget.fileName,
      );

      if (mounted) {
        // Successfully opened system dialog - close this dialog
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to open system save dialog. Please try sharing or opening the file instead.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareFile() async {
    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      await Share.shareXFiles([
        XFile(widget.filePath),
      ], subject: 'Vision Test Report');

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Unable to share the file. Please check your sharing settings.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _openFile() async {
    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    try {
      final result = await OpenFilex.open(widget.filePath);

      if (mounted) {
        if (result.type == ResultType.done) {
          Navigator.pop(context);
        } else if (result.type == ResultType.noAppToOpen) {
          setState(() {
            _errorMessage =
                'No PDF reader app found. Please install a PDF reader or try sharing the file.';
          });
        } else if (result.type == ResultType.fileNotFound) {
          setState(() {
            _errorMessage =
                'File not found. The PDF may have been moved or deleted.';
          });
        } else {
          setState(() {
            _errorMessage = 'Unable to open the file. Please try again.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'An error occurred while opening the file. Please try sharing instead.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isOpening = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyActionInProgress = _isSaving || _isSharing || _isOpening;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated Success Icon
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.success.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                    ),
                    FadeTransition(
                      opacity: _checkmarkAnimation,
                      child: const Icon(
                        Icons.check_circle,
                        color: AppColors.success,
                        size: 56,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Title
            const Text(
              'PDF Downloaded Successfully',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),

            const SizedBox(height: 8),

            // Subtitle
            Text(
              'Your vision test report is ready',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // File Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                children: [
                  // File name
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf,
                          color: AppColors.error,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.fileName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'PDF Document',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 12),
                  // Location
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _locationIcon,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _location,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              widget.filePath,
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textTertiary,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Error Message (if any)
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.error.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.error,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Primary Action Buttons (Open & Share)
            Row(
              children: [
                // Share Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isAnyActionInProgress ? null : _shareFile,
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          )
                        : const Icon(Icons.share_outlined, size: 18),
                    label: Text(_isSharing ? 'Sharing...' : 'Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: isAnyActionInProgress
                            ? AppColors.border
                            : AppColors.primary,
                        width: 1.5,
                      ),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Open PDF Button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isAnyActionInProgress ? null : _openFile,
                    icon: _isOpening
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.open_in_new, size: 18),
                    label: Text(_isOpening ? 'Opening...' : 'Open'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAnyActionInProgress
                          ? AppColors.primary.withOpacity(0.5)
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Save/Print Button (Secondary Action)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isAnyActionInProgress ? null : _saveToCustomLocation,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      )
                    : const Icon(Icons.file_download_outlined, size: 18),
                label: Text(
                  _isSaving
                      ? 'Opening System Dialog...'
                      : 'Save to Files / Print',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: AppColors.border, width: 1.5),
                  foregroundColor: AppColors.textSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Close Button
            TextButton(
              onPressed: isAnyActionInProgress
                  ? null
                  : () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
              ),
              child: Text(
                'Close',
                style: TextStyle(
                  color: isAnyActionInProgress
                      ? AppColors.textTertiary
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the dialog
Future<void> showDownloadSuccessDialog({
  required BuildContext context,
  required String filePath,
  String? fileName,
}) async {
  final name = fileName ?? filePath.split(Platform.pathSeparator).last;

  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) =>
        DownloadSuccessDialog(filePath: filePath, fileName: name),
  );
}
