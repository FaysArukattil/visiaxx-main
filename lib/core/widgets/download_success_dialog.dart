import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import '../services/file_manager_service.dart';
import '../extensions/theme_extension.dart';
import '../widgets/eye_loader.dart';
import '../utils/snackbar_utils.dart';

class DownloadSuccessDialog extends StatefulWidget {
  final String? filePath;
  final String? fileName;
  final String folderPath;
  final int count;

  const DownloadSuccessDialog({
    super.key,
    this.filePath,
    this.fileName,
    required this.folderPath,
    this.count = 1,
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
  bool _isOpeningFolder = false;
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

  String get _folderName {
    return widget.folderPath.split(RegExp(r'[/\\]')).last;
  }

  Future<void> _saveToCustomLocation() async {
    if (widget.filePath == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final pdfBytes = await File(widget.filePath!).readAsBytes();

      await Printing.layoutPdf(
        onLayout: (format) => pdfBytes,
        name: widget.fileName ?? 'Visiaxx_Report',
      );

      if (mounted) {
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
    if (widget.filePath == null) return;

    setState(() {
      _isSharing = true;
      _errorMessage = null;
    });

    try {
      await Share.shareXFiles([
        XFile(widget.filePath!),
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
    if (widget.filePath == null) return;

    setState(() {
      _isOpening = true;
      _errorMessage = null;
    });

    try {
      final result = await OpenFilex.open(widget.filePath!);

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

  Future<void> _openFolder() async {
    setState(() {
      _isOpeningFolder = true;
      _errorMessage = null;
    });

    try {
      final success = await FileManagerService.openFolder(widget.folderPath);

      if (mounted) {
        if (!success) {
          SnackbarUtils.showWarning(
            context,
            Platform.isAndroid
                ? 'Files saved! Open Files app → Downloads → Visiaxx_Reports'
                : 'Files saved! Open Files app to view reports',
            duration: const Duration(seconds: 5),
          );
        } else {
          SnackbarUtils.showSuccess(context, 'Opening file manager...');
        }
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not open file manager. Files are saved in Downloads/Visiaxx_Reports';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningFolder = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnyActionInProgress =
        _isSaving || _isSharing || _isOpening || _isOpeningFolder;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                    child: Column(
                      children: [
                        // Success Icon with glow
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.success.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: FadeTransition(
                              opacity: _checkmarkAnimation,
                              child: Icon(
                                Icons.check_circle_rounded,
                                color: context.success,
                                size: 52,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          widget.count > 1 ? 'Reports Ready' : 'Report Ready',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: context.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Successfully prepared ${widget.count} clinical report${widget.count > 1 ? 's' : ''}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: context.textSecondary.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Location Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.scaffoldBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.dividerColor.withValues(
                                alpha: 0.5,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.folder_open_rounded,
                                    size: 16,
                                    color: context.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'SAVE LOCATION',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                      color: context.textTertiary,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _folderName,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: context.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.folderPath,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.textSecondary,
                                  fontFamily: 'monospace',
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Error Message (if any)
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: context.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: context.error.withValues(alpha: 0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: context.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: context.error,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        // Action Buttons
                        if (widget.filePath != null) ...[
                          // Primary Actions for single file
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: isAnyActionInProgress
                                      ? null
                                      : _shareFile,
                                  icon: _isSharing
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: EyeLoader.button(),
                                        )
                                      : const Icon(
                                          Icons.share_outlined,
                                          size: 18,
                                        ),
                                  label: Text(
                                    _isSharing ? 'Sharing...' : 'Share',
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    side: BorderSide(
                                      color: context.primary,
                                      width: 1.5,
                                    ),
                                    foregroundColor: context.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isAnyActionInProgress
                                      ? null
                                      : _openFile,
                                  icon: _isOpening
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: EyeLoader.button(),
                                        )
                                      : const Icon(Icons.open_in_new, size: 18),
                                  label: Text(
                                    _isOpening ? 'Opening...' : 'Open',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: context.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
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
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: isAnyActionInProgress
                                  ? null
                                  : _saveToCustomLocation,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: EyeLoader.button(),
                                    )
                                  : const Icon(Icons.print_rounded, size: 18),
                              label: Text(
                                _isSaving
                                    ? 'Printing...'
                                    : 'Save to Files / Print',
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                side: BorderSide(
                                  color: context.dividerColor,
                                  width: 1.5,
                                ),
                                foregroundColor: context.textSecondary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Shared "Open Folder" Action
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: isAnyActionInProgress
                                ? null
                                : _openFolder,
                            icon: _isOpeningFolder
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: EyeLoader.button(),
                                  )
                                : const Icon(
                                    Icons.folder_open_rounded,
                                    size: 18,
                                  ),
                            label: const Text('Open Folder Location'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(
                                color: context.dividerColor,
                                width: 1.5,
                              ),
                              foregroundColor: context.textSecondary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Close',
                            style: TextStyle(
                              color: context.textTertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the dialog
Future<void> showDownloadSuccessDialog({
  required BuildContext context,
  String? filePath,
  String? fileName,
  required String folderPath,
  int count = 1,
}) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => DownloadSuccessDialog(
      filePath: filePath,
      fileName: fileName,
      folderPath: folderPath,
      count: count,
    ),
  );
}
