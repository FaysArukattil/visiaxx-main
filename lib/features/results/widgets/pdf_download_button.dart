import 'package:flutter/material.dart';

/// PDF download button widget
class PdfDownloadButton extends StatefulWidget {
  final VoidCallback onDownload;
  final String buttonText;

  const PdfDownloadButton({
    super.key,
    required this.onDownload,
    this.buttonText = 'Download PDF Report',
  });

  @override
  State<PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<PdfDownloadButton> {
  bool _isDownloading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isDownloading ? null : _handleDownload,
        icon: _isDownloading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.picture_as_pdf),
        label: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_isDownloading ? 'Generating PDF...' : widget.buttonText),
        ),
      ),
    );
  }

  Future<void> _handleDownload() async {
    setState(() {
      _isDownloading = true;
    });

    widget.onDownload();

    // Simulate download delay
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isDownloading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
