import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/radio_group.dart';
import '../../../data/models/questionnaire_model.dart';
import '../../../data/providers/test_session_provider.dart';

/// Pre-test questionnaire with dynamic follow-up questions
class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  int _currentStep = 0;

  // Chief complaints
  ChiefComplaints _chiefComplaints = ChiefComplaints();

  // Systemic illness
  SystemicIllness _systemicIllness = SystemicIllness();

  // Other fields
  final _medicationsController = TextEditingController();
  bool _hasRecentSurgery = false;
  final _surgeryDetailsController = TextEditingController();

  // Follow-up controllers
  final _rednessController = TextEditingController();
  final _wateringDaysController = TextEditingController();
  String _wateringPattern = 'continuous';
  bool _itchingBothEyes = false;
  final _itchingLocationController = TextEditingController();
  final _headacheLocationController = TextEditingController();
  final _headacheDurationController = TextEditingController();
  String _headachePainType = 'throbbing';
  bool _acBlowingOnFace = false;
  final _screenTimeController = TextEditingController();
  String _dischargeColor = 'white';
  bool _dischargeRegular = false;
  final _dischargeStartController = TextEditingController();

  @override
  void dispose() {
    _medicationsController.dispose();
    _surgeryDetailsController.dispose();
    _rednessController.dispose();
    _wateringDaysController.dispose();
    _itchingLocationController.dispose();
    _headacheLocationController.dispose();
    _headacheDurationController.dispose();
    _screenTimeController.dispose();
    _dischargeStartController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() => _currentStep++);
    } else {
      _submitQuestionnaire();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _submitQuestionnaire() {
    // Build follow-up objects
    RednesFollowUp? rednessFollowUp;
    if (_chiefComplaints.hasRedness) {
      rednessFollowUp = RednesFollowUp(duration: _rednessController.text);
    }

    WateringFollowUp? wateringFollowUp;
    if (_chiefComplaints.hasWatering) {
      wateringFollowUp = WateringFollowUp(
        days: int.tryParse(_wateringDaysController.text) ?? 0,
        pattern: _wateringPattern,
      );
    }

    ItchingFollowUp? itchingFollowUp;
    if (_chiefComplaints.hasItching) {
      itchingFollowUp = ItchingFollowUp(
        bothEyes: _itchingBothEyes,
        location: _itchingLocationController.text,
      );
    }

    HeadacheFollowUp? headacheFollowUp;
    if (_chiefComplaints.hasHeadache) {
      headacheFollowUp = HeadacheFollowUp(
        location: _headacheLocationController.text,
        duration: _headacheDurationController.text,
        painType: _headachePainType,
      );
    }

    DrynessFollowUp? drynessFollowUp;
    if (_chiefComplaints.hasDryness) {
      drynessFollowUp = DrynessFollowUp(
        acBlowingOnFace: _acBlowingOnFace,
        screenTimeHours: int.tryParse(_screenTimeController.text) ?? 0,
      );
    }

    DischargeFollowUp? dischargeFollowUp;
    if (_chiefComplaints.hasStickyDischarge) {
      dischargeFollowUp = DischargeFollowUp(
        color: _dischargeColor,
        isRegular: _dischargeRegular,
        startDate: _dischargeStartController.text,
      );
    }

    // Update chief complaints with follow-ups
    _chiefComplaints = _chiefComplaints.copyWith(
      rednessFollowUp: rednessFollowUp,
      wateringFollowUp: wateringFollowUp,
      itchingFollowUp: itchingFollowUp,
      headacheFollowUp: headacheFollowUp,
      drynessFollowUp: drynessFollowUp,
      dischargeFollowUp: dischargeFollowUp,
    );

    final provider = context.read<TestSessionProvider>();
    final questionnaire = QuestionnaireModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      profileId: provider.profileId,
      profileType: provider.profileType,
      timestamp: DateTime.now(),
      chiefComplaints: _chiefComplaints,
      systemicIllness: _systemicIllness,
      currentMedications: _medicationsController.text.isEmpty
          ? null
          : _medicationsController.text,
      hasRecentSurgery: _hasRecentSurgery,
      surgeryDetails: _hasRecentSurgery ? _surgeryDetailsController.text : null,
    );

    provider.setQuestionnaire(questionnaire);
    Navigator.pushNamed(context, '/test-instructions');
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Exit Test?'),
        content: const Text(
          'Your progress will be lost. What would you like to do?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Test'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/home',
                (route) => false,
              );
            },
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pre-Test Questions'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
        ),
        body: Column(
          children: [
            // Progress indicator
            LinearProgressIndicator(
              value: (_currentStep + 1) / 4,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primary,
              ),
            ),
            // Step indicator
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index <= _currentStep
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                  );
                }),
              ),
            ),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildCurrentStep(),
              ),
            ),
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.cardShadow,
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Back', style: TextStyle(fontSize: 13)),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 16),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 1,
                    child: ElevatedButton(
                      onPressed: _nextStep,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _currentStep == 3 ? 'Continue' : 'Next',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildChiefComplaintsStep();
      case 1:
        return _buildFollowUpQuestionsStep();
      case 2:
        return _buildSystemicIllnessStep();
      case 3:
        return _buildAdditionalQuestionsStep();
      default:
        return Container();
    }
  }

  Widget _buildChiefComplaintsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chief Complaints',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select all symptoms you are currently experiencing',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildCheckboxTile(
          title: 'Redness',
          subtitle: 'Red or bloodshot eyes',
          icon: Icons.remove_red_eye,
          value: _chiefComplaints.hasRedness,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasRedness: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Watering',
          subtitle: 'Excessive tearing',
          icon: Icons.water_drop,
          value: _chiefComplaints.hasWatering,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasWatering: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Itching',
          subtitle: 'Itchy or irritated eyes',
          icon: Icons.warning_amber,
          value: _chiefComplaints.hasItching,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasItching: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Headache',
          subtitle: 'Pain around eyes or head',
          icon: Icons.psychology,
          value: _chiefComplaints.hasHeadache,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasHeadache: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Dryness',
          subtitle: 'Dry or gritty feeling',
          icon: Icons.wb_sunny,
          value: _chiefComplaints.hasDryness,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasDryness: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Sticky Discharge',
          subtitle: 'Mucus or discharge from eyes',
          icon: Icons.blur_on,
          value: _chiefComplaints.hasStickyDischarge,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasStickyDischarge: v);
          }),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        _buildYesNoTile(
          title: 'Previous cataract operation?',
          value: _chiefComplaints.hasPreviousCataractOperation,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(
              hasPreviousCataractOperation: v,
            );
          }),
        ),
        _buildYesNoTile(
          title: 'Family history of glaucoma?',
          value: _chiefComplaints.hasFamilyGlaucomaHistory,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(
              hasFamilyGlaucomaHistory: v,
            );
          }),
        ),
      ],
    );
  }

  Widget _buildFollowUpQuestionsStep() {
    final hasFollowUps =
        _chiefComplaints.hasRedness ||
        _chiefComplaints.hasWatering ||
        _chiefComplaints.hasItching ||
        _chiefComplaints.hasHeadache ||
        _chiefComplaints.hasDryness ||
        _chiefComplaints.hasStickyDischarge;

    if (!hasFollowUps) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, size: 64, color: AppColors.success),
          const SizedBox(height: 16),
          Text(
            'No follow-up questions needed',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'You can proceed to the next step',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tell us more',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        if (_chiefComplaints.hasRedness) ...[
          _buildSectionTitle('About Redness'),
          TextFormField(
            controller: _rednessController,
            decoration: const InputDecoration(
              labelText: 'How long has redness been present?',
              hintText: 'e.g., 2 days, 1 week',
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_chiefComplaints.hasWatering) ...[
          _buildSectionTitle('About Watering'),
          TextFormField(
            controller: _wateringDaysController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'How many days?',
              hintText: 'Number of days',
            ),
          ),
          const SizedBox(height: 12),
          Text('Pattern:', style: TextStyle(color: AppColors.textSecondary)),
          AppRadioGroup<String>(
            groupValue: _wateringPattern,
            onChanged: (v) => setState(() => _wateringPattern = v!),
            child: Row(
              children: [
                Flexible(
                  child: AppRadioListTile<String>(
                    title: const Text(
                      'Continuous',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'continuous',
                  ),
                ),
                Flexible(
                  child: AppRadioListTile<String>(
                    title: const Text(
                      'Intermittent',
                      style: TextStyle(fontSize: 13),
                    ),
                    value: 'intermittent',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_chiefComplaints.hasItching) ...[
          _buildSectionTitle('About Itching'),
          SwitchListTile(
            title: const Text('Both eyes affected?'),
            value: _itchingBothEyes,
            onChanged: (v) => setState(() => _itchingBothEyes = v),
            contentPadding: EdgeInsets.zero,
          ),
          TextFormField(
            controller: _itchingLocationController,
            decoration: const InputDecoration(
              labelText: 'Where is the itching located?',
              hintText: 'e.g., corner of eye, eyelid',
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_chiefComplaints.hasHeadache) ...[
          _buildSectionTitle('About Headache'),
          TextFormField(
            controller: _headacheLocationController,
            decoration: const InputDecoration(
              labelText: 'Location of headache',
              hintText: 'e.g., forehead, temples, behind eyes',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _headacheDurationController,
            decoration: const InputDecoration(
              labelText: 'How long does it last?',
              hintText: 'e.g., 1 hour, all day',
            ),
          ),
          const SizedBox(height: 12),
          Text('Pain type:', style: TextStyle(color: AppColors.textSecondary)),
          AppRadioGroup<String>(
            groupValue: _headachePainType,
            onChanged: (v) => setState(() => _headachePainType = v!),
            child: Row(
              children: [
                Expanded(
                  child: AppRadioListTile<String>(
                    title: const Text('Throbbing'),
                    value: 'throbbing',
                  ),
                ),
                Expanded(
                  child: AppRadioListTile<String>(
                    title: const Text('Mild/Dull'),
                    value: 'mild',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_chiefComplaints.hasDryness) ...[
          _buildSectionTitle('About Dryness'),
          SwitchListTile(
            title: const Text('Is AC blowing directly on your face?'),
            value: _acBlowingOnFace,
            onChanged: (v) => setState(() => _acBlowingOnFace = v),
            contentPadding: EdgeInsets.zero,
          ),
          TextFormField(
            controller: _screenTimeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Daily screen time (hours)',
              hintText: 'e.g., 8',
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (_chiefComplaints.hasStickyDischarge) ...[
          _buildSectionTitle('About Discharge'),
          Text(
            'Color of discharge:',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('White'),
                selected: _dischargeColor == 'white',
                onSelected: (s) => setState(() => _dischargeColor = 'white'),
              ),
              ChoiceChip(
                label: const Text('Green'),
                selected: _dischargeColor == 'green',
                onSelected: (s) => setState(() => _dischargeColor = 'green'),
              ),
              ChoiceChip(
                label: const Text('Yellow'),
                selected: _dischargeColor == 'yellow',
                onSelected: (s) => setState(() => _dischargeColor = 'yellow'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Is it regular/recurring?'),
            value: _dischargeRegular,
            onChanged: (v) => setState(() => _dischargeRegular = v),
            contentPadding: EdgeInsets.zero,
          ),
          TextFormField(
            controller: _dischargeStartController,
            decoration: const InputDecoration(
              labelText: 'When did it start?',
              hintText: 'e.g., 3 days ago',
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSystemicIllnessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Medical History',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Select any conditions you have been diagnosed with',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _buildCheckboxTile(
          title: 'Hypertension',
          subtitle: 'High blood pressure',
          icon: Icons.favorite,
          value: _systemicIllness.hasHypertension,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasHypertension: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Diabetes',
          subtitle: 'Type 1 or Type 2 diabetes',
          icon: Icons.bloodtype,
          value: _systemicIllness.hasDiabetes,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasDiabetes: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'COPD',
          subtitle: 'Chronic obstructive pulmonary disease',
          icon: Icons.air,
          value: _systemicIllness.hasCopd,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasCopd: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Asthma',
          subtitle: 'Respiratory condition',
          icon: Icons.air,
          value: _systemicIllness.hasAsthma,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasAsthma: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Migraine',
          subtitle: 'Recurring severe headaches',
          icon: Icons.psychology_alt,
          value: _systemicIllness.hasMigraine,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasMigraine: v);
          }),
        ),
        _buildCheckboxTile(
          title: 'Sinus',
          subtitle: 'Sinus problems or sinusitis',
          icon: Icons.face,
          value: _systemicIllness.hasSinus,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasSinus: v);
          }),
        ),
      ],
    );
  }

  Widget _buildAdditionalQuestionsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Additional Information',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        Text(
          'Current Medications',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _medicationsController,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'List any medications you are currently taking...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        _buildYesNoTile(
          title: 'Any recent surgery?',
          value: _hasRecentSurgery,
          onChanged: (v) => setState(() => _hasRecentSurgery = v),
        ),
        if (_hasRecentSurgery) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _surgeryDetailsController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Surgery Details',
              hintText: 'Type of surgery and when...',
            ),
          ),
        ],
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.info),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your responses will help us provide better recommendations.',
                  style: TextStyle(color: AppColors.info, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
      ),
    );
  }

  Widget _buildCheckboxTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: value ? AppColors.primary : AppColors.border),
      ),
      child: CheckboxListTile(
        value: value,
        onChanged: (v) => onChanged(v ?? false),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        secondary: Icon(
          icon,
          color: value ? AppColors.primary : AppColors.textSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        controlAffinity: ListTileControlAffinity.trailing,
      ),
    );
  }

  Widget _buildYesNoTile({
    required String title,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title)),
          Row(
            children: [
              _buildYesNoButton('No', !value, () => onChanged(false)),
              const SizedBox(width: 8),
              _buildYesNoButton('Yes', value, () => onChanged(true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYesNoButton(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
