import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:typed_data';
import 'package:permission_handler/permission_handler.dart';

import 'package:intl/intl.dart';
import '../../data/models/test_result_model.dart';
import '../../data/models/questionnaire_model.dart';
import '../../data/models/color_vision_result.dart';
import '../../data/models/amsler_grid_result.dart';
import '../../data/models/pelli_robson_result.dart';
import '../../data/models/visiual_acuity_result.dart';
import '../../data/models/short_distance_result.dart';

/// Service for generating PDF reports of test results
class PdfExportService {
  /// Generate and download PDF report to device's Downloads folder
  Future<String> generateAndDownloadPdf(TestResultModel result) async {
    final String filePath = await getExpectedFilePath(result);
    final File file = File(filePath);

    // If file already exists, return its path without regenerating
    if (await file.exists()) {
      debugPrint(
        '[PdfExportService] File already exists at: $filePath. Skipping generation.',
      );
      return filePath;
    }

    final pdf = await _buildPdfDocument(result);
    await file.writeAsBytes(await pdf.save());

    return file.path;
  }

  /// Get the expected file path for a test result PDF
  Future<String> getExpectedFilePath(TestResultModel result) async {
    final name = result.profileName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
    final age = result.profileAge != null ? '_${result.profileAge}y' : '';
    final dateTime = DateFormat('yyyyMMdd_HHmmss').format(result.timestamp);
    final filename = 'VisionTest_$name${age}_$dateTime.pdf';

    final downloadsDir = await getDownloadsDirectoryPath();
    return '$downloadsDir/$filename';
  }

  /// Get platform-specific downloads directory path
  Future<String> getDownloadsDirectoryPath() async {
    Directory? downloadsDir;
    if (Platform.isAndroid) {
      await Permission.storage.request();
      downloadsDir = Directory('/storage/emulated/0/Download');
      if (!await downloadsDir.exists()) {
        downloadsDir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      downloadsDir = await getApplicationDocumentsDirectory();
    } else {
      downloadsDir = await getApplicationDocumentsDirectory();
    }
    return downloadsDir?.path ?? '';
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
        result.amslerGridRight!.firebaseImageUrl,
      );
    }

    if (result.amslerGridLeft != null) {
      amslerLeftBytes = await _getImageBytes(
        result.amslerGridLeft!.annotatedImagePath,
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
                    result.id.substring(0, 8).toUpperCase(),
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
      if (cc.rednessFollowUp?.duration != null)
        detail += ' (${cc.rednessFollowUp!.duration})';
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
    // 1. Try local path first
    if (localPath != null &&
        localPath.isNotEmpty &&
        !localPath.startsWith('http')) {
      try {
        final file = File(localPath);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        print('[PdfExportService] Error reading local image: $e');
      }
    }

    // 2. Fallback to remote URL
    if (remoteUrl != null &&
        remoteUrl.isNotEmpty &&
        remoteUrl.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(remoteUrl));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        print('[PdfExportService] Error fetching remote image: $e');
      }
    }

    // 3. Fallback: if localPath is actually a URL (backward compatibility)
    if (localPath != null && localPath.startsWith('http')) {
      try {
        final response = await http.get(Uri.parse(localPath));
        if (response.statusCode == 200) {
          return response.bodyBytes;
        }
      } catch (e) {
        print('[PdfExportService] Error fetching localPath as URL: $e');
      }
    }

    return null;
  }
}
