import 'package:flutter/material.dart';
import '../services/symptom_detector_service.dart';
import '../../data/models/test_result_model.dart';
import '../extensions/theme_extension.dart';

/// Reusable card that runs the symptom detector engine on a TestResultModel
/// and displays the results with expandable disease tiles + disclaimer.
class SymptomDetectorCard extends StatefulWidget {
  final TestResultModel result;
  const SymptomDetectorCard({super.key, required this.result});

  @override
  State<SymptomDetectorCard> createState() => _SymptomDetectorCardState();
}

class _SymptomDetectorCardState extends State<SymptomDetectorCard> {
  late List<DetectedCondition> _conditions;
  bool _isExpanded = true;

  @override
  void initState() {
    super.initState();
    _conditions = SymptomDetectorService.analyze(widget.result);
  }

  @override
  void didUpdateWidget(covariant SymptomDetectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _conditions = SymptomDetectorService.analyze(widget.result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.dividerColor),
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(context),

          if (_isExpanded) ...[
            // Disclaimer
            _buildDisclaimer(context),

            // Content
            if (_conditions.isEmpty)
              _buildNoConcerns(context)
            else
              _buildConditionsList(context),

            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.deepPurple.shade400,
                    Colors.deepPurple.shade700,
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.biotech_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Symptom Detector',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _conditions.isEmpty
                        ? 'No concerns detected'
                        : '${_conditions.length} condition${_conditions.length == 1 ? '' : 's'} detected',
                    style: TextStyle(
                      color: _conditions.isEmpty
                          ? context.success
                          : Colors.deepPurple.shade300,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_conditions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _getOverallSeverityColor().withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getOverallSeverityLabel(),
                  style: TextStyle(
                    color: _getOverallSeverityColor(),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              color: context.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.warning.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gavel_rounded, color: context.warning, size: 16),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This analysis is for informational purposes only and does not '
                'constitute a medical diagnosis. Always consult a licensed eye '
                'care professional for a definitive diagnosis.',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoConcerns(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.success.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              color: context.success,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No Concerns Detected',
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on available test data, no significant conditions were flagged.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsList(BuildContext context) {
    // Group by category
    final grouped = <ConditionCategory, List<DetectedCondition>>{};
    for (final c in _conditions) {
      grouped.putIfAbsent(c.category, () => []).add(c);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: grouped.entries.map((entry) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category header
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Icon(
                      _getCategoryIcon(entry.key),
                      size: 14,
                      color: context.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getCategoryLabel(entry.key).toUpperCase(),
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Condition tiles
              ...entry.value.map((c) => _buildConditionTile(context, c)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConditionTile(
    BuildContext context,
    DetectedCondition condition,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: context.scaffoldBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.dividerColor),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          childrenPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 0,
          ),
          leading: _buildSeverityDot(condition.severity),
          title: Text(
            condition.name,
            style: TextStyle(
              color: context.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          subtitle: Text(
            condition.recommendation,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: context.textTertiary, fontSize: 11),
          ),
          children: [
            // Detected symptoms
            _buildDetailSection(
              context,
              'Detected Signs',
              Icons.visibility_outlined,
              condition.detectedSymptoms,
            ),
            // Possible causes
            _buildDetailSection(
              context,
              'Possible Causes',
              Icons.help_outline,
              condition.possibleCauses,
            ),
            // Contributing tests
            _buildDetailSection(
              context,
              'Based On',
              Icons.science_outlined,
              condition.contributingTests,
            ),
            // Recommendation
            Padding(
              padding: const EdgeInsets.only(bottom: 12, top: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: context.info.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: context.info,
                      size: 14,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        condition.recommendation,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    BuildContext context,
    String title,
    IconData icon,
    List<String> items,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: context.textSecondary),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 12,
                        height: 1.3,
                      ),
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

  Widget _buildSeverityDot(ConditionSeverity severity) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getSeverityColor(severity),
        boxShadow: [
          BoxShadow(
            color: _getSeverityColor(severity).withValues(alpha: 0.4),
            blurRadius: 6,
          ),
        ],
      ),
    );
  }

  Color _getSeverityColor(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.critical:
        return Colors.red;
      case ConditionSeverity.significant:
        return Colors.orange;
      case ConditionSeverity.moderate:
        return Colors.amber;
      case ConditionSeverity.informational:
        return Colors.blue;
    }
  }

  Color _getOverallSeverityColor() {
    if (_conditions.isEmpty) return Colors.green;
    return _getSeverityColor(_conditions.first.severity);
  }

  String _getOverallSeverityLabel() {
    if (_conditions.isEmpty) return 'All Clear';
    switch (_conditions.first.severity) {
      case ConditionSeverity.critical:
        return 'Critical';
      case ConditionSeverity.significant:
        return 'Attention Needed';
      case ConditionSeverity.moderate:
        return 'Review';
      case ConditionSeverity.informational:
        return 'Info';
    }
  }

  IconData _getCategoryIcon(ConditionCategory category) {
    switch (category) {
      case ConditionCategory.refractive:
        return Icons.remove_red_eye_outlined;
      case ConditionCategory.retinal:
        return Icons.grain;
      case ConditionCategory.glaucoma:
        return Icons.warning_amber_rounded;
      case ConditionCategory.neurological:
        return Icons.psychology_outlined;
      case ConditionCategory.surface:
        return Icons.water_drop_outlined;
      case ConditionCategory.alignment:
        return Icons.swap_horiz;
      case ConditionCategory.systemic:
        return Icons.monitor_heart_outlined;
    }
  }

  String _getCategoryLabel(ConditionCategory category) {
    switch (category) {
      case ConditionCategory.refractive:
        return 'Refractive';
      case ConditionCategory.retinal:
        return 'Retinal';
      case ConditionCategory.glaucoma:
        return 'Glaucoma / IOP';
      case ConditionCategory.neurological:
        return 'Neurological';
      case ConditionCategory.surface:
        return 'Surface / Anterior';
      case ConditionCategory.alignment:
        return 'Alignment / Binocular';
      case ConditionCategory.systemic:
        return 'Systemic';
    }
  }
}
