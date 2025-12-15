import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../../data/models/test_result_model.dart';
import '../../data/models/questionnaire_model.dart';

/// Service for generating PDF reports of test results
class PdfExportService {
  /// Generate and save a PDF report
  Future<File> generatePdfReport(
    TestResultModel result, {
    String? userName,
    int? userAge,
  }) async {
    final pdf = await _buildPdfDocument(
      result,
      userName: userName,
      userAge: userAge,
    );

    final output = await getTemporaryDirectory();
    final file = File('${output.path}/visiaxx_report_${result.id}.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  /// Print or share the PDF directly
  Future<void> printOrSharePdf(
    TestResultModel result, {
    String? userName,
    int? userAge,
  }) async {
    final pdf = await _buildPdfDocument(
      result,
      userName: userName,
      userAge: userAge,
    );
    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  /// Share PDF file using share_plus for native sharing
  Future<void> sharePdf(
    TestResultModel result, {
    String? userName,
    int? userAge,
  }) async {
    // Generate PDF file
    final file = await generatePdfReport(
      result,
      userName: userName,
      userAge: userAge,
    );

    // Share using share_plus for native share dialog
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'My Vision Test Report',
      subject:
          'Visiaxx Vision Test Results - ${DateFormat('MMM dd, yyyy').format(result.timestamp)}',
    );
  }

  /// Build PDF Document with all sections
  Future<pw.Document> _buildPdfDocument(
    TestResultModel result, {
    String? userName,
    int? userAge,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(context, userName),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          // Title Section
          _buildTitleSection(result, userName, userAge),
          pw.SizedBox(height: 20),

          // Visual Acuity Section (Distance Vision - 1 meter)
          _buildVisualAcuitySection(result),
          pw.SizedBox(height: 20),

          // Short Distance Section (Reading Test - 40cm)
          if (result.shortDistance != null) ...[
            _buildShortDistanceSection(result),
            pw.SizedBox(height: 20),
          ],

          // Color Vision Section
          _buildColorVisionSection(result),
          pw.SizedBox(height: 20),

          // Amsler Grid Section
          if (result.amslerGridRight != null ||
              result.amslerGridLeft != null) ...[
            _buildAmslerGridSection(result),
            pw.SizedBox(height: 20),
          ],

          // Overall Status Section
          _buildOverallStatusSection(result),
          pw.SizedBox(height: 20),

          // Questionnaire Section
          if (result.questionnaire != null) ...[
            _buildQuestionnaireSection(result.questionnaire!),
          ],
        ],
      ),
    );

    return pdf;
  }

