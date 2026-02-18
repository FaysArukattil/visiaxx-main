import 'package:flutter/material.dart';
import '../services/symptom_detector_service.dart';
import '../../data/models/test_result_model.dart';
import '../extensions/theme_extension.dart';

/// Reusable card that runs the symptom detector engine on a TestResultModel
/// and displays the results as a compact summariser with expandable details.
class SymptomDetectorCard extends StatefulWidget {
  final TestResultModel result;
  const SymptomDetectorCard({super.key, required this.result});

  @override
  State<SymptomDetectorCard> createState() => _SymptomDetectorCardState();
}

class _SymptomDetectorCardState extends State<SymptomDetectorCard>
    with SingleTickerProviderStateMixin {
  late List<DetectedCondition> _conditions;
  bool _isExpanded = true;
  int? _expandedIndex; // which condition row is expanded (null = none)

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _conditions = SymptomDetectorService.analyze(widget.result);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant SymptomDetectorCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.result != widget.result) {
      _conditions = SymptomDetectorService.analyze(widget.result);
      _expandedIndex = null;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(context),
          if (_isExpanded) ...[
            _buildDisclaimer(context),
            if (_conditions.isEmpty)
              _buildNoConcerns(context)
            else
              _buildSummaryList(context),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  // ─── HEADER ──────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.biotech_rounded,
                color: context.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Symptoms Detected',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (_conditions.isEmpty)
                    Text(
                      'No concerns detected',
                      style: TextStyle(
                        color: context.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _getOverallSeverityColor().withValues(
                          alpha: 0.12,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _getOverallSeverityLabel().toUpperCase(),
                        style: TextStyle(
                          color: _getOverallSeverityColor(),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedRotation(
              turns: _isExpanded ? 0.5 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DISCLAIMER ──────────────────────────────────────────────

  Widget _buildDisclaimer(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.warning.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.gavel_rounded, color: context.warning, size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'For informational purposes only — not a medical diagnosis. '
                'Consult a licensed eye care professional for definitive diagnosis.',
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 10.5,
                  height: 1.35,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── NO CONCERNS ─────────────────────────────────────────────

  Widget _buildNoConcerns(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_rounded,
                color: context.success,
                size: 36,
              ),
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
            'All test data within normal parameters.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ─── COMPACT SUMMARY LIST ────────────────────────────────────

  Widget _buildSummaryList(BuildContext context) {
    // Group by severity (critical → informational)
    final grouped =
        <ConditionSeverity, List<MapEntry<int, DetectedCondition>>>{};
    for (int i = 0; i < _conditions.length; i++) {
      final c = _conditions[i];
      grouped.putIfAbsent(c.severity, () => []).add(MapEntry(i, c));
    }

    // Order: critical, significant, moderate, informational
    final orderedSeverities = [
      ConditionSeverity.critical,
      ConditionSeverity.significant,
      ConditionSeverity.moderate,
      ConditionSeverity.informational,
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: orderedSeverities.where((s) => grouped.containsKey(s)).map((
          severity,
        ) {
          final items = grouped[severity]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Severity group label
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    Text(
                      _getSeverityLabel(severity).toUpperCase(),
                      style: TextStyle(
                        color: context.textSecondary.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Spacer(),
                  ],
                ),
              ),
              // Compact rows for this severity group
              ...items.map(
                (entry) =>
                    _buildCompactConditionRow(context, entry.key, entry.value),
              ),
              const SizedBox(height: 8),
            ],
          );
        }).toList(),
      ),
    );
  }

  /// A single compact condition row — tap to expand details
  Widget _buildCompactConditionRow(
    BuildContext context,
    int index,
    DetectedCondition condition,
  ) {
    final isOpen = _expandedIndex == index;
    final categoryIcon = _getCategoryIcon(condition.category);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isOpen
            ? context.primary.withValues(alpha: 0.03)
            : context.scaffoldBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() {
            _expandedIndex = isOpen ? null : index;
          }),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // ── Compact row ──
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    // Category icon
                    Icon(
                      categoryIcon,
                      size: 16,
                      color: _getSeverityColor(condition.severity),
                    ),
                    const SizedBox(width: 10),
                    // Condition name + key finding
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            condition.name,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                              height: 1.2,
                            ),
                          ),
                          if (condition.detectedSymptoms.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              condition.detectedSymptoms.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.textTertiary,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: context.textSecondary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getCategoryLabel(condition.category),
                        style: TextStyle(
                          color: context.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Expanded detail panel ──
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: _buildConditionDetails(context, condition),
                crossFadeState: isOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Expanded details — detected symptoms + recommendation (concise)
  Widget _buildConditionDetails(
    BuildContext context,
    DetectedCondition condition,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Spacing instead of divider
          const SizedBox(height: 8),

          // Detected symptoms
          if (condition.detectedSymptoms.isNotEmpty) ...[
            _buildMiniSectionLabel(
              context,
              'Detected Signs',
              Icons.visibility_outlined,
            ),
            const SizedBox(height: 4),
            ...condition.detectedSymptoms.map(
              (s) => Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '▸ ',
                      style: TextStyle(
                        color: _getSeverityColor(condition.severity),
                        fontSize: 11,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        s,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Possible causes (compact inline)
          if (condition.possibleCauses.isNotEmpty) ...[
            _buildMiniSectionLabel(
              context,
              'Possible Causes',
              Icons.help_outline_rounded,
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                condition.possibleCauses.join(' · '),
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Recommendation box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_outline, color: context.info, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    condition.recommendation,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniSectionLabel(
    BuildContext context,
    String label,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, size: 12, color: context.textSecondary),
        const SizedBox(width: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }

  // ─── HELPERS ─────────────────────────────────────────────────

  Color _getSeverityColor(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.critical:
        return Colors.red;
      case ConditionSeverity.significant:
        return Colors.orange;
      case ConditionSeverity.moderate:
        return Colors.amber.shade700;
      case ConditionSeverity.informational:
        return Colors.blue;
    }
  }

  String _getSeverityLabel(ConditionSeverity severity) {
    switch (severity) {
      case ConditionSeverity.critical:
        return 'Critical';
      case ConditionSeverity.significant:
        return 'Attention Needed';
      case ConditionSeverity.moderate:
        return 'Review';
      case ConditionSeverity.informational:
        return 'Informational';
    }
  }

  Color _getOverallSeverityColor() {
    if (_conditions.isEmpty) return Colors.green;
    return _getSeverityColor(_conditions.first.severity);
  }

  String _getOverallSeverityLabel() {
    if (_conditions.isEmpty) return 'All Clear';
    return _getSeverityLabel(_conditions.first.severity);
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
        return 'Glaucoma';
      case ConditionCategory.neurological:
        return 'Neuro';
      case ConditionCategory.surface:
        return 'Surface';
      case ConditionCategory.alignment:
        return 'Binocular';
      case ConditionCategory.systemic:
        return 'Systemic';
    }
  }
}
