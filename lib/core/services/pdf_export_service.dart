import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../../data/models/test_result_model.dart';
import '../../data/models/questionnaire_model.dart';
import '../../data/models/amsler_grid_result.dart';
import '../../data/models/color_vision_result.dart';
import 'package:flutter/services.dart';

/// Service for generating PDF reports of test results
class PdfExportService {
  /// Generate and download PDF report to device's Downloads folder
  /// Generate and download PDF report to device's Downloads folder
  /// Generate and download PDF report to device's Downloads folder
  /// Generate and download PDF silently to Downloads folder
  /// Generate and download PDF report to device's Downloads folder
  Future<String> generateAndDownloadPdf(TestResultModel result) async {
    try {
      // Generate filename
      final name = result.profileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final age = result.profileAge != null ? '${result.profileAge}' : 'NA';
      final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
      final timeStr = DateFormat('HH-mm').format(result.timestamp);
      final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

      // Generate PDF
      debugPrint('[PdfExportService] 📄 Generating PDF...');
      final pdf = await _buildPdfDocument(result);
      final pdfBytes = await pdf.save();
      debugPrint(
        '[PdfExportService] ✅ PDF generated (${pdfBytes.length} bytes)',
      );

      // Save to Downloads folder
      final savedPath = await _saveToDownloads(pdfBytes, filename);
      debugPrint('[PdfExportService] ✅ PDF saved to: $savedPath');

      return savedPath;
    } catch (e) {
      debugPrint('[PdfExportService] ❌ Error generating PDF: $e');

      // Fallback: Save to app documents directory
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final name = result.profileName.replaceAll(
          RegExp(r'[^a-zA-Z0-9]'),
          '_',
        );
        final age = result.profileAge != null ? '${result.profileAge}' : 'NA';
        final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
        final timeStr = DateFormat('HH-mm').format(result.timestamp);
        final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';
        final fallbackPath = '${appDir.path}/$filename';

        final file = File(fallbackPath);
        final pdf = await _buildPdfDocument(result);
        await file.writeAsBytes(await pdf.save());

        debugPrint('[PdfExportService] ✅ PDF saved to fallback: $fallbackPath');
        return fallbackPath;
      } catch (fallbackError) {
        throw Exception(
          'Failed to save PDF: $e. Fallback also failed: $fallbackError',
        );
      }
    }
  }

  Future<String> _fallbackSave(Uint8List bytes, String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$filename');
    await file.writeAsBytes(bytes);
    return file.path;
  }

  /// Save file to Downloads folder (works on Android & iOS)
  Future<String> _saveToDownloads(Uint8List bytes, String filename) async {
    if (Platform.isAndroid) {
      // Android: Save to public Downloads folder
      try {
        // Request storage permission
        final status = await Permission.storage.request();

        if (status.isDenied) {
          debugPrint(
            '[PdfExportService] ⚠️ Permission denied, trying app directory',
          );
          return await _saveToAppDirectory(bytes, filename);
        }

        // Try to save to Downloads folder
        final downloadsDir = Directory('/storage/emulated/0/Download');

        if (await downloadsDir.exists()) {
          final file = File('${downloadsDir.path}/$filename');
          await file.writeAsBytes(bytes);
          debugPrint('[PdfExportService] ✅ Saved to Downloads: ${file.path}');
          return file.path;
        } else {
          // Try alternate path
          final altDownloadsDir = Directory('/storage/emulated/0/Downloads');
          if (await altDownloadsDir.exists()) {
            final file = File('${altDownloadsDir.path}/$filename');
            await file.writeAsBytes(bytes);
            debugPrint('[PdfExportService] ✅ Saved to Downloads: ${file.path}');
            return file.path;
          }
        }

        // Fallback to external storage
        debugPrint(
          '[PdfExportService] ⚠️ Downloads folder not found, using external storage',
        );
        final externalDir = await getExternalStorageDirectory();
        if (externalDir != null) {
          // Create a Downloads subfolder in external storage
          final downloadsPath = Directory('${externalDir.path}/Downloads');
          if (!await downloadsPath.exists()) {
            await downloadsPath.create(recursive: true);
          }
          final file = File('${downloadsPath.path}/$filename');
          await file.writeAsBytes(bytes);
          debugPrint('[PdfExportService] ✅ Saved to: ${file.path}');
          return file.path;
        }

        // Last resort
        return await _saveToAppDirectory(bytes, filename);
      } catch (e) {
        debugPrint('[PdfExportService] ❌ Android save failed: $e');
        return await _saveToAppDirectory(bytes, filename);
      }
    } else if (Platform.isIOS) {
      // iOS: Save to app documents directory (this is the proper way for iOS)
      return await _saveToAppDirectory(bytes, filename);
    } else {
      // Other platforms
      return await _saveToAppDirectory(bytes, filename);
    }
  }

  /// Fallback: Save to app-specific directory
  Future<String> _saveToAppDirectory(Uint8List bytes, String filename) async {
    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/$filename');
    await file.writeAsBytes(bytes);
    debugPrint('[PdfExportService] ✅ Saved to app directory: ${file.path}');
    return file.path;
  }

  /// Save PDF to Android Downloads folder using MediaStore (Android 10+)
  Future<String> _saveToDownloadsAndroid(
    Uint8List pdfBytes,
    TestResultModel result,
  ) async {
    try {
      // Generate filename
      final name = result.profileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final age = result.profileAge != null ? '${result.profileAge}' : 'NA';
      final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
      final timeStr = DateFormat('HH-mm').format(result.timestamp);
      final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

      // Check Android version
      int sdkInt = 0;
      try {
        final androidInfo = await _getAndroidSdkVersion();
        sdkInt = androidInfo;
      } catch (e) {
        debugPrint('[PdfExportService] Could not get SDK version: $e');
      }

      debugPrint('[PdfExportService] Android SDK: $sdkInt');

      if (sdkInt >= 29) {
        // Android 10+ (API 29+) - Use MediaStore via platform channel
        return await _saveViaMediaStore(pdfBytes, filename);
      } else {
        // Android 9 and below - Use traditional file system
        return await _saveViaLegacyStorage(pdfBytes, filename);
      }
    } catch (e) {
      debugPrint('[PdfExportService] ❌ Android save failed: $e');
      rethrow;
    }
  }

  /// Get Android SDK version
  Future<int> _getAndroidSdkVersion() async {
    if (!Platform.isAndroid) return 0;

    try {
      const platform = MethodChannel('com.example.visiaxx/system_info');
      final int version = await platform.invokeMethod('getAndroidVersion');
      return version;
    } catch (e) {
      // Fallback: assume modern Android
      debugPrint('[PdfExportService] Could not get SDK version, assuming 29+');
      return 29;
    }
  }

  /// Save using MediaStore (Android 10+)
  Future<String> _saveViaMediaStore(Uint8List pdfBytes, String filename) async {
    try {
      const platform = MethodChannel('com.example.visiaxx/downloads');
      final String? path = await platform.invokeMethod('saveToDownloads', {
        'filename': filename,
        'bytes': pdfBytes,
        'mimeType': 'application/pdf',
      });

      if (path != null && path.isNotEmpty) {
        debugPrint('[PdfExportService] ✅ Saved via MediaStore: $path');
        return path;
      } else {
        throw Exception('MediaStore returned null path');
      }
    } catch (e) {
      debugPrint('[PdfExportService] ❌ MediaStore failed: $e');
      // Fallback to legacy method
      return await _saveViaLegacyStorage(pdfBytes, filename);
    }
  }

  /// Save using legacy file system (Android 9 and below)
  Future<String> _saveViaLegacyStorage(
    Uint8List pdfBytes,
    String filename,
  ) async {
    try {
      // Request storage permission
      final status = await Permission.storage.request();

      if (!status.isGranted) {
        throw Exception('Storage permission denied');
      }

      // Try common Download paths
      final List<String> candidatePaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
        '/sdcard/Downloads',
      ];

      for (final dirPath in candidatePaths) {
        final dir = Directory(dirPath);
        if (await dir.exists()) {
          try {
            final file = File('$dirPath/$filename');
            await file.writeAsBytes(pdfBytes);

            // Make file visible in Downloads app
            await _scanFile(file.path);

            debugPrint('[PdfExportService] ✅ Saved to: ${file.path}');
            return file.path;
          } catch (e) {
            debugPrint('[PdfExportService] ⚠️ Failed to write to $dirPath: $e');
            continue;
          }
        }
      }

      throw Exception('Could not find writable Downloads directory');
    } catch (e) {
      debugPrint('[PdfExportService] ❌ Legacy storage failed: $e');

      // Last resort: app-specific directory
      final appDir = await getExternalStorageDirectory();
      if (appDir != null) {
        final file = File('${appDir.path}/$filename');
        await file.writeAsBytes(pdfBytes);
        debugPrint(
          '[PdfExportService] ⚠️ Saved to app directory: ${file.path}',
        );
        return file.path;
      }

      rethrow;
    }
  }

  /// Scan file to make it visible in Downloads app (legacy Android)
  Future<void> _scanFile(String filePath) async {
    try {
      const platform = MethodChannel('com.example.visiaxx/media_scanner');
      await platform.invokeMethod('scanFile', {'path': filePath});
      debugPrint('[PdfExportService] 📱 File scanned for media store');
    } catch (e) {
      debugPrint('[PdfExportService] ⚠️ Media scan failed: $e');
    }
  }

  /// Get the expected file path for a test result PDF
  /// Get the expected file path for a test result PDF
  Future<String> getExpectedFilePath(TestResultModel result) async {
    final name = result.profileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final age = result.profileAge != null ? '${result.profileAge}' : 'NA';
    final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
    final timeStr = DateFormat('HH-mm').format(result.timestamp);
    final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

    if (Platform.isAndroid) {
      // Try Downloads folder first
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        return '${downloadsDir.path}/$filename';
      }
      // Fallback to external storage
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        return '${externalDir.path}/Downloads/$filename';
      }
    }

    // iOS or fallback
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/$filename';
  }

  /// Compatibility method for existing UI calls.
  Future<String> sharePdf(TestResultModel result, {String? userName}) async {
    return generateAndDownloadPdf(result);
  }

  /// BUILD PROFESSIONAL PDF
  Future<pw.Document> _buildPdfDocument(TestResultModel result) async {
    final pdf = pw.Document();

    // Pre-fetch Amsler grid images if they exist (local or remote)
    Uint8List? amslerRightBytes;
    Uint8List? amslerLeftBytes;

    if (result.amslerGridRight != null) {
      amslerRightBytes = await _getImageBytes(
        result.amslerGridRight!.annotatedImagePath,
        result.amslerGridRight!.awsImageUrl ??
            result.amslerGridRight!.firebaseImageUrl,
      );
    }

    if (result.amslerGridLeft != null) {
      amslerLeftBytes = await _getImageBytes(
        result.amslerGridLeft!.annotatedImagePath,
        result.amslerGridLeft!.awsImageUrl ??
            result.amslerGridLeft!.firebaseImageUrl,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(context, result.profileName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Title Section
          _buildTitleSection(result, result.profileName, result.profileAge),
          pw.SizedBox(height: 24),

          // Executive Summary
          _buildExecutiveSummary(result),
          pw.SizedBox(height: 24),

          // Visual Acuity Section - DETAILED
          _buildVisualAcuityDetailedSection(result),
          pw.SizedBox(height: 24),

          // Short Distance Section - DETAILED
          if (result.shortDistance != null) ...[
            _buildShortDistanceDetailedSection(result),
            pw.SizedBox(height: 24),
          ],

          // Color Vision Section - DETAILED
          _buildColorVisionDetailedSection(result),
          pw.SizedBox(height: 24),

          // Amsler Grid Section - DETAILED
          _buildAmslerGridDetailedSection(
            result,
            rightImageBytes: amslerRightBytes,
            leftImageBytes: amslerLeftBytes,
          ),
          pw.SizedBox(height: 24),

          // Pelli-Robson Contrast Sensitivity Section - DETAILED
          if (result.pelliRobson != null) ...[
            _buildPelliRobsonDetailedSection(result),
            pw.SizedBox(height: 24),
          ],

          // Overall Assessment
          _buildOverallAssessment(result),

          // Questionnaire (if space allows)
          if (result.questionnaire != null) ...[
            pw.SizedBox(height: 24),
            _buildQuestionnaireSection(result.questionnaire!),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(pw.Context context, String? userName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 2, color: PdfColors.blue800),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'VISIAXX',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Text(
                'Digital Eye Health Assessment',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Text(
            'VISION TEST REPORT',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Generated by Visiaxx App - Confidential Medical Document',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
              pw.Text(
                'Page ${context.pageNumber}/${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'DISCLAIMER: This vision test is a screening tool and is not a substitute for a professional eye examination. '
            'The results should be interpreted by a qualified eye care professional. If you have concerns about your vision, '
            'please seek professional medical advice.',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTitleSection(
    TestResultModel result,
    String? userName,
    int? userAge,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.blue200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PATIENT INFORMATION',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildInfoRow(
                    'Name',
                    result.profileName.isNotEmpty
                        ? result.profileName
                        : (userName ?? 'N/A'),
                  ),
                  if (userAge != null) _buildInfoRow('Age', '$userAge years'),
                  _buildInfoRow(
                    'Profile',
                    result.profileType == 'self' ? 'Self' : 'Family Member',
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'TEST DETAILS',
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  _buildInfoRow(
                    'Date',
                    DateFormat('MMM dd, yyyy').format(result.timestamp),
                  ),
                  _buildInfoRow(
                    'Time',
                    DateFormat('h:mm a').format(result.timestamp),
                  ),
                  _buildInfoRow(
                    'Test ID',
                    result.id.length >= 8
                        ? result.id.substring(0, 8).toUpperCase()
                        : (result.id.isNotEmpty
                              ? result.id.toUpperCase()
                              : 'NEW'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// EXECUTIVE SUMMARY
  pw.Widget _buildExecutiveSummary(TestResultModel result) {
    PdfColor statusColor = result.overallStatus == TestStatus.normal
        ? PdfColors.green700
        : result.overallStatus == TestStatus.review
        ? PdfColors.orange700
        : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: statusColor, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EXECUTIVE SUMMARY',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text(
                'Overall Status: ',
                style: const pw.TextStyle(fontSize: 11),
              ),
              pw.Text(
                result.overallStatus.label,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            result.recommendation,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// VISUAL ACUITY - DETAILED
  pw.Widget _buildVisualAcuityDetailedSection(TestResultModel result) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('DISTANCE VISION TEST (1 Meter)'),
        pw.SizedBox(height: 8),

        // Summary Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Eye', isHeader: true),
                _buildTableCell('Snellen', isHeader: true),
                _buildTableCell('Score', isHeader: true),
                _buildTableCell('Clinical Interpretation', isHeader: true),
              ],
            ),
            // Right Eye
            pw.TableRow(
              children: [
                _buildTableCell('Right'),
                _buildTableCell(
                  result.visualAcuityRight?.snellenScore ?? 'N/A',
                ),
                _buildTableCell(
                  '${result.visualAcuityRight?.correctResponses ?? 0}/${result.visualAcuityRight?.totalResponses ?? 0}',
                ),
                _buildTableCell(
                  _getVAInterpretation(result.visualAcuityRight?.logMAR),
                ),
              ],
            ),
            // Left Eye
            pw.TableRow(
              children: [
                _buildTableCell('Left'),
                _buildTableCell(result.visualAcuityLeft?.snellenScore ?? 'N/A'),
                _buildTableCell(
                  '${result.visualAcuityLeft?.correctResponses ?? 0}/${result.visualAcuityLeft?.totalResponses ?? 0}',
                ),
                _buildTableCell(
                  _getVAInterpretation(result.visualAcuityLeft?.logMAR),
                ),
              ],
            ),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Text(
          'Clinical Interpretation:',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.Text(
          _getAcuityClinicalExplanation(
            result.visualAcuityRight?.snellenScore,
            result.visualAcuityLeft?.snellenScore,
          ),
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Note: Visual acuity measured using Tumbling E chart at 1 meter. Normal vision = 6/6 or better.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  String _getAcuityClinicalExplanation(String? right, String? left) {
    if (right == null && left == null) return 'N/A';
    final best = (right != null && right != 'Worse than 6/60') ? right : left;
    if (best == '6/6') {
      return 'Excellent. User identifies optotypes at 6 meters that a standard eye identifies at 6 meters (20/20 equivalent).';
    }
    if (best == '6/9') {
      return 'Good. User identifies optotypes at 6 meters that a standard eye identifies at 9 meters.';
    }
    if (best == '6/12') {
      return 'Mild reduction. User identifies optotypes at 6 meters that a standard eye identifies at 12 meters.';
    }
    if (best == 'Worse') {
      return 'Significant reduction. Performance is below the standard screening threshold.';
    }
    return 'The results represent the clarity of distance vision compared to normative standards.';
  }

  String _getVAInterpretation(double? logMAR) {
    if (logMAR == null) return 'Not tested';
    if (logMAR <= 0.0) return 'Excellent (Normal)';
    if (logMAR <= 0.2) return 'Good';
    if (logMAR <= 0.3) return 'Mild reduction';
    if (logMAR <= 0.5) return 'Moderate reduction';
    return 'Significant reduction - Requires attention';
  }

  /// SHORT DISTANCE - DETAILED (NO TABLE!)
  pw.Widget _buildShortDistanceDetailedSection(TestResultModel result) {
    final sd = result.shortDistance!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('NEAR VISION TEST (40cm - Reading)'),
        pw.SizedBox(height: 8),

        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Summary Row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Performance:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        _getReadingPerformance(sd.averageSimilarity),
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Best Acuity:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        sd.bestAcuity,
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Metrics
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildMetricBox(
                      'Sentences Read',
                      '${sd.correctSentences}/${sd.totalSentences}',
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      'Accuracy',
                      '${(sd.accuracy * 100).toStringAsFixed(0)}%',
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(
                    child: _buildMetricBox(
                      'Match Quality',
                      '${sd.averageSimilarity.toStringAsFixed(0)}%',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        pw.SizedBox(height: 6),
        pw.Text(
          'Clinical Note: Near vision assessed using sentence reading at 40cm. Tests reading ability and near visual acuity.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  String _getReadingPerformance(double similarity) {
    if (similarity >= 85) return 'Excellent';
    if (similarity >= 70) return 'Good';
    if (similarity >= 50) return 'Fair';
    return 'Needs Improvement';
  }

  pw.Widget _buildMetricBox(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  /// COLOR VISION - DETAILED
  pw.Widget _buildColorVisionDetailedSection(TestResultModel result) {
    final cv = result.colorVision;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('COLOR VISION TEST (Ishihara)'),
        pw.SizedBox(height: 8),

        if (cv != null) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Result:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          cv.isNormal
                              ? 'Normal Color Vision'
                              : (cv.deficiencyType
                                    .toString()), // Convert to string
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: cv.isNormal
                                ? PdfColors.green700
                                : PdfColors.orange700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Score:',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '${cv.correctAnswers}/${cv.totalPlates}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!cv.isNormal) ...[
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.orange50,
                      borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Detailed Finding:',
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.orange900,
                          ),
                        ),
                        pw.Text(
                          _getColorVisionExplanation(
                            cv.deficiencyType,
                            cv.severity,
                          ),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.orange900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Note: Ishihara test screens for red-green color deficiencies. Professional diagnosis requires full 38-plate examination.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ] else
          pw.Text(
            'Not performed',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
      ],
    );
  }

  String _getColorVisionExplanation(
    DeficiencyType? type,
    DeficiencySeverity? severity,
  ) {
    if (type == null || type == DeficiencyType.none) {
      return 'Normal color vision.';
    }
    String typeStr = type.toString().split('.').last.toUpperCase();
    String sevStr =
        severity?.toString().split('.').last.toLowerCase() ?? 'unknown';
    if (type == DeficiencyType.protan) {
      return 'Protanopia/Protanomaly ($sevStr) indicated. Red-sensitive cones are abnormal/missing, causing difficulty distinguishing red spectrums.';
    }
    if (type == DeficiencyType.deutan) {
      return 'Deuteranopia/Deuteranomaly ($sevStr) indicated. Green-sensitive cones are abnormal/missing (most common type of red-green deficiency).';
    }
    return '$typeStr deficiency ($sevStr) indicated by Ishihara screening results.';
  }

  /// AMSLER GRID - DETAILED
  pw.Widget _buildAmslerGridDetailedSection(
    TestResultModel result, {
    Uint8List? rightImageBytes,
    Uint8List? leftImageBytes,
  }) {
    final right = result.amslerGridRight;
    final left = result.amslerGridLeft;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('AMSLER GRID TEST (Macular Assessment)'),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Eye', isHeader: true),
                _buildTableCell('Findings', isHeader: true),
                _buildTableCell('Status', isHeader: true),
                _buildTableCell('Clinical Interpretation', isHeader: true),
              ],
            ),
            if (right != null)
              pw.TableRow(
                children: [
                  _buildTableCell('Right'),
                  _buildTableCell(right.resultSummary),
                  _buildTableCell(right.isNormal ? 'Normal' : 'Abnormal'),
                  _buildTableCell(_getAmslerInterpretation(right)),
                ],
              ),
            if (left != null)
              pw.TableRow(
                children: [
                  _buildTableCell('Left'),
                  _buildTableCell(left.resultSummary),
                  _buildTableCell(left.isNormal ? 'Normal' : 'Abnormal'),
                  _buildTableCell(_getAmslerInterpretation(left)),
                ],
              ),
          ],
        ),

        if ((rightImageBytes != null) || (leftImageBytes != null)) ...[
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
            children: [
              if (rightImageBytes != null)
                pw.Column(
                  children: [
                    pw.Text(
                      'Right Eye Tracing',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 140,
                      height: 140,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(rightImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              if (leftImageBytes != null)
                pw.Column(
                  children: [
                    pw.Text(
                      'Left Eye Tracing',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 140,
                      height: 140,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(leftImageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],

        pw.SizedBox(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.start,
          children: [
            pw.Text(
              'Marking Legend: ',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
            ),
            _buildPdfLegendItem('Wavy / Distortion', PdfColors.red),
            pw.SizedBox(width: 10),
            _buildPdfLegendItem('Missing Area', PdfColors.orange),
            pw.SizedBox(width: 10),
            _buildPdfLegendItem('Blurry Area', PdfColors.blue),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Note: Amsler grid screenings monitor the central visual field. Metamorphopsia (wavy lines) or Scotoma (missing areas) are clinical indicators of potential macular dysfunction and warrant prompt professional evaluation.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  /// PELLI-ROBSON - DETAILED
  pw.Widget _buildPelliRobsonDetailedSection(TestResultModel result) {
    if (result.pelliRobson == null) return pw.SizedBox();
    final pr = result.pelliRobson!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PELLI-ROBSON CONTRAST SENSITIVITY TEST'),
        pw.SizedBox(height: 8),

        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Eye', isHeader: true),
                _buildTableCell('Near (40cm)', isHeader: true),
                _buildTableCell('Distance (1m)', isHeader: true),
                _buildTableCell('Clinical Finding', isHeader: true),
              ],
            ),
            // Right Eye
            if (pr.rightEye != null)
              (() {
                final re = pr.rightEye!;
                final reNear = re.shortDistance;
                final reDist = re.longDistance;
                return pw.TableRow(
                  children: [
                    _buildTableCell('Right'),
                    _buildTableCell(
                      reNear != null
                          ? '${reNear.adjustedScore.toStringAsFixed(2)} (${reNear.category})'
                          : 'N/A',
                    ),
                    _buildTableCell(
                      reDist != null
                          ? '${reDist.adjustedScore.toStringAsFixed(2)} (${reDist.category})'
                          : 'N/A',
                    ),
                    _buildTableCell(
                      reDist != null
                          ? _getPelliRobsonInterpretation(reDist.adjustedScore)
                          : (reNear != null
                                ? _getPelliRobsonInterpretation(
                                    reNear.adjustedScore,
                                  )
                                : 'N/A'),
                    ),
                  ],
                );
              })(),
            // Left Eye
            if (pr.leftEye != null)
              (() {
                final le = pr.leftEye!;
                final leNear = le.shortDistance;
                final leDist = le.longDistance;
                return pw.TableRow(
                  children: [
                    _buildTableCell('Left'),
                    _buildTableCell(
                      leNear != null
                          ? '${leNear.adjustedScore.toStringAsFixed(2)} (${leNear.category})'
                          : 'N/A',
                    ),
                    _buildTableCell(
                      leDist != null
                          ? '${leDist.adjustedScore.toStringAsFixed(2)} (${leDist.category})'
                          : 'N/A',
                    ),
                    _buildTableCell(
                      leDist != null
                          ? _getPelliRobsonInterpretation(leDist.adjustedScore)
                          : (leNear != null
                                ? _getPelliRobsonInterpretation(
                                    leNear.adjustedScore,
                                  )
                                : 'N/A'),
                    ),
                  ],
                );
              })(),
            // Legacy / Old Format (only if present and no per-eye results)
            if (pr.rightEye == null &&
                pr.leftEye == null &&
                pr.bothEyes == null &&
                (pr.shortDistance != null || pr.longDistance != null))
              pw.TableRow(
                children: [
                  _buildTableCell('Test Result (Legacy)'),
                  _buildTableCell(
                    pr.shortDistance != null
                        ? '${pr.shortDistance!.adjustedScore.toStringAsFixed(2)} (${pr.shortDistance!.category})'
                        : 'N/A',
                  ),
                  _buildTableCell(
                    pr.longDistance != null
                        ? '${pr.longDistance!.adjustedScore.toStringAsFixed(2)} (${pr.longDistance!.category})'
                        : 'N/A',
                  ),
                  _buildTableCell(
                    pr.longDistance != null
                        ? _getPelliRobsonInterpretation(
                            pr.longDistance!.adjustedScore,
                          )
                        : (pr.shortDistance != null
                              ? _getPelliRobsonInterpretation(
                                  pr.shortDistance!.adjustedScore,
                                )
                              : 'N/A'),
                  ),
                ],
              ),
          ],
        ),

        pw.SizedBox(height: 8),
        pw.Text(
          'Clinical Summary:',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.Text(
          pr.clinicalSummary,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
        pw.Text(
          pr.userSummary,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey800),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Note: Log Contrast Sensitivity (Log CS) measures the ability to detect low contrast patterns. Higher scores indicate better sensitivity.',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    );
  }

  String _getPelliRobsonInterpretation(double score) {
    if (score >= 1.65) return 'Normal (Good)';
    if (score >= 1.35) return 'Mild impairment';
    if (score >= 1.05) return 'Moderate impairment';
    return 'Significant impairment - Action recommended';
  }

  String _getAmslerInterpretation(AmslerGridResult result) {
    if (result.isNormal) return 'Normal central vision';

    if (result.hasDistortions) {
      return 'Distortions (Metamorphopsia) detected - Urgent macular evaluation recommended';
    }

    if (result.hasMissingAreas) {
      return 'Missing areas (Scotoma) detected - Comprehensive retinal assessment advised';
    }

    return 'Abnormal findings detected - Professional eye examination recommended';
  }

  /// OVERALL ASSESSMENT
  pw.Widget _buildOverallAssessment(TestResultModel result) {
    PdfColor statusColor = result.overallStatus == TestStatus.normal
        ? PdfColors.green700
        : result.overallStatus == TestStatus.review
        ? PdfColors.orange700
        : PdfColors.red700;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: statusColor, width: 2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PROFESSIONAL RECOMMENDATION',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            result.recommendation,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildQuestionnaireSection(QuestionnaireModel q) {
    // Collect symptoms with details
    List<String> detailedComplaints = [];
    final cc = q.chiefComplaints;

    if (cc.hasRedness) {
      String detail = 'Redness';
      if (cc.rednessFollowUp?.duration != null) {
        detail += ' (${cc.rednessFollowUp!.duration})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasWatering) {
      String detail = 'Watering';
      if (cc.wateringFollowUp != null) {
        detail +=
            ' (${cc.wateringFollowUp!.days} days, ${cc.wateringFollowUp!.pattern})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasItching) {
      String detail = 'Itching';
      if (cc.itchingFollowUp != null) {
        detail +=
            ' (${cc.itchingFollowUp!.bothEyes ? 'Both eyes' : 'Single eye'}, ${cc.itchingFollowUp!.location})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasHeadache) {
      String detail = 'Headache';
      if (cc.headacheFollowUp != null) {
        detail +=
            ' (${cc.headacheFollowUp!.location}, ${cc.headacheFollowUp!.duration}, ${cc.headacheFollowUp!.painType})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasDryness) {
      String detail = 'Dryness';
      if (cc.drynessFollowUp != null) {
        detail +=
            ' (${cc.drynessFollowUp!.screenTimeHours}h screen time, AC: ${cc.drynessFollowUp!.acBlowingOnFace ? 'Yes' : 'No'})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasStickyDischarge) {
      String detail = 'Sticky Discharge';
      if (cc.dischargeFollowUp != null) {
        detail +=
            ' (${cc.dischargeFollowUp!.color}, ${cc.dischargeFollowUp!.isRegular ? 'Regular' : 'Irregular'}, since ${cc.dischargeFollowUp!.startDate})';
      }
      detailedComplaints.add(detail);
    }

    // Collect systemic illnesses
    final systemicConditions = q.systemicIllness.activeConditions;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('PATIENT HISTORY'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Symptoms
              pw.Text(
                'Current Symptoms:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                detailedComplaints.isEmpty
                    ? 'None reported'
                    : detailedComplaints.join('; '),
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 10),

              // Medical History
              pw.Text(
                'Medical History:',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                systemicConditions.isEmpty
                    ? 'No significant medical history'
                    : systemicConditions.join(', '),
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.SizedBox(height: 10),

              // Current Medications
              if (q.currentMedications != null &&
                  q.currentMedications!.isNotEmpty) ...[
                pw.Text(
                  'Current Medications:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  q.currentMedications!,
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 10),
              ],

              // Surgery History
              if (q.hasRecentSurgery) ...[
                pw.Text(
                  'Recent Surgery:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  q.surgeryDetails ?? 'Details not provided',
                  style: const pw.TextStyle(fontSize: 8),
                ),
                pw.SizedBox(height: 10),
              ],

              // Family History
              if (q.chiefComplaints.hasPreviousCataractOperation ||
                  q.chiefComplaints.hasFamilyGlaucomaHistory) ...[
                pw.Text(
                  'Family/Previous History:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  [
                    if (q.chiefComplaints.hasPreviousCataractOperation)
                      'Previous cataract operation',
                    if (q.chiefComplaints.hasFamilyGlaucomaHistory)
                      'Family history of glaucoma',
                  ].join(', '),
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1, color: PdfColors.blue800),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue800,
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  pw.Widget _buildPdfLegendItem(String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 6,
          height: 6,
          decoration: pw.BoxDecoration(color: color, shape: pw.BoxShape.circle),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 7)),
      ],
    );
  }

  Future<Uint8List?> _getImageBytes(
    String? localPath,
    String? remoteUrl,
  ) async {
    // 1. Try local path first (PRIORITY)
    if (localPath != null && localPath.isNotEmpty) {
      // Check if it's a URL stored in localPath (backward compatibility)
      if (localPath.startsWith('http')) {
        try {
          debugPrint(
            '[PdfExportService] Fetching image from URL in localPath: $localPath',
          );
          final response = await http.get(Uri.parse(localPath));
          if (response.statusCode == 200) {
            debugPrint(
              '[PdfExportService] ✅ Downloaded ${response.bodyBytes.length} bytes',
            );
            return response.bodyBytes;
          }
        } catch (e) {
          debugPrint(
            '[PdfExportService] ❌ Error fetching URL from localPath: $e',
          );
        }
      } else {
        // It's a local file path
        try {
          final file = File(localPath);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            debugPrint(
              '[PdfExportService] ✅ Read ${bytes.length} bytes from local file',
            );
            return bytes;
          } else {
            debugPrint(
              '[PdfExportService] ⚠️ Local file does not exist: $localPath',
            );
          }
        } catch (e) {
          debugPrint('[PdfExportService] ❌ Error reading local file: $e');
        }
      }
    }

    // 2. Try remote URL as fallback
    if (remoteUrl != null &&
        remoteUrl.isNotEmpty &&
        remoteUrl.startsWith('http')) {
      try {
        debugPrint('[PdfExportService] Fetching from remoteUrl: $remoteUrl');
        final response = await http.get(Uri.parse(remoteUrl));
        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          debugPrint(
            '[PdfExportService] ✅ Downloaded ${bytes.length} bytes from remote',
          );

          // HEALING: If we fetched from remote but localPath was missing/invalid,
          // try to save it locally for future use
          if (localPath != null &&
              localPath.isNotEmpty &&
              !localPath.startsWith('http')) {
            try {
              final file = File(localPath);
              final parentDir = file.parent;
              if (!await parentDir.exists()) {
                await parentDir.create(recursive: true);
              }
              await file.writeAsBytes(bytes);
              debugPrint(
                '[PdfExportService] 🩹 Healed local file at: $localPath',
              );
            } catch (e) {
              debugPrint('[PdfExportService] ⚠️ Failed to heal local file: $e');
            }
          }

          return bytes;
        }
      } catch (e) {
        debugPrint('[PdfExportService] ❌ Error fetching remote image: $e');
      }
    }

    debugPrint('[PdfExportService] ⚠️ No image bytes available');
    return null;
  }
}