  /// Build Short Distance Section (Reading Test - 40cm)
  pw.Widget _buildShortDistanceSection(TestResultModel result) {
    final shortDistance = result.shortDistance;

    if (shortDistance == null) {
      return pw.SizedBox.shrink();
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Reading Test (Near Vision - 40cm)'),
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
              // Status row
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Status:',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  pw.Text(
                    shortDistance.status,
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: shortDistance.isNormal
                          ? PdfColors.green700
                          : PdfColors.orange700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),

              // Stats grid
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Best Acuity:',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          shortDistance.bestAcuity,
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Sentences:',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${shortDistance.correctSentences}/${shortDistance.totalSentences}',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Average Match:',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${shortDistance.averageSimilarity.toStringAsFixed(1)}%',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                            color: shortDistance.averageSimilarity >= 70
                                ? PdfColors.green700
                                : PdfColors.orange700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Accuracy:',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${(shortDistance.accuracy * 100).toStringAsFixed(0)}%',
                          style: pw.TextStyle(
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Detailed responses table (if space allows)
        if (shortDistance.responses.isNotEmpty) ...[
          pw.SizedBox(height: 12),
          pw.Text(
            'Detailed Results:',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(0.5),
              1: const pw.FlexColumnWidth(1.5),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(0.8),
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _buildTableCell('#', isHeader: true),
                  _buildTableCell('Snellen', isHeader: true),
                  _buildTableCell('Match %', isHeader: true),
                  _buildTableCell('Result', isHeader: true),
                ],
              ),
              // Data rows (limit to 7 for space)
              ...shortDistance.responses.take(7).map((response) {
                return pw.TableRow(
                  children: [
                    _buildTableCell('${response.screenNumber}'),
                    _buildTableCell(response.snellen),
                    _buildTableCell(
                      '${response.similarity.toStringAsFixed(0)}%',
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        response.passed ? '✓' : '✗',
                        style: pw.TextStyle(
                          fontSize: 10,
                          color: response.passed
                              ? PdfColors.green700
                              : PdfColors.red700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ],
    );
  }

  pw.Widget _buildHeader(pw.Context context, String? userName) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(width: 1, color: PdfColors.grey300),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'VISIAXX',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Text(
            'Digital Eye Clinic',
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
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
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Generated by Visiaxx App',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
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
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Vision Test Report',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Patient',
                      result.profileName.isNotEmpty
                          ? result.profileName
                          : (userName ?? 'N/A'),
                    ),
                    if (userAge != null) _buildInfoRow('Age', '$userAge years'),
                    _buildInfoRow('Test Type', result.testType.toUpperCase()),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow(
                      'Date',
                      DateFormat('MMM dd, yyyy').format(result.timestamp),
                    ),
                    _buildInfoRow(
                      'Time',
                      DateFormat('h:mm a').format(result.timestamp),
                    ),
                    _buildInfoRow(
                      'Report ID',
                      result.id.substring(0, 8).toUpperCase(),
                    ),
                  ],
                ),
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
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildVisualAcuitySection(TestResultModel result) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Visual Acuity Test (Distance Vision - 1 meter)'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Eye', isHeader: true),
                _buildTableCell('Snellen Score', isHeader: true),
                _buildTableCell('LogMAR', isHeader: true),
                _buildTableCell('Status', isHeader: true),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Right Eye'),
                _buildTableCell(
                  result.visualAcuityRight?.snellenScore ?? 'N/A',
                ),
                _buildTableCell(
                  result.visualAcuityRight?.logMAR.toStringAsFixed(2) ?? 'N/A',
                ),
                _buildTableCell(result.visualAcuityRight?.status ?? 'N/A'),
              ],
            ),
            pw.TableRow(
              children: [
                _buildTableCell('Left Eye'),
                _buildTableCell(result.visualAcuityLeft?.snellenScore ?? 'N/A'),
                _buildTableCell(
                  result.visualAcuityLeft?.logMAR.toStringAsFixed(2) ?? 'N/A',
                ),
                _buildTableCell(result.visualAcuityLeft?.status ?? 'N/A'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildColorVisionSection(TestResultModel result) {
    final colorVision = result.colorVision;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Color Vision Test (Ishihara)'),
        pw.SizedBox(height: 8),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Score: ${colorVision?.correctAnswers ?? 0}/${colorVision?.totalPlates ?? 0}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Status: ${colorVision?.status ?? 'N/A'}',
                      style: const pw.TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (colorVision?.deficiencyType != null)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.orange100,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Text(
                    colorVision!.deficiencyType!,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.orange900,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildAmslerGridSection(TestResultModel result) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Amsler Grid Test'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              children: [
                _buildTableCell('Eye', isHeader: true),
                _buildTableCell('Distortions', isHeader: true),
                _buildTableCell('Status', isHeader: true),
              ],
            ),
            if (result.amslerGridRight != null)
              pw.TableRow(
                children: [
                  _buildTableCell('Right Eye'),
                  _buildTableCell(
                    result.amslerGridRight!.hasDistortions
                        ? 'Detected'
                        : 'None',
                  ),
                  _buildTableCell(
                    result.amslerGridRight!.hasDistortions
                        ? 'Abnormal'
                        : 'Normal',
                  ),
                ],
              ),
            if (result.amslerGridLeft != null)
              pw.TableRow(
                children: [
                  _buildTableCell('Left Eye'),
                  _buildTableCell(
                    result.amslerGridLeft!.hasDistortions ? 'Detected' : 'None',
                  ),
                  _buildTableCell(
                    result.amslerGridLeft!.hasDistortions
                        ? 'Abnormal'
                        : 'Normal',
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildOverallStatusSection(TestResultModel result) {
    PdfColor statusColor;
    switch (result.overallStatus) {
      case TestStatus.normal:
        statusColor = PdfColors.green700;
        break;
      case TestStatus.review:
        statusColor = PdfColors.orange700;
        break;
      case TestStatus.urgent:
        statusColor = PdfColors.red700;
        break;
    }

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
          pw.Row(
            children: [
              pw.Text(
                'Overall Status: ',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                result.overallStatus.label,
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            result.recommendation,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildQuestionnaireSection(QuestionnaireModel questionnaire) {
    final complaints = <String>[];
    if (questionnaire.chiefComplaints.hasRedness) complaints.add('Redness');
    if (questionnaire.chiefComplaints.hasWatering) complaints.add('Watering');
    if (questionnaire.chiefComplaints.hasItching) complaints.add('Itching');
    if (questionnaire.chiefComplaints.hasHeadache) complaints.add('Headache');
    if (questionnaire.chiefComplaints.hasDryness) complaints.add('Dryness');
    if (questionnaire.chiefComplaints.hasStickyDischarge)
      complaints.add('Sticky Discharge');

    final conditions = <String>[];
    if (questionnaire.systemicIllness.hasHypertension)
      conditions.add('Hypertension');
    if (questionnaire.systemicIllness.hasDiabetes) conditions.add('Diabetes');
    if (questionnaire.systemicIllness.hasCopd) conditions.add('COPD');
    if (questionnaire.systemicIllness.hasAsthma) conditions.add('Asthma');
    if (questionnaire.systemicIllness.hasMigraine) conditions.add('Migraine');
    if (questionnaire.systemicIllness.hasSinus) conditions.add('Sinus');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Patient History (Questionnaire)'),
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
              pw.Text(
                'Chief Complaints:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                complaints.isEmpty ? 'None reported' : complaints.join(', '),
                style: const pw.TextStyle(fontSize: 10),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Systemic Conditions:',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                conditions.isEmpty ? 'None reported' : conditions.join(', '),
                style: const pw.TextStyle(fontSize: 10),
              ),
              if (questionnaire.currentMedications != null &&
                  questionnaire.currentMedications!.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Current Medications:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  questionnaire.currentMedications!,
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
              if (questionnaire.hasRecentSurgery) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Recent Surgery:',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
                pw.Text(
                  questionnaire.surgeryDetails ?? 'Yes',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.blue800,
      ),
    );
  }

  pw.Widget _buildTableCell(String text, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }
}
