import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/network_connectivity_provider.dart';

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
    // Check network connectivity
    final connectivity = Provider.of<NetworkConnectivityProvider>(
      context,
      listen: false,
    );

    if (!connectivity.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No internet connection. Please connect to download the PDF.',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

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
