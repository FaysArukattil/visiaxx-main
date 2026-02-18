import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'file_manager_service.dart';

import '../../data/models/test_result_model.dart';
import '../../data/models/questionnaire_model.dart';
import '../../data/models/amsler_grid_result.dart';
import '../../data/models/color_vision_result.dart';
import '../../data/models/mobile_refractometry_result.dart';
import '../../data/models/pelli_robson_result.dart';
import '../../data/models/refraction_prescription_model.dart';
import '../../data/models/shadow_test_result.dart';
import '../../data/models/stereopsis_result.dart';
import '../../data/models/visual_field_result.dart';
import '../../data/models/eye_hydration_result.dart';
import '../../data/models/cover_test_result.dart';
import '../../data/models/torchlight_test_result.dart';
import 'symptom_detector_service.dart';

/// Service for generating PDF reports of test results
class PdfExportService {
  /// Generate and download PDF report to device's Downloads folder
  Future<String> generateAndDownloadPdf(
    TestResultModel result, {
    String subFolder = 'Single_Reports',
  }) async {
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
      final savedPath = await _saveToDownloads(
        pdfBytes,
        filename,
        subFolder: subFolder,
      );
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

  /// Save file to Downloads folder (works on Android & iOS)
  Future<String> _saveToDownloads(
    Uint8List bytes,
    String filename, {
    String subFolder = 'Single_Reports',
  }) async {
    try {
      // Use FileManagerService to get the correct download directory for the platform
      final baseDir = await FileManagerService.getDownloadDirectory();

      // Build the target directory path: Downloads/Visiaxx_Reports/subFolder
      // Ensure subFolder doesn't have leading/trailing slashes
      final normalizedSubFolder = subFolder.replaceAll(
        RegExp(r'^[/\\]|[/\\]$'),
        '',
      );
      final targetPath = '${baseDir.path}/Visiaxx_Reports/$normalizedSubFolder';
      final targetDir = Directory(targetPath);

      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      final file = File('${targetDir.path}/$filename');
      await file.writeAsBytes(bytes);
      debugPrint('[PdfExportService] ✅ Saved to: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint(
        '[PdfExportService] ❌ Save to downloads failed: $e. Falling back to app directory.',
      );
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

  /// Get the expected file path for a test result PDF
  Future<String> getExpectedFilePath(
    TestResultModel result, {
    String subFolder = 'Single_Reports',
  }) async {
    final name = result.profileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final age = result.profileAge != null ? '${result.profileAge}' : 'NA';
    final dateStr = DateFormat('dd-MM-yyyy').format(result.timestamp);
    final timeStr = DateFormat('HH-mm').format(result.timestamp);
    final filename = 'Visiaxx_${name}_${age}_${dateStr}_$timeStr.pdf';

    try {
      final baseDir = await FileManagerService.getDownloadDirectory();
      final normalizedSubFolder = subFolder.replaceAll(
        RegExp(r'^[/\\]|[/\\]$'),
        '',
      );
      return '${baseDir.path}/Visiaxx_Reports/$normalizedSubFolder/$filename';
    } catch (e) {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}/$filename';
    }
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

    // Shadow Test images
    Uint8List? shadowRightBytes;
    Uint8List? shadowLeftBytes;

    if (result.shadowTest != null) {
      shadowRightBytes = await _getImageBytes(
        result.shadowTest!.rightEye.imagePath,
        result.shadowTest!.rightEye.awsImageUrl,
      );
      shadowLeftBytes = await _getImageBytes(
        result.shadowTest!.leftEye.imagePath,
        result.shadowTest!.leftEye.awsImageUrl,
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 30, vertical: 30),
        header: (context) => _buildHeader(context, result.profileName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Title Section
          _buildTitleSection(result, result.profileName, result.profileAge),
          pw.SizedBox(height: 12),

          // Executive Summary
          _buildExecutiveSummary(result),
          pw.SizedBox(height: 12),

          // Visual Acuity Section - DETAILED
          if (result.visualAcuityRight != null ||
              result.visualAcuityLeft != null) ...[
            _buildVisualAcuityDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Short Distance Section - DETAILED
          if (result.shortDistance != null) ...[
            _buildShortDistanceDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Color Vision Section - DETAILED
          if (result.colorVision != null) ...[
            _buildColorVisionDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Amsler Grid Section - DETAILED
          if (result.amslerGridRight != null ||
              result.amslerGridLeft != null) ...[
            _buildAmslerGridDetailedSection(
              result,
              rightImageBytes: amslerRightBytes,
              leftImageBytes: amslerLeftBytes,
            ),
            pw.SizedBox(height: 12),
          ],

          // Pelli-Robson Contrast Sensitivity Section - DETAILED
          if (result.pelliRobson != null) ...[
            _buildPelliRobsonDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Mobile Refractometry Section - DETAILED
          if (result.mobileRefractometry != null) ...[
            _buildMobileRefractometryDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Shadow Test Section - DETAILED
          if (result.shadowTest != null) ...[
            _buildShadowTestDetailedSection(
              result,
              rightImageBytes: shadowRightBytes,
              leftImageBytes: shadowLeftBytes,
            ),
            pw.SizedBox(height: 12),
          ],

          // Eye Hydration Section - DETAILED
          if (result.eyeHydration != null) ...[
            _buildEyeHydrationDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Visual Field Section - DETAILED
          if (result.visualFieldRight != null ||
              result.visualFieldLeft != null ||
              result.visualField != null) ...[
            _buildVisualFieldDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Stereopsis Section - DETAILED
          if (result.stereopsis != null) ...[
            _buildStereopsisDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Cover Test Section - DETAILED
          if (result.coverTest != null) ...[
            _buildCoverTestDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Torchlight Examination Section - DETAILED
          if (result.torchlight != null) ...[
            _buildTorchlightDetailedSection(result),
            pw.SizedBox(height: 12),
          ],

          // Practitioner Prescription Section (if verified)
          if (result.refractionPrescription != null &&
              result.refractionPrescription!.includeInResults) ...[
            _buildRefractionPrescriptionSection(result),
            pw.SizedBox(height: 12),
          ],

          // Symptom Detector Section
          _buildSymptomDetectorSection(result),
          pw.SizedBox(height: 12),

          // Questionnaire
          if (result.questionnaire != null) ...[
            pw.SizedBox(height: 12),
            _buildQuestionnaireSection(result.questionnaire!),
          ],

          // Overall Assessment
          pw.SizedBox(height: 12),
          _buildOverallAssessment(result),
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
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
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
                  color: PdfColors.blueGrey900,
                  letterSpacing: 2,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'HEALTH ANALYTICS & DIAGNOSTICS',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey600,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'CONFIDENTIAL CLINICAL REPORT',
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'VIS-2026-XQZ', // Placeholder for actual report versioning if needed
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey300),
        ),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Visiaxx Digital Health - Validated Medical Documentation',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey400,
                ),
              ),
              pw.Text(
                'PAGE ${context.pageNumber} OF ${context.pagesCount}',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.grey400,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'DISCLAIMER: This report is based on digital vision screening tools and is not a substitute for a comprehensive professional eye examination. '
            'Final clinical interpretation and management decisions should be made by a qualified healthcare professional in conjunction with our technical data.',
            style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey400),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Generate PDF bytes without saving (for bulk downloads)
  Future<Uint8List> generatePdfBytes(TestResultModel result) async {
    final pdf = await _buildPdfDocument(result);
    return await pdf.save();
  }

  pw.Widget _buildTitleSection(
    TestResultModel result,
    String? userName,
    int? userAge,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 16),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Bio Data Column
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PATIENT NAME',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  result.profileName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey900,
                  ),
                ),
                pw.SizedBox(height: 12),
                pw.Row(
                  children: [
                    _buildPatientDetailItem('AGE', '${userAge ?? 'N/A'} Yrs'),
                    pw.SizedBox(width: 24),
                    _buildPatientDetailItem(
                      'GENDER',
                      (result.profileSex?.isNotEmpty ?? false)
                          ? result.profileSex![0].toUpperCase() +
                                result.profileSex!.substring(1)
                          : 'N/A',
                    ),
                    pw.SizedBox(width: 24),
                    _buildPatientDetailItem(
                      'ID',
                      result.id.length >= 8
                          ? result.id.substring(0, 8).toUpperCase()
                          : result.id.toUpperCase(),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Report Info Column
          pw.Expanded(
            flex: 1,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'EXAMINATION DATE',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey500,
                    letterSpacing: 1,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  DateFormat('MMM dd, yyyy').format(result.timestamp),
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  DateFormat('h:mm a').format(result.timestamp),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 12),
                _buildPatientDetailItem(
                  'ACCOUNT TYPE',
                  result.profileType == 'self' ? 'Primary' : 'Member',
                  alignEnd: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPatientDetailItem(
    String label,
    String value, {
    bool alignEnd = false,
  }) {
    return pw.Column(
      crossAxisAlignment: alignEnd
          ? pw.CrossAxisAlignment.end
          : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 6,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey400,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 1),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ],
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
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'ASSESSMENT OVERVIEW',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: pw.BoxDecoration(
                  color: statusColor,
                  borderRadius: pw.BorderRadius.circular(3),
                ),
                child: pw.Text(
                  result.overallStatus.label.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            result.recommendation,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColors.blueGrey900,
              lineSpacing: 1.8,
            ),
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
        pw.SizedBox(height: 6),
        _buildSectionHeader('DISTANCE VISION (1 METER)'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                _buildTableCell('EYE', isHeader: true),
                _buildTableCell('SNELLEN SCORE', isHeader: true),
                _buildTableCell('ACCURACY', isHeader: true),
                _buildTableCell('INTERPRETATION', isHeader: true),
              ],
            ),
            // Right Eye
            pw.TableRow(
              children: [
                _buildTableCell('OD (Right Eye)'),
                _buildTableCell(
                  result.visualAcuityRight?.snellenScore ?? 'N/A',
                  color: _getScoreColor(result.visualAcuityRight?.snellenScore),
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
                _buildTableCell('OS (Left Eye)'),
                _buildTableCell(
                  result.visualAcuityLeft?.snellenScore ?? 'N/A',
                  color: _getScoreColor(result.visualAcuityLeft?.snellenScore),
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
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLINICAL FINDING: ',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  _getAcuityClinicalExplanation(
                    result.visualAcuityRight?.snellenScore,
                    result.visualAcuityLeft?.snellenScore,
                  ),
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.blueGrey700,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Note: Measured using the Tumbling E optotype chart at 1-meter distance. Normal adult vision is 6/6.',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey400,
            fontStyle: pw.FontStyle.italic,
          ),
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
    if (result.shortDistance == null) return pw.SizedBox();
    final sd = result.shortDistance!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('NEAR VISION (READING)'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricTile(
                'ACCURACY',
                '${(sd.accuracy * 100).toStringAsFixed(0)}%',
                _getReadingPerformance(sd.averageSimilarity),
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'SENTENCES',
                '${sd.correctSentences}/${sd.totalSentences}',
                'CORRECTLY READ',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'BEST ACUITY',
                sd.bestAcuity,
                'NEAR SCORE',
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLINICAL DETAIL: ',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  sd.isNormal
                      ? 'N1 (Normal) performance. User is able to read and understand text at standard near distances.'
                      : 'Review recommended. Some difficulty in reading or lower accuracy detected at near distance.',
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.blueGrey600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMetricTile(String label, String value, String subtext) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey50, width: 0.5),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 6,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey500,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            subtext.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey400,
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

  pw.Widget _buildColorVisionDetailedSection(TestResultModel result) {
    final cv = result.colorVision;
    if (cv == null) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('COLOR VISION ASSESSMENT'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1.2),
            3: const pw.FlexColumnWidth(1.8),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                _buildTableCell('EYE', isHeader: true),
                _buildTableCell('PLATES', isHeader: true),
                _buildTableCell('SEVERITY', isHeader: true),
                _buildTableCell('DEFICIENCY TYPE', isHeader: true),
              ],
            ),
            // Right Eye
            pw.TableRow(
              children: [
                _buildTableCell('OD (Right Eye)'),
                _buildTableCell(
                  '${cv.rightEye.correctAnswers}/${cv.rightEye.totalDiagnosticPlates}',
                ),
                _buildTableCell(
                  cv.rightEye.status.displayName,
                  color: cv.rightEye.status == ColorVisionStatus.normal
                      ? PdfColors.green800
                      : PdfColors.orange800,
                ),
                _buildTableCell(
                  cv.rightEye.detectedType?.displayName ??
                      (cv.rightEye.status == ColorVisionStatus.normal
                          ? 'None'
                          : 'Undetermined'),
                ),
              ],
            ),
            // Left Eye
            pw.TableRow(
              children: [
                _buildTableCell('OS (Left Eye)'),
                _buildTableCell(
                  '${cv.leftEye.correctAnswers}/${cv.leftEye.totalDiagnosticPlates}',
                ),
                _buildTableCell(
                  cv.leftEye.status.displayName,
                  color: cv.leftEye.status == ColorVisionStatus.normal
                      ? PdfColors.green800
                      : PdfColors.orange800,
                ),
                _buildTableCell(
                  cv.leftEye.detectedType?.displayName ??
                      (cv.leftEye.status == ColorVisionStatus.normal
                          ? 'None'
                          : 'Undetermined'),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: cv.isNormal ? PdfColors.green50 : PdfColors.orange50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'INTERPRETATION: ',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: cv.isNormal ? PdfColors.green900 : PdfColors.orange900,
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  cv.isNormal
                      ? 'The patient demonstrates normal color perception across the tested red-green spectrum.'
                      : '${cv.deficiencyType.displayName} - ${cv.severity.displayName} deficiency indicated.',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: cv.isNormal
                        ? PdfColors.green800
                        : PdfColors.orange900,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!cv.isNormal) ...[
          pw.SizedBox(height: 6),
          _buildDetailRow(
            'CLINICAL DETAIL',
            _getColorVisionExplanation(cv.deficiencyType, cv.severity),
          ),
        ],
        pw.SizedBox(height: 8),
        pw.Text(
          'Note: Based on Ishihara 38-plate screening methodology. A comprehensive diagnostic test by a specialist is required for confirmation.',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey400,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 70,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 6,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey400,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(
                fontSize: 7,
                color: PdfColors.blueGrey700,
              ),
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
        pw.SizedBox(height: 6),
        _buildSectionHeader('AMSLER GRID (MACULAR ASSESSMENT)'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
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
                  _buildTableCell('OD (Right Eye)'),
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
                  _buildTableCell('OS (Left Eye)'),
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
    );
  }

  /// PELLI-ROBSON - DETAILED
  pw.Widget _buildPelliRobsonDetailedSection(TestResultModel result) {
    if (result.pelliRobson == null) return pw.SizedBox();
    final PelliRobsonResult pr = result.pelliRobson!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('CONTRAST SENSITIVITY (PELLI-ROBSON)'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
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
                    _buildTableCell('OD (Right Eye)'),
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
                    _buildTableCell('OS (Left Eye)'),
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
        pw.SizedBox(height: 12),
        _buildDetailRow('SUMMARY', pr.clinicalSummary),
        pw.SizedBox(height: 6),
        pw.Text(
          'Note: Contrast sensitivity reflects the eye\'s ability to distinguish an object from its background. Impairment can affect mobility and reading in low light.',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey400,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildMobileRefractometryDetailedSection(TestResultModel result) {
    if (result.mobileRefractometry == null) return pw.SizedBox();
    final refract = result.mobileRefractometry!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('MOBILE REFRACTOMETRY AR'),
        pw.SizedBox(height: 12),

        // Independent Eye Rows
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (refract.rightEye != null)
              pw.Expanded(
                child: _buildRefractionEyePdfCard(
                  'RIGHT EYE (OD)',
                  refract.rightEye!,
                  PdfColors.blueGrey800,
                  result.profileAge,
                ),
              ),
            if (refract.rightEye != null && refract.leftEye != null)
              pw.SizedBox(width: 12),
            if (refract.leftEye != null)
              pw.Expanded(
                child: _buildRefractionEyePdfCard(
                  'LEFT EYE (OS)',
                  refract.leftEye!,
                  PdfColors.blueGrey800,
                  result.profileAge,
                ),
              ),
          ],
        ),
        pw.SizedBox(height: 12),

        if (refract.criticalAlert) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.red50,
              border: pw.Border.all(color: PdfColors.red100, width: 0.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              children: [
                pw.Container(
                  width: 10,
                  height: 10,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.red700,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      '!',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Text(
                  'CRITICAL ALERT: SIGNIFICANT REFRACTIVE ERROR DETECTED',
                  style: pw.TextStyle(
                    color: PdfColors.red800,
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 8),
        ],

        if (refract.healthWarnings.isNotEmpty) ...[
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLINICAL OBSERVATIONS:',
                style: pw.TextStyle(
                  fontSize: 7,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                ),
              ),
              pw.SizedBox(height: 4),
              ...refract.healthWarnings.map(
                (warning) => pw.Bullet(
                  text: warning,
                  style: const pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.blueGrey600,
                  ),
                  bulletSize: 2,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _buildRefractionEyePdfCard(
    String label,
    MobileRefractometryEyeResult res,
    PdfColor color,
    int? age,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: _buildRefractionEyePdfBlock(label, res, color, age),
    );
  }

  pw.Widget _buildRefractionEyePdfBlock(
    String label,
    MobileRefractometryEyeResult res,
    PdfColor color,
    int? age,
  ) {
    // Replicate interpretation logic from UI
    final sph = double.tryParse(res.sphere) ?? 0.0;
    final cyl = double.tryParse(res.cylinder) ?? 0.0;
    final sphAbs = sph.abs();
    final cylAbs = cyl.abs();

    String condition = 'Healthy Vision';
    String reduction = '';
    String description = 'This eye shows no significant refractive issues.';

    if (sph < -0.25) {
      String level = sphAbs > 6.0
          ? 'High'
          : (sphAbs > 3.0 ? 'Moderate' : 'Low');
      condition = '$level Myopia';
      description = 'Distance objects may appear blurry or out of focus.';
    } else if (sph > 0.25) {
      String level = sphAbs > 6.0
          ? 'High'
          : (sphAbs > 3.0 ? 'Moderate' : 'Low');
      condition = '$level Hyperopia';
      description =
          'May experience blurriness or strain during close-up tasks.';
    }

    if (cylAbs > 0.25) {
      String level = cylAbs > 1.0 ? 'Significant' : 'Mild';
      if (condition == 'Healthy Vision') {
        condition = '$level Astigmatism';
        description = 'Vision may be distorted at all distances.';
      } else {
        condition += ' with Astigmatism';
      }
    }

    final maxError = math.max(sphAbs, cylAbs);
    if (maxError > 6.0) {
      reduction = 'Heavy reduction';
    } else if (maxError > 3.0) {
      reduction = 'Moderate reduction';
    } else if (maxError > 0.25) {
      reduction = 'Slight reduction';
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Header Row
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Expanded(
              child: pw.Row(
                children: [
                  pw.Text(
                    label,
                    style: pw.TextStyle(
                      fontSize: 9, // Slightly smaller to prevent label overflow
                      fontWeight: pw.FontWeight.bold,
                      color: color,
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Flexible(
                    child: pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1.5,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius: pw.BorderRadius.circular(3),
                      ),
                      child: pw.Text(
                        condition.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Text(
              'ACCURACY: ${res.accuracy}%',
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // Prescription Table
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey100, width: 0.5),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey50),
              children: [
                _buildTableCell('SPH', isHeader: true),
                _buildTableCell('CYL', isHeader: true),
                _buildTableCell('AXIS', isHeader: true),
                if (age != null &&
                    age >= 40 &&
                    double.tryParse(res.addPower) != null &&
                    double.parse(res.addPower) > 0)
                  _buildTableCell('ADD', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell(res.sphere),
                _buildTableCell(res.cylinder),
                _buildTableCell('${res.axis}°'),
                if (age != null &&
                    age >= 40 &&
                    double.tryParse(res.addPower) != null &&
                    double.parse(res.addPower) > 0)
                  _buildTableCell(
                    '+${res.addPower.replaceFirst(RegExp(r'^\++'), '')}',
                  ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),

        // Layman Interpretation
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 3,
              height: 25,
              decoration: pw.BoxDecoration(
                color: color, // Removed .withValues(alpha: 2),
              ),
            ),
            pw.SizedBox(width: 8),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    description,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey800,
                    ),
                  ),
                  if (reduction.isNotEmpty)
                    pw.Text(
                      'Impact: $reduction status detected based on clinical results.',
                      style: const pw.TextStyle(
                        fontSize: 8,
                        color: PdfColors.grey600,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// SHADOW TEST - DETAILED
  pw.Widget _buildShadowTestDetailedSection(
    TestResultModel result, {
    Uint8List? rightImageBytes,
    Uint8List? leftImageBytes,
  }) {
    if (result.shadowTest == null) return pw.SizedBox();
    final st = result.shadowTest!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('VAN HERICK SHADOW TEST (ANGLE ASSESSMENT)'),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _buildEyeShadowDetail(
                'RIGHT EYE (OD)',
                st.rightEye,
                rightImageBytes,
                PdfColors.blueGrey700,
              ),
            ),
            pw.SizedBox(width: 20),
            pw.Expanded(
              child: _buildEyeShadowDetail(
                'LEFT EYE (OS)',
                st.leftEye,
                leftImageBytes,
                PdfColors.blueGrey700,
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            color: PdfColors.blueGrey50,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLINICAL INTERPRETATION',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey700,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                st.interpretation,
                style: pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.blueGrey900,
                  lineSpacing: 1.2,
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                'CLINICAL RECOMMENDATION',
                style: pw.TextStyle(
                  fontSize: 7.5,
                  fontWeight: pw.FontWeight.bold,
                  color: st.requiresReferral
                      ? PdfColors.red700
                      : PdfColors.green700,
                  letterSpacing: 0.5,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: st.requiresReferral
                      ? PdfColors.red50
                      : PdfColors.green50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  st.conclusion.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: st.requiresReferral
                        ? PdfColors.red800
                        : PdfColors.green800,
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text(
                    'OVERALL RISK: ',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    st.overallRisk,
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: st.requiresReferral
                          ? PdfColors.red700
                          : PdfColors.green700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildEyeShadowDetail(
    String label,
    EyeGrading eye,
    Uint8List? imageBytes,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: pw.BoxDecoration(
            color: eye.grade.grade <= 2 ? PdfColors.red50 : PdfColors.green50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            'VAN HERICK GRADE: ${eye.grade.grade}',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: eye.grade.grade <= 2
                  ? PdfColors.red700
                  : PdfColors.green700,
            ),
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Status: ${eye.grade.angleStatus}',
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey800,
          ),
        ),
        pw.Text(
          'Risk: ${eye.grade.glaucomaRisk}',
          style: pw.TextStyle(
            fontSize: 7.5,
            color: eye.grade.grade <= 2 ? PdfColors.red700 : PdfColors.green700,
          ),
        ),
        pw.Text(
          'Shadow Ratio: ${eye.shadowRatio?.toStringAsFixed(2) ?? "N/A"} (${eye.grade.ratio})',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 8),
        if (imageBytes != null)
          pw.Container(
            height: 100,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey200),
            ),
            child: pw.Image(pw.MemoryImage(imageBytes), fit: pw.BoxFit.cover),
          )
        else
          pw.Container(
            height: 100,
            width: double.infinity,
            decoration: pw.BoxDecoration(color: PdfColors.grey100),
            child: pw.Center(
              child: pw.Text(
                'IMAGE NOT AVAILABLE',
                style: pw.TextStyle(fontSize: 6, color: PdfColors.grey400),
              ),
            ),
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

  /// EYE HYDRATION - DETAILED
  pw.Widget _buildEyeHydrationDetailedSection(TestResultModel result) {
    if (result.eyeHydration == null) return pw.SizedBox();
    final EyeHydrationResult hydration = result.eyeHydration!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('EYE HYDRATION & BLINK ANALYTICS'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricTile(
                'BLINK RATE',
                '${hydration.averageBlinksPerMinute.toStringAsFixed(1)} BPM',
                'AVERAGE PER MINUTE',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'BLINK COUNT',
                '${hydration.blinkCount}',
                'TOTAL DETECTED',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'DURATION',
                '${hydration.totalTestTime.inSeconds}s',
                'TEST TIME',
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: hydration.status == EyeHydrationStatus.normal
                ? PdfColors.green50
                : (hydration.status == EyeHydrationStatus.suspicious
                      ? PdfColors.orange50
                      : PdfColors.red50),
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: hydration.status == EyeHydrationStatus.normal
                  ? PdfColors.green100
                  : (hydration.status == EyeHydrationStatus.suspicious
                        ? PdfColors.orange100
                        : PdfColors.red100),
              width: 0.5,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(
                    'STATUS: ${hydration.status.label.toUpperCase()}',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: hydration.status == EyeHydrationStatus.normal
                          ? PdfColors.green800
                          : (hydration.status == EyeHydrationStatus.suspicious
                                ? PdfColors.orange800
                                : PdfColors.red800),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                hydration.status.description,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.blueGrey800,
                  lineSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (hydration.recommendations.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'TARGETED RECOMMENDATIONS',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
              letterSpacing: 0.5,
            ),
          ),
          pw.SizedBox(height: 6),
          ...hydration.recommendations.map(
            (rec) => pw.Bullet(
              text: rec,
              style: const pw.TextStyle(fontSize: 8),
              bulletSize: 2,
            ),
          ),
        ],
      ],
    );
  }

  /// STEREOPSIS - DETAILED
  pw.Widget _buildStereopsisDetailedSection(TestResultModel result) {
    if (result.stereopsis == null) return pw.SizedBox();
    final StereopsisResult stereo = result.stereopsis!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('STEREOPSIS (DEPTH PERCEPTION)'),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(
              child: _buildMetricTile(
                'SCORE',
                '${stereo.score}/${stereo.totalRounds}',
                'SUCCESSFUL TRIALS',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'ACCURACY',
                '${stereo.percentage.toStringAsFixed(0)}%',
                'RESPONSE RATE',
              ),
            ),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _buildMetricTile(
                'GRADE',
                stereo.grade.label.toUpperCase(),
                'DEPTH QUALITY',
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: stereo.stereopsisPresent
                ? PdfColors.green50
                : PdfColors.red50,
            borderRadius: pw.BorderRadius.circular(6),
            border: pw.Border.all(
              color: stereo.stereopsisPresent
                  ? PdfColors.green100
                  : PdfColors.red100,
              width: 0.5,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'CLINICAL FINDING: ${stereo.grade.description}',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: stereo.stereopsisPresent
                      ? PdfColors.green800
                      : PdfColors.red800,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text(
                stereo.recommendation,
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.blueGrey800,
                  lineSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'Note: Stereopsis refers to the brain\'s ability to perceive depth and 3D structures from two slightly different images from each eye.',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey400,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// OVERALL ASSESSMENT
  pw.Widget _buildOverallAssessment(TestResultModel result) {
    PdfColor statusColor = result.overallStatus == TestStatus.normal
        ? PdfColors.blueGrey700
        : result.overallStatus == TestStatus.review
        ? PdfColors.orange700
        : PdfColors.red700;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blueGrey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                width: 14,
                height: 14,
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
                      fontSize: 8,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 8),
              pw.Text(
                'CLINICAL INTERPRETATION & ADVICE',
                style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            result.recommendation,
            style: pw.TextStyle(
              fontSize: 9.5,
              color: PdfColors.blueGrey900,
              lineSpacing: 1.8,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Important: This assessment is generated through digital screening protocols. For a definitive medical diagnosis or if symptoms persist, immediate consultation with an ophthalmologist is required.',
            style: pw.TextStyle(
              fontSize: 6,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.blueGrey400,
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
      if (cc.rednessFollowUp?.duration != null &&
          cc.rednessFollowUp!.duration.isNotEmpty) {
        detail += ' (${cc.rednessFollowUp!.duration})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasWatering) {
      String detail = 'Watering';
      if (cc.wateringFollowUp != null) {
        detail +=
            ' (${cc.wateringFollowUp!.days}d, ${cc.wateringFollowUp!.pattern})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasItching) {
      String detail = 'Itching';
      if (cc.itchingFollowUp != null) {
        detail +=
            ' (${cc.itchingFollowUp!.bothEyes ? 'Both Eyes' : 'Single Eye'}, ${cc.itchingFollowUp!.location})';
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
            ' (${cc.drynessFollowUp!.screenTimeHours}h/d, ${cc.drynessFollowUp!.acBlowingOnFace ? 'AC on face' : 'No AC'})';
      }
      detailedComplaints.add(detail);
    }
    if (cc.hasStickyDischarge) {
      String detail = 'Sticky Discharge';
      if (cc.dischargeFollowUp != null) {
        detail +=
            ' (${cc.dischargeFollowUp!.color}, ${cc.dischargeFollowUp!.isRegular ? 'Recurring' : 'One-time'}, Start: ${cc.dischargeFollowUp!.startDate})';
      }
      detailedComplaints.add(detail);
    }

    final systemicConditions = q.systemicIllness.activeConditions;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 8),
        _buildSectionHeader('PATIENT ADVICE & HISTORY'),
        pw.SizedBox(height: 12),
        _buildHistoryRow(
          'REPORTED SYMPTOMS',
          detailedComplaints.isEmpty
              ? 'None reported'
              : detailedComplaints.join('; '),
        ),
        _buildHistoryRow(
          'SYSTEMIC CONDITIONS',
          systemicConditions.isEmpty
              ? 'No significant history'
              : systemicConditions.join(', '),
        ),
        if (q.currentMedications != null && q.currentMedications!.isNotEmpty)
          _buildHistoryRow('CURRENT MEDICATIONS', q.currentMedications!),
        if (q.hasRecentSurgery)
          _buildHistoryRow(
            'RECENT SURGERY',
            q.surgeryDetails ?? 'Yes (Details not provided)',
          ),
        if (q.chiefComplaints.hasPreviousCataractOperation ||
            q.chiefComplaints.hasFamilyGlaucomaHistory)
          _buildHistoryRow(
            'OCULAR HISTORY',
            [
              q.chiefComplaints.hasPreviousCataractOperation
                  ? 'Cataract Operation'
                  : null,
              q.chiefComplaints.hasFamilyGlaucomaHistory
                  ? 'Family Glaucoma Hist.'
                  : null,
            ].whereType<String>().join(', '),
          ),
      ],
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
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1, color: PdfColors.blueGrey100),
        ),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blueGrey800,
          letterSpacing: 1,
        ),
      ),
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
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 6.5 : 7.5,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color ?? (isHeader ? PdfColors.black : PdfColors.grey900),
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
            '[PdfExportService] Œ Error fetching URL from localPath: $e',
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
              '[PdfExportService]  ï¸ Local file does not exist: $localPath',
            );
          }
        } catch (e) {
          debugPrint('[PdfExportService] Œ Error reading local file: $e');
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
                '[PdfExportService] 🛠️ Healed local file at: $localPath',
              );
            } catch (e) {
              debugPrint(
                '[PdfExportService]  ï¸ Failed to heal local file: $e',
              );
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

  pw.Widget _buildRefractionPrescriptionSection(TestResultModel result) {
    if (result.refractionPrescription == null) return pw.SizedBox();
    final prescription = result.refractionPrescription!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        _buildSectionHeader('FINAL RX & CLINICAL ADVICE'),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'AUTHORIZED BY: ${prescription.practitionerName.toUpperCase()}',
              style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey800,
              ),
            ),
            pw.Text(
              'DATE: ${DateFormat('dd MMM yyyy').format(prescription.timestamp)}',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey500),
            ),
          ],
        ),
        pw.SizedBox(height: 12),

        // Rx Table (Professional Look)
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey100, width: 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: _buildFinalRxTable(
            prescription.finalPrescription,
            (result.profileAge ?? 0) >= 40,
          ),
        ),
        pw.SizedBox(height: 12),

        // Practitioner Notes (The "What the practitioner typed")
        if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'CLINICAL NOTES & INSTRUCTIONS',
                  style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey700,
                    letterSpacing: 0.5,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  prescription.notes!,
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.blueGrey900,
                    lineSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),
        ],

        pw.Text(
          'Verification Statement: The above refractive values have been clinically verified for corrective lens dispensing. This document is a valid digital prescription.',
          style: pw.TextStyle(
            fontSize: 6,
            color: PdfColors.grey500,
            fontStyle: pw.FontStyle.italic,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFinalRxTable(FinalPrescriptionData data, bool showAdd) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _buildTableCell('EYE', isHeader: true),
            _buildTableCell('SPHERE (SPH)', isHeader: true),
            _buildTableCell('CYLINDER (CYL)', isHeader: true),
            _buildTableCell('AXIS', isHeader: true),
            _buildTableCell('ACUITY (VN)', isHeader: true),
            if (showAdd) _buildTableCell('NEAR ADD', isHeader: true),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Right Eye (OD)', isHeader: true),
            _buildTableCell(data.right.sph),
            _buildTableCell(data.right.cyl),
            _buildTableCell(data.right.axis),
            _buildTableCell(data.right.vn),
            if (showAdd) _buildTableCell(data.right.add),
          ],
        ),
        pw.TableRow(
          children: [
            _buildTableCell('Left Eye (OS)', isHeader: true),
            _buildTableCell(data.left.sph),
            _buildTableCell(data.left.cyl),
            _buildTableCell(data.left.axis),
            _buildTableCell(data.left.vn),
            if (showAdd) _buildTableCell(data.left.add),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildVisualFieldDetailedSection(TestResultModel result) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('PERIPHERAL VISUAL FIELD ASSESSMENT'),
        pw.SizedBox(height: 10),
        if (result.visualFieldRight != null) ...[
          _buildVisualFieldEyeDetail(
            'RIGHT EYE (OD)',
            result.visualFieldRight!,
          ),
          if (result.visualFieldLeft != null) pw.SizedBox(height: 15),
        ],
        if (result.visualFieldLeft != null)
          _buildVisualFieldEyeDetail('LEFT EYE (OS)', result.visualFieldLeft!),
        if (result.visualField != null &&
            result.visualFieldRight == null &&
            result.visualFieldLeft == null)
          _buildVisualFieldEyeDetail('OVERALL RESULT', result.visualField!),
      ],
    );
  }

  pw.Widget _buildVisualFieldEyeDetail(String label, VisualFieldResult res) {
    final statusColor = res.overallSensitivity >= 0.8
        ? PdfColors.green800
        : (res.overallSensitivity >= 0.5
              ? PdfColors.orange800
              : PdfColors.red800);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          children: [
            pw.Column(
              children: [
                pw.Text(
                  'GHT',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                _buildPdfGrayscaleMap(res),
              ],
            ),
            pw.SizedBox(width: 15),
            pw.Column(
              children: [
                pw.Text(
                  'PATTERN DEVIATION',
                  style: pw.TextStyle(
                    fontSize: 6,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 4),
                _buildPdfPatternDeviationMap(res),
              ],
            ),
            pw.SizedBox(width: 20),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: res.overallSensitivity >= 0.8
                        ? PdfColors.green50
                        : (res.overallSensitivity >= 0.5
                              ? PdfColors.orange50
                              : PdfColors.red50),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    '${(res.overallSensitivity * 100).toStringAsFixed(0)}% SENSITIVITY',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.SizedBox(
                  width: 150,
                  child: pw.Text(
                    res.interpretation,
                    style: const pw.TextStyle(
                      fontSize: 7,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            _buildPdfQuadrantItem(
              VisualFieldQuadrant.topRight.getLabel(res.eye),
              res.quadrantSensitivity[VisualFieldQuadrant.topRight] ?? 0,
            ),
            pw.SizedBox(width: 6),
            _buildPdfQuadrantItem(
              VisualFieldQuadrant.topLeft.getLabel(res.eye),
              res.quadrantSensitivity[VisualFieldQuadrant.topLeft] ?? 0,
            ),
            pw.SizedBox(width: 6),
            _buildPdfQuadrantItem(
              VisualFieldQuadrant.bottomRight.getLabel(res.eye),
              res.quadrantSensitivity[VisualFieldQuadrant.bottomRight] ?? 0,
            ),
            pw.SizedBox(width: 6),
            _buildPdfQuadrantItem(
              VisualFieldQuadrant.bottomLeft.getLabel(res.eye),
              res.quadrantSensitivity[VisualFieldQuadrant.bottomLeft] ?? 0,
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildPdfGrayscaleMap(VisualFieldResult res) {
    const int gridSteps = 14;
    final List<pw.Widget> blocks = [];

    for (int i = 0; i < gridSteps; i++) {
      for (int j = 0; j < gridSteps; j++) {
        final x = (i + 0.5) / gridSteps;
        final y = (j + 0.5) / gridSteps;

        double totalWeight = 0;
        double weightedIntensity = 0;

        for (final stimulus in res.stimuliResults) {
          final dx = x - stimulus.position.dx;
          final dy = y - stimulus.position.dy;
          final distance = math.sqrt(dx * dx + dy * dy);

          if (distance < 0.3) {
            final weight = 1.0 / (distance * distance + 0.01);
            totalWeight += weight;
            weightedIntensity +=
                (stimulus.isDetected ? stimulus.intensity : 1.2) * weight;
          }
        }

        if (totalWeight > 0) {
          final avgIntensity = weightedIntensity / totalWeight;
          if (avgIntensity > 0.4) {
            PdfColor blockColor;
            if (avgIntensity > 0.9) {
              blockColor = PdfColors.black;
            } else if (avgIntensity > 0.7) {
              blockColor = PdfColors.grey700;
            } else if (avgIntensity > 0.5) {
              blockColor = PdfColors.grey400;
            } else {
              blockColor = PdfColors.grey200;
            }

            blocks.add(
              pw.Positioned(
                left: i * 10,
                top: j * 10,
                child: pw.Container(width: 10, height: 10, color: blockColor),
              ),
            );
          }
        }
      }
    }

    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                canvas.setStrokeColor(PdfColors.grey100);
                canvas.setLineWidth(0.5);
                canvas.drawLine(size.x / 2, 0, size.x / 2, size.y);
                canvas.strokePath();
                canvas.drawLine(0, size.y / 2, size.x, size.y / 2);
                canvas.strokePath();
                canvas.setStrokeColor(PdfColors.black);
                canvas.drawEllipse(size.x / 2, size.y / 2, 1, 1);
                canvas.strokePath();
              },
            ),
          ),
          ...blocks,
        ],
      ),
    );
  }

  pw.Widget _buildPdfPatternDeviationMap(VisualFieldResult res) {
    return pw.Container(
      width: 100,
      height: 100,
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(4),
        border: pw.Border.all(color: PdfColors.grey200, width: 0.5),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned.fill(
            child: pw.CustomPaint(
              painter: (canvas, size) {
                canvas.setStrokeColor(PdfColors.grey100);
                canvas.setLineWidth(0.5);
                canvas.drawLine(size.x / 2, 0, size.x / 2, size.y);
                canvas.strokePath();
                canvas.drawLine(0, size.y / 2, size.x, size.y / 2);
                canvas.strokePath();
                canvas.setStrokeColor(PdfColors.black);
                canvas.drawEllipse(size.x / 2, size.y / 2, 1, 1);
                canvas.strokePath();

                // Central ring
                canvas.setStrokeColor(PdfColors.grey100);
                canvas.drawEllipse(
                  size.x / 2,
                  size.y / 2,
                  size.x * 0.2,
                  size.y * 0.2,
                );
                canvas.strokePath();
              },
            ),
          ),
          ...res.stimuliResults.map((s) {
            final x = s.position.dx * 100;
            final y = s.position.dy * 100;

            // Clamp to ensure no overflow
            final cx = x.clamp(3, 97);
            final cy = y.clamp(3, 97);

            if (!s.isDetected) {
              return pw.Positioned(
                left: cx - 3.5,
                top: cy - 3.5,
                child: pw.Container(
                  width: 7,
                  height: 7,
                  color: PdfColors.black,
                ),
              );
            } else {
              final intensity = s.intensity;
              if (intensity < 0.4) {
                return pw.Positioned(
                  left: cx - 0.5,
                  top: cy - 0.5,
                  child: pw.Container(
                    width: 1,
                    height: 1,
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.black,
                      shape: pw.BoxShape.circle,
                    ),
                  ),
                );
              } else if (intensity < 0.6) {
                return pw.Positioned(
                  left: cx - 2,
                  top: cy - 2,
                  child: pw.Container(
                    width: 4,
                    height: 4,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.black, width: 0.5),
                    ),
                  ),
                );
              } else if (intensity < 0.8) {
                return pw.Positioned(
                  left: cx - 2.5,
                  top: cy - 2.5,
                  child: pw.Container(
                    width: 5,
                    height: 5,
                    color: PdfColors.grey400,
                  ),
                );
              } else {
                return pw.Positioned(
                  left: cx - 3,
                  top: cy - 3,
                  child: pw.Container(
                    width: 6,
                    height: 6,
                    color: PdfColors.grey700,
                  ),
                );
              }
            }
          }),
        ],
      ),
    );
  }

  pw.Widget _buildPdfQuadrantItem(String label, double value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: pw.BoxDecoration(
          color: PdfColors.grey50,
          borderRadius: pw.BorderRadius.circular(4),
          border: pw.Border.all(color: PdfColors.grey100, width: 0.5),
        ),
        child: pw.Column(
          children: [
            pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              child: pw.Text(
                label.toUpperCase(),
                style: pw.TextStyle(
                  fontSize: 6,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey600,
                ),
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  pw.Widget _buildCoverTestDetailedSection(TestResultModel result) {
    final ct = result.coverTest;
    if (ct == null) return pw.SizedBox();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('BINOCULAR VISION (COVER TEST)'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                _buildTableCell('EYE', isHeader: true),
                _buildTableCell('ALIGNMENT STATUS', isHeader: true),
                _buildTableCell('DESCRIPTION', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('OD (Right Eye)'),
                _buildTableCell(
                  ct.rightEyeStatus.label,
                  color: ct.rightEyeStatus == AlignmentStatus.normal
                      ? PdfColors.green700
                      : PdfColors.orange700,
                ),
                _buildTableCell(ct.rightEyeStatus.description),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('OS (Left Eye)'),
                _buildTableCell(
                  ct.leftEyeStatus.label,
                  color: ct.leftEyeStatus == AlignmentStatus.normal
                      ? PdfColors.green700
                      : PdfColors.orange700,
                ),
                _buildTableCell(ct.leftEyeStatus.description),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey50,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CLINICAL INTERPRETATION: ',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      ct.overallInterpretation,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'RECOMMENDATION: ',
                    style: pw.TextStyle(
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blueGrey800,
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Text(
                      ct.recommendation,
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.blueGrey700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// TORCHLIGHT EXAMINATION - DETAILED
  pw.Widget _buildTorchlightDetailedSection(TestResultModel result) {
    if (result.torchlight == null) return pw.SizedBox();
    final t = result.torchlight!;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('TORCHLIGHT EXAMINATION'),
        pw.SizedBox(height: 10),

        // 1. Pupillary Examination Subsection
        if (t.pupillary != null) ...[
          pw.Text(
            'PUPILLARY EXAMINATION',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                children: [
                  _buildTableCell('METRIC', isHeader: true),
                  _buildTableCell('RIGHT EYE (OD)', isHeader: true),
                  _buildTableCell('LEFT EYE (OS)', isHeader: true),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Pupil Size (Static)'),
                  _buildTableCell(
                    '${t.pupillary!.rightPupilSize.toStringAsFixed(1)} mm',
                  ),
                  _buildTableCell(
                    '${t.pupillary!.leftPupilSize.toStringAsFixed(1)} mm',
                  ),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Pupil Shape'),
                  _buildTableCell(t.pupillary!.rightShape.name.toUpperCase()),
                  _buildTableCell(t.pupillary!.leftShape.name.toUpperCase()),
                ],
              ),
              pw.TableRow(
                children: [
                  _buildTableCell('Light Reflex'),
                  _buildTableCell(t.pupillary!.directReflex.name.toUpperCase()),
                  _buildTableCell(
                    t.pupillary!.consensualReflex.name.toUpperCase(),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSimpleInfoRow(
                    'Symmetry:',
                    t.pupillary!.symmetric
                        ? 'Symmetric'
                        : 'Anisocoria detected',
                  ),
                ),
                pw.Expanded(
                  child: _buildSimpleInfoRow(
                    'RAPD Status:',
                    t.pupillary!.rapdStatus.name.toUpperCase(),
                  ),
                ),
              ],
            ),
          ),
          if (t.pupillary!.anisocoriaDifference != null &&
              t.pupillary!.anisocoriaDifference! > 0)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 4),
              child: pw.Text(
                'Anisocoria: ${t.pupillary!.anisocoriaDifference!.toStringAsFixed(1)} mm difference between pupils.',
                style: const pw.TextStyle(
                  fontSize: 7,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ),
          pw.SizedBox(height: 12),
        ],

        // 2. Extraocular Muscle Subsection
        if (t.extraocular != null) ...[
          pw.Text(
            'EXTRAOCULAR MUSCLE MOTILITY',
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey700,
            ),
          ),
          pw.SizedBox(height: 6),
          _buildEomTable(t.extraocular!),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildSimpleInfoRow(
                  'Nystagmus:',
                  t.extraocular!.nystagmusDetected
                      ? 'Detected'
                      : 'Not detected',
                ),
              ),
              pw.Expanded(
                child: _buildSimpleInfoRow(
                  'Ptosis:',
                  t.extraocular!.ptosisDetected
                      ? 'Detected (${t.extraocular!.ptosisEye?.name})'
                      : 'Not detected',
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],

        // 3. Clinical Interpretation
        _buildTorchlightAssessmentBlock(
          'CLINICAL INTERPRETATION',
          t.clinicalInterpretation,
        ),
        pw.SizedBox(height: 8),

        // 4. Recommendations
        if (t.recommendations.isNotEmpty) ...[
          _buildTorchlightAssessmentBlock(
            'RECOMMENDATIONS',
            t.recommendations.join('\n'),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildEomTable(ExtraocularResult eom) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
          children: [
            _buildTableCell('DIRECTION', isHeader: true),
            _buildTableCell('MOVEMENT QUALITY', isHeader: true),
            _buildTableCell('RESTRICTION', isHeader: true),
          ],
        ),
        ...eom.movements.entries.map((entry) {
          final restriction = eom.restrictionMap[entry.key] ?? 0;
          return pw.TableRow(
            children: [
              _buildTableCell(entry.key.replaceAll('_', ' ').toUpperCase()),
              _buildTableCell(entry.value.name.toUpperCase()),
              _buildTableCell(
                restriction > 0 ? '${restriction.toStringAsFixed(0)}%' : 'None',
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildTorchlightAssessmentBlock(String title, String content) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            content,
            style: const pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.blueGrey700,
              lineSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSimpleInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Text(
            '$label ',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey600,
            ),
          ),
          pw.Text(
            value,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.blueGrey800,
            ),
          ),
        ],
      ),
    );
  }

  /// SYMPTOM DETECTOR & PRELIMINARY SCREENING SECTION
  pw.Widget _buildSymptomDetectorSection(TestResultModel result) {
    final conditions = SymptomDetectorService.analyze(result);
    if (conditions.isEmpty) return pw.SizedBox();

    // Group by category
    final grouped = <ConditionCategory, List<DetectedCondition>>{};
    for (var c in conditions.take(15)) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 6),
        _buildSectionHeader('PRELIMINARY SYMPTOM DETECTION & SCREENING'),
        pw.SizedBox(height: 8),
        // Disclaimer notice
        pw.Container(
          padding: const pw.EdgeInsets.all(8),
          decoration: pw.BoxDecoration(
            color: PdfColors.yellow50,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.yellow100, width: 0.5),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: 10,
                height: 10,
                decoration: const pw.BoxDecoration(
                  color: PdfColors.amber700,
                  shape: pw.BoxShape.circle,
                ),
                child: pw.Center(
                  child: pw.Text(
                    '!',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 7,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Expanded(
                child: pw.Text(
                  'PRELIMINARY SYMPTOMS/SIGNS - Not clinical diagnoses. '
                  'A full ocular examination by a qualified practitioner is mandatory.',
                  style: pw.TextStyle(
                    fontSize: 6.5,
                    fontStyle: pw.FontStyle.italic,
                    color: PdfColors.amber900,
                  ),
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // Summary count
        pw.Text(
          '${conditions.length} condition${conditions.length == 1 ? '' : 's'} detected',
          style: pw.TextStyle(
            fontSize: 7,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blueGrey600,
          ),
        ),
        pw.SizedBox(height: 6),
        // Compact summary table with grouping
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey50, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: {
            0: const pw.FlexColumnWidth(2.2),
            1: const pw.FlexColumnWidth(
              1.3,
            ), // Fixed: more space for "INFORMATIONAL"
            2: const pw.FlexColumnWidth(3),
            3: const pw.FlexColumnWidth(2.5),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
              children: [
                _buildTableCell('CONDITION', isHeader: true),
                _buildTableCell('SEVERITY', isHeader: true),
                _buildTableCell('KEY FINDINGS', isHeader: true),
                _buildTableCell('RECOMMENDATION', isHeader: true),
              ],
            ),
            // Grouped Data rows
            ...grouped.entries.expand((entry) {
              final category = entry.key;
              final items = entry.value;

              return [
                // Category Header Line
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: pw.Text(
                        category.name.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 6.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.grey900,
                        ),
                      ),
                    ),
                    pw.SizedBox(),
                    pw.SizedBox(),
                    pw.SizedBox(),
                  ],
                ),
                // Items for this category
                ...items.map((condition) {
                  final severityColor =
                      condition.severity == ConditionSeverity.critical
                      ? PdfColors.red700
                      : condition.severity == ConditionSeverity.significant
                      ? PdfColors.orange700
                      : condition.severity == ConditionSeverity.moderate
                      ? PdfColors.amber700
                      : PdfColors.blue700;

                  return pw.TableRow(
                    children: [
                      // Condition name
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          condition.name,
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                      ),
                      // Severity badge
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Container(
                          padding: const pw.EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: pw.BoxDecoration(
                            color: severityColor,
                            borderRadius: pw.BorderRadius.circular(2),
                          ),
                          child: pw.Text(
                            condition.severity.name.toUpperCase(),
                            style: pw.TextStyle(
                              fontSize: 5.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.white,
                            ),
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ),
                      // Key findings
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            ...condition.detectedSymptoms
                                .take(2)
                                .map(
                                  (s) => pw.Text(
                                    '- $s',
                                    style: const pw.TextStyle(
                                      fontSize: 6.5,
                                      color: PdfColors.grey800,
                                    ),
                                  ),
                                ),
                            if (condition.detectedSymptoms.length > 2)
                              pw.Text(
                                '  +${condition.detectedSymptoms.length - 2} more',
                                style: const pw.TextStyle(
                                  fontSize: 6,
                                  color: PdfColors.grey500,
                                ),
                              ),
                            if (condition.possibleCauses.isNotEmpty) ...[
                              pw.SizedBox(height: 1),
                              pw.Text(
                                condition.possibleCauses.take(2).join(', '),
                                style: pw.TextStyle(
                                  fontSize: 5.5,
                                  color: PdfColors.grey600,
                                  fontStyle: pw.FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Recommendation
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(
                          condition.recommendation,
                          style: const pw.TextStyle(
                            fontSize: 6.5,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ];
            }).toList(),
          ],
        ),
      ],
    );
  }
}
