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
          pw.SizedBox(height: 16),

          // Executive Summary
          _buildExecutiveSummary(result),
          pw.SizedBox(height: 16),

          // Visual Acuity Section - DETAILED
          _buildVisualAcuityDetailedSection(result),
          pw.SizedBox(height: 16),

          // Short Distance Section - DETAILED
          if (result.shortDistance != null) ...[
            _buildShortDistanceDetailedSection(result),
            pw.SizedBox(height: 16),
          ],

          // Color Vision Section - DETAILED
          _buildColorVisionDetailedSection(result),
          pw.SizedBox(height: 16),

          // Amsler Grid Section - DETAILED
          _buildAmslerGridDetailedSection(
            result,
            rightImageBytes: amslerRightBytes,
            leftImageBytes: amslerLeftBytes,
          ),
          pw.SizedBox(height: 16),

          // Pelli-Robson Contrast Sensitivity Section - DETAILED
          if (result.pelliRobson != null) ...[
            _buildPelliRobsonDetailedSection(result),
            pw.SizedBox(height: 16),
          ],

          // Overall Assessment
          _buildOverallAssessment(result),

          // Questionnaire
          if (result.questionnaire != null) ...[
            pw.SizedBox(height: 16),
            _buildQuestionnaireSection(result.questionnaire!),
          ],
        ],
      ),
    );

    return pdf;
  }

  pw.Widget _buildHeader(pw.Context context, String? userName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1.5, color: PdfColors.blue800),
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
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                  letterSpacing: 1.2,
                ),
              ),
              pw.Text(
                'DIGITAL EYE HEALTH ASSESSMENT',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey600,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue900,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'CLINICAL REPORT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                letterSpacing: 1,
              ),
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
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PATIENT INFORMATION',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                'REPORT ID: ${result.id.length >= 8 ? result.id.substring(0, 8).toUpperCase() : result.id.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey500,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Avatar Circle
              pw.Container(
                width: 36,
                height: 36,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue100,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    (result.profileName.isNotEmpty)
                        ? result.profileName[0].toUpperCase()
                        : 'U',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              // Name & Basic Info
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      result.profileName.isNotEmpty
                          ? result.profileName
                          : (userName ?? 'N/A'),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey900,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      [
                        if (userAge != null) '$userAge yrs',
                        if (result.profileSex != null &&
                            result.profileSex!.isNotEmpty)
                          result.profileSex![0].toUpperCase() +
                              result.profileSex!.substring(1),
                        result.profileType == 'self'
                            ? 'Primary Account'
                            : 'Family Member',
                      ].join(' | '),
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
              // Date & Time Column
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    DateFormat('MMM dd, yyyy').format(result.timestamp),
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey900,
                    ),
                  ),
                  pw.Text(
                    DateFormat('h:mm a').format(result.timestamp),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ),
            ],
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

    PdfColor lightBg = result.overallStatus == TestStatus.normal
        ? PdfColor.fromInt(0xFFE8F5E9)
        : result.overallStatus == TestStatus.review
        ? PdfColor.fromInt(0xFFFFF3E0)
        : PdfColor.fromInt(0xFFFFEBEE);

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: statusColor, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ASSESSMENT SUMMARY',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  result.overallStatus.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            result.recommendation,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.grey800,
              lineSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  /// VISUAL ACUITY - DETAILED
  pw.Widget _buildVisualAcuityDetailedSection(TestResultModel result) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('DISTANCE VISION (1 METER)'),
          pw.SizedBox(height: 16),

          // Custom styled table
          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildTableCell('EYE', isHeader: true),
                    _buildTableCell('SNELLEN', isHeader: true),
                    _buildTableCell('ACCURACY', isHeader: true),
                    _buildTableCell('INTERPRETATION', isHeader: true),
                  ],
                ),
                // Right Eye
                pw.TableRow(
                  children: [
                    _buildTableCell('Right Eye'),
                    _buildTableCell(
                      result.visualAcuityRight?.snellenScore ?? 'N/A',
                      color: _getScoreColor(
                        result.visualAcuityRight?.snellenScore,
                      ),
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
                    _buildTableCell('Left Eye'),
                    _buildTableCell(
                      result.visualAcuityLeft?.snellenScore ?? 'N/A',
                      color: _getScoreColor(
                        result.visualAcuityLeft?.snellenScore,
                      ),
                    ),
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
          ),

          pw.SizedBox(height: 12),
          // Interpretation Footer
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Clinical Finding:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  _getAcuityClinicalExplanation(
                    result.visualAcuityRight?.snellenScore,
                    result.visualAcuityLeft?.snellenScore,
                  ),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Note: Measured using the Tumbling E optotype chart at 1-meter distance. Normal adult vision is 6/6.',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
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
    if (result.shortDistance == null) return pw.SizedBox();
    final sd = result.shortDistance!;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('NEAR VISION (READING)'),
          pw.SizedBox(height: 16),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue50,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'PERFORMANCE SUMMARY',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      _getReadingPerformance(
                        sd.averageSimilarity,
                      ).toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'BEST ACUITY',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue800,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      sd.bestAcuity,
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Row(
            children: [
              pw.Expanded(
                child: _buildMetricIndicator(
                  'Accuracy',
                  '${(sd.accuracy * 100).toStringAsFixed(0)}%',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricIndicator(
                  'Sentences',
                  '${sd.correctSentences}/${sd.totalSentences}',
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: _buildMetricIndicator(
                  'Match Qual.',
                  '${sd.averageSimilarity.toStringAsFixed(0)}%',
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Clinical Detail:',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  sd.isNormal
                      ? 'Normal performance. User is able to read and understand text at standard near distances.'
                      : 'Review recommended. Some difficulty in reading or lower accuracy detected at near distance.',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Note: Near vision (reading) test performed at a standard reading distance (approx. 40cm).',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  String _getReadingPerformance(double similarity) {
    if (similarity >= 85) return 'Excellent';
    if (similarity >= 70) return 'Good';
    if (similarity >= 50) return 'Fair';
    return 'Needs Improvement';
  }

  pw.Widget _buildMetricIndicator(String label, String value) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 6.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ],
      ),
    );
  }

  /// COLOR VISION - DETAILED
  pw.Widget _buildColorVisionDetailedSection(TestResultModel result) {
    final cv = result.colorVision;
    if (cv == null) return pw.SizedBox();

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('COLOR VISION ASSESSMENT'),
          pw.SizedBox(height: 16),

          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildTableCell('EYE', isHeader: true),
                    _buildTableCell('SCORE', isHeader: true),
                    _buildTableCell('STATUS', isHeader: true),
                  ],
                ),
                // Right Eye
                pw.TableRow(
                  children: [
                    _buildTableCell('Right Eye'),
                    _buildTableCell(
                      '${cv.rightEye.correctAnswers}/${cv.rightEye.totalDiagnosticPlates}',
                    ),
                    _buildTableCell(
                      cv.rightEye.status.displayName,
                      color: cv.rightEye.status == ColorVisionStatus.normal
                          ? PdfColors.green800
                          : PdfColors.orange800,
                    ),
                  ],
                ),
                // Left Eye
                pw.TableRow(
                  children: [
                    _buildTableCell('Left Eye'),
                    _buildTableCell(
                      '${cv.leftEye.correctAnswers}/${cv.leftEye.totalDiagnosticPlates}',
                    ),
                    _buildTableCell(
                      cv.leftEye.status.displayName,
                      color: cv.leftEye.status == ColorVisionStatus.normal
                          ? PdfColors.green800
                          : PdfColors.orange800,
                    ),
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: cv.isNormal
                  ? PdfColor.fromInt(0xFFE8F5E9)
                  : PdfColor.fromInt(0xFFFFF3E0),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'General Finding:',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                          color: cv.isNormal
                              ? PdfColors.green900
                              : PdfColors.orange900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        cv.isNormal
                            ? 'The patient demonstrates normal color perception across the tested red-green spectrum.'
                            : '${cv.deficiencyType.displayName} - ${cv.severity.displayName} deficiency indicated.',
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: cv.isNormal
                              ? PdfColors.green800
                              : PdfColors.orange900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (!cv.isNormal) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Detailed Clinical Explanation:',
              style: pw.TextStyle(
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.Text(
              _getColorVisionExplanation(cv.deficiencyType, cv.severity),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
          ],

          pw.SizedBox(height: 12),
          pw.Text(
            'Note: Based on Ishihara 38-plate screening methodology. A comprehensive diagnostic test by a specialist is required for confirmation.',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
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

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('AMSLER GRID (MACULAR ASSESSMENT)'),
          pw.SizedBox(height: 16),

          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Table(
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildTableCell('EYE', isHeader: true),
                    _buildTableCell('FINDINGS', isHeader: true),
                    _buildTableCell('STATUS', isHeader: true),
                    _buildTableCell('CLINICAL INTERPRETATION', isHeader: true),
                  ],
                ),
                if (right != null)
                  pw.TableRow(
                    children: [
                      _buildTableCell('Right Eye'),
                      _buildTableCell(right.resultSummary),
                      _buildTableCell(
                        right.isNormal ? 'Normal' : 'Abnormal',
                        color: right.isNormal
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                      _buildTableCell(_getAmslerInterpretation(right)),
                    ],
                  ),
                if (left != null)
                  pw.TableRow(
                    children: [
                      _buildTableCell('Left Eye'),
                      _buildTableCell(left.resultSummary),
                      _buildTableCell(
                        left.isNormal ? 'Normal' : 'Abnormal',
                        color: left.isNormal
                            ? PdfColors.green800
                            : PdfColors.red800,
                      ),
                      _buildTableCell(_getAmslerInterpretation(left)),
                    ],
                  ),
              ],
            ),
          ),

          if ((rightImageBytes != null) || (leftImageBytes != null)) ...[
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                if (rightImageBytes != null)
                  pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'RIGHT EYE TRACING',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 160,
                        height: 160,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 4,
                          verticalRadius: 4,
                          child: pw.Image(
                            pw.MemoryImage(rightImageBytes),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (leftImageBytes != null)
                  pw.Column(
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue50,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          'LEFT EYE TRACING',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Container(
                        width: 160,
                        height: 160,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.ClipRRect(
                          horizontalRadius: 4,
                          verticalRadius: 4,
                          child: pw.Image(
                            pw.MemoryImage(leftImageBytes),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],

          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.start,
            children: [
              pw.Text(
                'Marking Legend: ',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),
              _buildPdfLegendItem('Distortion', PdfColors.red),
              pw.SizedBox(width: 12),
              _buildPdfLegendItem('Missing Area', PdfColors.orange),
              pw.SizedBox(width: 12),
              _buildPdfLegendItem('Blurry Area', PdfColors.blue),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Clinical Significance: Metamorphopsia (distortion) or Scotoma (vision loss) are indicators of macular issues like ARMD or CSR. Prompt clinical evaluation is advised if markings are present.',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
                fontStyle: pw.FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// PELLI-ROBSON - DETAILED
  pw.Widget _buildPelliRobsonDetailedSection(TestResultModel result) {
    if (result.pelliRobson == null) return pw.SizedBox();
    final pr = result.pelliRobson!;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('CONTRAST SENSITIVITY (PELLI-ROBSON)'),
          pw.SizedBox(height: 16),

          pw.Container(
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Table(
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _buildTableCell('EYE', isHeader: true),
                    _buildTableCell('NEAR (40CM)', isHeader: true),
                    _buildTableCell('DIST (1M)', isHeader: true),
                    _buildTableCell('FINDING', isHeader: true),
                  ],
                ),
                // Right Eye
                if (pr.rightEye != null)
                  (() {
                    final re = pr.rightEye!;
                    return pw.TableRow(
                      children: [
                        _buildTableCell('Right Eye'),
                        _buildTableCell(
                          re.shortDistance != null
                              ? '${re.shortDistance!.adjustedScore.toStringAsFixed(2)} LogCS'
                              : 'N/A',
                        ),
                        _buildTableCell(
                          re.longDistance != null
                              ? '${re.longDistance!.adjustedScore.toStringAsFixed(2)} LogCS'
                              : 'N/A',
                        ),
                        _buildTableCell(
                          re.longDistance != null
                              ? _getPelliRobsonInterpretation(
                                  re.longDistance!.adjustedScore,
                                )
                              : (re.shortDistance != null
                                    ? _getPelliRobsonInterpretation(
                                        re.shortDistance!.adjustedScore,
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
                    return pw.TableRow(
                      children: [
                        _buildTableCell('Left Eye'),
                        _buildTableCell(
                          le.shortDistance != null
                              ? '${le.shortDistance!.adjustedScore.toStringAsFixed(2)} LogCS'
                              : 'N/A',
                        ),
                        _buildTableCell(
                          le.longDistance != null
                              ? '${le.longDistance!.adjustedScore.toStringAsFixed(2)} LogCS'
                              : 'N/A',
                        ),
                        _buildTableCell(
                          le.longDistance != null
                              ? _getPelliRobsonInterpretation(
                                  le.longDistance!.adjustedScore,
                                )
                              : (le.shortDistance != null
                                    ? _getPelliRobsonInterpretation(
                                        le.shortDistance!.adjustedScore,
                                      )
                                    : 'N/A'),
                        ),
                      ],
                    );
                  })(),
              ],
            ),
          ),

          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Assessment Summary:',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  pr.clinicalSummary,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Note: Contrast sensitivity reflects the eye\'s ability to distinguish an object from its background. Impairment can affect mobility and reading in low light.',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey500,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
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
        ? PdfColors.blue800
        : result.overallStatus == TestStatus.review
        ? PdfColors.orange800
        : PdfColors.red800;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(20),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey300, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 24,
                height: 24,
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    'i',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 10),
              pw.Text(
                'PROFESSIONAL CLINICAL ADVICE',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
            ),
            child: pw.Text(
              result.recommendation,
              style: pw.TextStyle(
                fontSize: 10,
                color: PdfColors.grey900,
                lineSpacing: 2,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'This assessment is based on digital screening results. For a definitive diagnosis, please consult an ophthalmologist.',
            style: pw.TextStyle(
              fontSize: 8,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey600,
            ),
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
      if (cc.rednessFollowUp?.duration != null)
        detail += ' (${cc.rednessFollowUp!.duration})';
      detailedComplaints.add(detail);
    }
    if (cc.hasWatering) {
      String detail = 'Watering';
      if (cc.wateringFollowUp != null)
        detail +=
            ' (${cc.wateringFollowUp!.days}d, ${cc.wateringFollowUp!.pattern})';
      detailedComplaints.add(detail);
    }
    if (cc.hasItching) {
      String detail = 'Itching';
      if (cc.itchingFollowUp != null)
        detail +=
            ' (${cc.itchingFollowUp!.bothEyes ? 'Both' : 'Single'}, ${cc.itchingFollowUp!.location})';
      detailedComplaints.add(detail);
    }
    if (cc.hasHeadache) {
      String detail = 'Headache';
      if (cc.headacheFollowUp != null)
        detail +=
            ' (${cc.headacheFollowUp!.location}, ${cc.headacheFollowUp!.painType})';
      detailedComplaints.add(detail);
    }
    if (cc.hasDryness) {
      String detail = 'Dryness';
      if (cc.drynessFollowUp != null)
        detail += ' (${cc.drynessFollowUp!.screenTimeHours}h/d)';
      detailedComplaints.add(detail);
    }
    if (cc.hasStickyDischarge) {
      String detail = 'Sticky Discharge';
      if (cc.dischargeFollowUp != null)
        detail += ' (${cc.dischargeFollowUp!.color})';
      detailedComplaints.add(detail);
    }

    final systemicConditions = q.systemicIllness.activeConditions;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: PdfColors.grey200, width: 1),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('PATIENT MEDICAL HISTORY'),
          pw.SizedBox(height: 16),

          _buildHistoryRow(
            'Symptoms',
            detailedComplaints.isEmpty
                ? 'None reported'
                : detailedComplaints.join('; '),
          ),
          _buildHistoryRow(
            'Systemic Conditions',
            systemicConditions.isEmpty
                ? 'No significant history'
                : systemicConditions.join(', '),
          ),

          if (q.currentMedications != null && q.currentMedications!.isNotEmpty)
            _buildHistoryRow('Medications', q.currentMedications!),

          if (q.hasRecentSurgery)
            _buildHistoryRow(
              'Recent Surgery',
              q.surgeryDetails ?? 'Yes (Details not provided)',
            ),

          if (q.chiefComplaints.hasPreviousCataractOperation ||
              q.chiefComplaints.hasFamilyGlaucomaHistory)
            _buildHistoryRow(
              'Ocular Hist.',
              [
                if (q.chiefComplaints.hasPreviousCataractOperation)
                  'Cataract Operation',
                if (q.chiefComplaints.hasFamilyGlaucomaHistory)
                  'Family Glaucoma Hist.',
              ].join(', '),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildHistoryRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 80,
            child: pw.Text(
              label.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8.5,
                color: PdfColors.grey900,
                lineSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  PdfColor _getScoreColor(String? score) {
    if (score == null) return PdfColors.grey900;
    if (score == '6/6') return PdfColors.green800;
    if (score == '6/12' || score == '6/18') return PdfColors.orange800;
    return PdfColors.red800;
  }

  pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    PdfColor? color,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 8 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.blue900 : PdfColors.grey900),
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
