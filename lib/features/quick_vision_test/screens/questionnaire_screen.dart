import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../data/models/questionnaire_model.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/services/test_pause_handler.dart';

/// Pre-test questionnaire with dynamic follow-up questions
class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen>
    with WidgetsBindingObserver {
  final TestPauseHandler _pauseHandler = TestPauseHandler();
  final ScrollController _scrollController = ScrollController();
  int _currentStep = 0;
  bool _isMovingForward = true;

  // Chief complaints
  ChiefComplaints _chiefComplaints = ChiefComplaints();

  // Systemic illness
  SystemicIllness _systemicIllness = SystemicIllness();

  // Other fields
  final _medicationsController = TextEditingController();
  bool _hasRecentSurgery = false;
  final _surgeryDetailsController = TextEditingController();

  // Patient details (for guest or incomplete profiles)
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedSex = 'Male';
  bool _needsPatientDetails = false;

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
  bool _lightSensitivitySevere = false;
  final _lightSensitivityDetailController = TextEditingController();
  String _cataractAffectedEye = 'both';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize pause handler
    _pauseHandler.initialize(
      context: context,
      onPause: () {
        debugPrint('[Questionnaire] ⏸️ Paused');
      },
      onResume: () {
        debugPrint('[Questionnaire] ▶️ Resumed');
      },
      getTestName: () => 'Questionnaire',
    );

    // Check if we need patient details
    final provider = context.read<TestSessionProvider>();
    _needsPatientDetails =
        provider.profileId == 'guest_id' || provider.profileAge == null;

    if (_needsPatientDetails) {
      _firstNameController.text = provider.profileName == 'User'
          ? ''
          : provider.profileName;
      if (provider.profileAge != null) {
        _ageController.text = provider.profileAge.toString();
      }
      if (provider.profileSex != null) {
        _selectedSex = provider.profileSex!;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pauseHandler.handleAppPaused();
    } else if (state == AppLifecycleState.resumed) {
      _pauseHandler.handleAppResumed();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _pauseHandler.dispose();
    _medicationsController.dispose();
    _surgeryDetailsController.dispose();
    _rednessController.dispose();
    _wateringDaysController.dispose();
    _itchingLocationController.dispose();
    _headacheLocationController.dispose();
    _headacheDurationController.dispose();
    _screenTimeController.dispose();
    _dischargeStartController.dispose();
    _lightSensitivityDetailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isStepValid() {
    int adjustedStep = _needsPatientDetails ? _currentStep - 1 : _currentStep;

    if (_currentStep == 0 && _needsPatientDetails) {
      return _firstNameController.text.trim().isNotEmpty &&
          _ageController.text.trim().isNotEmpty;
    }

    if (adjustedStep == 0) {
      if (_chiefComplaints.hasRedness &&
          _rednessController.text.trim().isEmpty) {
        return false;
      }
      if (_chiefComplaints.hasWatering &&
          _wateringDaysController.text.trim().isEmpty) {
        return false;
      }
      if (_chiefComplaints.hasItching &&
          _itchingLocationController.text.trim().isEmpty) {
        return false;
      }
      if (_chiefComplaints.hasHeadache &&
          (_headacheLocationController.text.trim().isEmpty ||
              _headacheDurationController.text.trim().isEmpty)) {
        return false;
      }
      if (_chiefComplaints.hasDryness &&
          _screenTimeController.text.trim().isEmpty) {
        return false;
      }
      if (_chiefComplaints.hasStickyDischarge &&
          _dischargeStartController.text.trim().isEmpty) {
        return false;
      }
      if (_chiefComplaints.hasLightSensitivity &&
          _lightSensitivityDetailController.text.trim().isEmpty) {
        return false;
      }
      return true;
    }
    if (adjustedStep == 2) {
      if (_hasRecentSurgery && _surgeryDetailsController.text.trim().isEmpty) {
        return false;
      }
      return true;
    }
    return true; // Step 1 is always valid (systemic illness is optional)
  }

  void _nextStep() {
    if (!_isStepValid()) return;
    int maxSteps = _needsPatientDetails ? 3 : 2;
    if (_currentStep < maxSteps) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _isMovingForward = true;
        _currentStep++;
      });
    } else {
      _submitQuestionnaire();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _isMovingForward = false;
        _currentStep--;
      });
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
      lightSensitivityFollowUp: _chiefComplaints.hasLightSensitivity
          ? LightSensitivityFollowUp(
              isSevere: _lightSensitivitySevere,
              details: _lightSensitivityDetailController.text,
            )
          : null,
      cataractFollowUp: _chiefComplaints.hasPreviousCataractOperation
          ? CataractFollowUp(affectedEye: _cataractAffectedEye)
          : null,
    );

    // Update profile in provider if guest or incomplete
    final provider = context.read<TestSessionProvider>();
    if (_needsPatientDetails) {
      provider.selectSelfProfile(
        provider.profileId,
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            .trim(),
        int.tryParse(_ageController.text),
        _selectedSex,
      );
    }

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
    _pauseHandler.showPauseDialog(
      reason: 'Are you sure you want to exit the questionnaire?',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showExitConfirmation();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('Pre-Test Questions'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: _showExitConfirmation,
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(isLandscape ? 45 : 80),
            child: _buildEyeProgressIndicator(isLandscape),
          ),
        ),
        body: Column(
          children: [
            // Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  20,
                  isLandscape ? 12 : 24,
                  20,
                  (isLandscape ? 12 : 24) +
                      MediaQuery.of(context).viewInsets.bottom,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final isEntering =
                            (child.key as ValueKey).value == _currentStep;
                        final direction = _isMovingForward ? 1.0 : -1.0;

                        return SlideTransition(
                          position:
                              Tween<Offset>(
                                begin: Offset(
                                  isEntering ? direction : -direction,
                                  0.0,
                                ),
                                end: Offset.zero,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeInOut,
                                ),
                              ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  layoutBuilder:
                      (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topCenter,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                  child: _buildCurrentStep(isLandscape),
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isLandscape ? 12 : 24,
                vertical: isLandscape ? 8 : 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _previousStep,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Theme.of(context).dividerColor,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isLandscape ? 10 : 16,
                            ),
                            child: const Text(
                              'Back',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 16),
                    Expanded(
                      child: Opacity(
                        opacity: _isStepValid() ? 1.0 : 0.5,
                        child: ElevatedButton(
                          onPressed: _isStepValid() ? _nextStep : null,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            backgroundColor: Theme.of(context).primaryColor,
                            disabledBackgroundColor: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: isLandscape ? 10 : 16,
                            ),
                            child: Text(
                              _currentStep == (_needsPatientDetails ? 3 : 2)
                                  ? 'Start Test'
                                  : 'Next Step',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
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

  Widget _buildCurrentStep(bool isLandscape) {
    if (_needsPatientDetails) {
      switch (_currentStep) {
        case 0:
          return _buildPatientDetailsStep(isLandscape);
        case 1:
          return _buildChiefComplaintsStep(isLandscape);
        case 2:
          return _buildMedicalHistoryStep(isLandscape);
        case 3:
          return _buildAdditionalQuestionsStep(isLandscape);
        default:
          return Container();
      }
    }

    switch (_currentStep) {
      case 0:
        return _buildChiefComplaintsStep(isLandscape);
      case 1:
        return _buildMedicalHistoryStep(isLandscape);
      case 2:
        return _buildAdditionalQuestionsStep(isLandscape);
      default:
        return Container();
    }
  }

  Widget _buildPatientDetailsStep(bool isLandscape) {
    return Column(
      key: ValueKey(-1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Patient Information',
          'Please provide your details to personalize the test results.',
          isLandscape,
        ),
        SizedBox(height: 8),
        if (isLandscape)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledInput(
                  label: 'First Name',
                  hint: 'Enter first name',
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildLabeledInput(
                  label: 'Last Name',
                  hint: 'Enter last name',
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                ),
              ),
            ],
          )
        else ...[
          _buildLabeledInput(
            label: 'First Name',
            hint: 'Enter first name',
            controller: _firstNameController,
            textCapitalization: TextCapitalization.words,
          ),
          SizedBox(height: 16),
          _buildLabeledInput(
            label: 'Last Name',
            hint: 'Enter last name',
            controller: _lastNameController,
            textCapitalization: TextCapitalization.words,
          ),
        ],
        SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildLabeledInput(
                label: 'Age',
                hint: 'Years',
                controller: _ageController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sex',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildModernSelector<String>(
                    options: {
                      'Male': 'Male',
                      'Female': 'Female',
                      'Other': 'Other',
                    },
                    selectedValue: _selectedSex,
                    onChanged: (v) => setState(() => _selectedSex = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        _buildLabeledInput(
          label: 'Phone (Optional)',
          hint: '10-digit mobile number',
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
        ),
        SizedBox(height: 24),
      ],
    );
  }

  Widget _buildChiefComplaintsStep(bool isLandscape) {
    return Column(
      key: const ValueKey(0),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Eye Symptoms',
          'Select the symptoms you are experiencing. We will ask for more details for selected items.',
          isLandscape,
        ),
        _buildQuestionCard(
          title: 'Redness',
          subtitle: 'Eyes appearing bloodshot or irritated',
          hint:
              'Redness can be caused by allergies, fatigue, or dryness. If accompanied by pain, please consult a specialist immediately.',
          icon: Icons.remove_red_eye_outlined,
          value: _chiefComplaints.hasRedness,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasRedness: v);
          }),
          followUp: _buildLabeledInput(
            label: 'How long has redness been present?',
            hint: 'e.g., 2 days, 1 week',
            controller: _rednessController,
          ),
        ),
        _buildQuestionCard(
          title: 'Watering',
          subtitle: 'Excessive tearing or fluid',
          hint:
              'Excess tearing can be a reflex to dryness or a sign of irritation/inflammation.',
          icon: Icons.water_drop_outlined,
          value: _chiefComplaints.hasWatering,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasWatering: v);
          }),
          followUp: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabeledInput(
                label: 'How many days?',
                hint: 'Number of days',
                controller: _wateringDaysController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Text(
                'Pattern of watering:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildModernSelector<String>(
                options: {
                  'continuous': 'Continuous',
                  'intermittent': 'Intermittent',
                },
                selectedValue: _wateringPattern,
                onChanged: (v) => setState(() => _wateringPattern = v),
              ),
            ],
          ),
        ),
        _buildQuestionCard(
          title: 'Itching',
          subtitle: 'Irritated or prickly feeling',
          hint:
              'Itching is often a symptom of allergic conjunctivitis. Avoid rubbing your eyes as it can worsen irritation.',
          icon: Icons.front_hand_outlined,
          value: _chiefComplaints.hasItching,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasItching: v);
          }),
          followUp: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Both eyes affected?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSlidableToggle(
                      value: _itchingBothEyes,
                      onChanged: (v) => setState(() => _itchingBothEyes = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildLabeledInput(
                label: 'Where is the itching located?',
                hint: 'e.g., corner of eye, eyelid',
                controller: _itchingLocationController,
              ),
            ],
          ),
        ),
        _buildQuestionCard(
          title: 'Headache',
          subtitle: 'Pain around eyes or head',
          hint:
              'Persistent headaches can be related to eye strain or uncorrected vision. Documenting the location helps our assessment.',
          icon: Icons.psychology_outlined,
          value: _chiefComplaints.hasHeadache,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasHeadache: v);
          }),
          followUp: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Use Column instead of Row for mobile responsiveness to avoid overflow
              _buildLabeledInput(
                label: 'Location',
                hint: 'e.g., Forehead, temples',
                controller: _headacheLocationController,
              ),
              const SizedBox(height: 12),
              _buildLabeledInput(
                label: 'Duration',
                hint: 'e.g., 1 hour, constant',
                controller: _headacheDurationController,
              ),
              const SizedBox(height: 16),
              Text(
                'Type of Pain:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildModernSelector<String>(
                options: {'throbbing': 'Throbbing', 'mild': 'Mild / Dull'},
                selectedValue: _headachePainType,
                onChanged: (v) => setState(() => _headachePainType = v),
              ),
            ],
          ),
        ),
        _buildQuestionCard(
          title: 'Dryness',
          subtitle: 'Dry or gritty feeling',
          hint:
              'Dryness is common with extended screen use or in AC environments. It can make eyes feel gritty or like sand is present.',
          icon: Icons.grain_outlined,
          value: _chiefComplaints.hasDryness,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasDryness: v);
          }),
          followUp: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'AC blowing on face?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSlidableToggle(
                      value: _acBlowingOnFace,
                      onChanged: (v) => setState(() => _acBlowingOnFace = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildLabeledInput(
                label: 'Daily screen time (hours)',
                hint: 'e.g., 8',
                controller: _screenTimeController,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        _buildQuestionCard(
          title: 'Sticky Discharge',
          subtitle: 'Mucus or buildup around lids',
          hint:
              'Discharge can range from watery to thick/crusty. Green or yellow discharge may indicate a bacterial infection.',
          icon: Icons.bubble_chart_outlined,
          value: _chiefComplaints.hasStickyDischarge,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(hasStickyDischarge: v);
          }),
          followUp: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Color of discharge:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildModernSelector<String>(
                options: {
                  'white': 'White',
                  'green': 'Green',
                  'yellow': 'Yellow',
                },
                selectedValue: _dischargeColor,
                onChanged: (v) => setState(() => _dischargeColor = v),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Is it recurring?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSlidableToggle(
                      value: _dischargeRegular,
                      onChanged: (v) => setState(() => _dischargeRegular = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildLabeledInput(
                label: 'When did it start?',
                hint: 'e.g., 3 days ago',
                controller: _dischargeStartController,
              ),
            ],
          ),
        ),
        _buildQuestionCard(
          title: 'Light Sensitivity',
          subtitle: 'Discomfort or pain from bright light',
          hint:
              'Photophobia can be caused by dry eyes, migraine, or inflammation. Documenting severity helps our assessment.',
          icon: Icons.lightbulb_outline,
          value: _chiefComplaints.hasLightSensitivity,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(
              hasLightSensitivity: v,
            );
          }),
          followUp: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Is it severe?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSlidableToggle(
                      value: _lightSensitivitySevere,
                      onChanged: (v) =>
                          setState(() => _lightSensitivitySevere = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _buildLabeledInput(
                label: 'When does it happen?',
                hint: 'e.g., sunlight, bright lamps',
                controller: _lightSensitivityDetailController,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Other Eye History'),
        _buildBooleanCard(
          title: 'Previous cataract operation?',
          hint:
              'A cataract is the clouding of the eye\'s lens. Surgery involves replacing it with an artificial Intraocular Lens (IOL).',
          value: _chiefComplaints.hasPreviousCataractOperation,
          onChanged: (v) => setState(() {
            _chiefComplaints = _chiefComplaints.copyWith(
              hasPreviousCataractOperation: v,
            );
          }),
          followUp: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Which eye was operated on?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _buildModernSelector<String>(
                options: {'left': 'Left', 'right': 'Right', 'both': 'Both'},
                selectedValue: _cataractAffectedEye,
                onChanged: (v) => setState(() => _cataractAffectedEye = v),
              ),
            ],
          ),
        ),
        _buildBooleanCard(
          title: 'Family history of glaucoma?',
          hint:
              'Glaucoma is a group of eye conditions that damage the optic nerve, often due to high eye pressure. It can be hereditary.',
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

  Widget _buildMedicalHistoryStep(bool isLandscape) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Health Records',
          'Please select any medical conditions you have. This helps us analyze eye-health correlations.',
          isLandscape,
        ),
        _buildQuestionCard(
          title: 'Hypertension',
          subtitle: 'High blood pressure',
          hint:
              'Hypertension (High BP) can damage the small blood vessels in the retina, leading to hypertensive retinopathy.',
          icon: Icons.favorite_border_rounded,
          value: _systemicIllness.hasHypertension,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasHypertension: v);
          }),
        ),
        _buildQuestionCard(
          title: 'Diabetes',
          subtitle: 'Type 1 or Type 2',
          hint:
              'Diabetes can cause Diabetic Retinopathy, affecting the light-sensitive tissue at the back of the eye.',
          icon: Icons.water_drop_outlined,
          value: _systemicIllness.hasDiabetes,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasDiabetes: v);
          }),
        ),
        _buildQuestionCard(
          title: 'COPD',
          subtitle: 'Chronic lung disease',
          hint:
              'Chronic Obstructive Pulmonary Disease makes breathing difficult and can affect overall blood oxygenation.',
          icon: Icons.air_rounded,
          value: _systemicIllness.hasCopd,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasCopd: v);
          }),
        ),
        _buildQuestionCard(
          title: 'Asthma',
          subtitle: 'Respiratory condition',
          hint:
              'A chronic condition that affects the airways. Some medications for asthma may have ocular side effects.',
          icon: Icons.air_rounded,
          value: _systemicIllness.hasAsthma,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasAsthma: v);
          }),
        ),
        _buildQuestionCard(
          title: 'Migraine',
          subtitle: 'Recurring severe headaches',
          hint:
              'Migraines can have visual symptoms (aura) such as flashing lights or temporary vision loss.',
          icon: Icons.wb_twilight_rounded,
          value: _systemicIllness.hasMigraine,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasMigraine: v);
          }),
        ),
        _buildQuestionCard(
          title: 'Sinus',
          subtitle: 'Sinus problems or congestion',
          hint:
              'Sinus inflammation can cause pressure that feels like pain behind the eyes or in the orbital area.',
          icon: Icons.face_rounded,
          value: _systemicIllness.hasSinus,
          onChanged: (v) => setState(() {
            _systemicIllness = _systemicIllness.copyWith(hasSinus: v);
          }),
        ),
      ],
    );
  }

  Widget _buildAdditionalQuestionsStep(bool isLandscape) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader(
          'Final Details',
          'Almost done! Please fill in these last few clinical details.',
          isLandscape,
        ),
        _buildLabeledInput(
          label: 'Are you currently on any medications?',
          hint: 'e.g. Daily eye drops, BP medicine...',
          controller: _medicationsController,
          maxLines: 4,
        ),
        const SizedBox(height: 24),
        _buildBooleanCard(
          title: 'Have you had any recent surgery?',
          hint:
              'Please mention any ocular or major systemic surgeries performed in the last 6 months.',
          value: _hasRecentSurgery,
          onChanged: (v) => setState(() => _hasRecentSurgery = v),
          followUp: _buildLabeledInput(
            label: 'Please specify the surgery details',
            hint: 'Type of surgery, date, etc.',
            controller: _surgeryDetailsController,
            maxLines: 3,
          ),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: Theme.of(context).primaryColor,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Your privacy is important. This information is shared only with your examining clinician.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStepHeader(String title, String subtitle, bool isLandscape) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLandscape ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isLandscape ? 20 : 28,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -1.0,
            ),
          ),
          if (!isLandscape) ...[
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.6),
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuestionCard({
    required String title,
    required String subtitle,
    required String hint,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
    Widget? followUp,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: value
              ? Theme.of(context).primaryColor
              : Theme.of(context).dividerColor.withValues(alpha: 0.35),
          width: value ? 2 : 1,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -2,
                ),
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onChanged(!value),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: value
                            ? Theme.of(context).primaryColor
                            : Theme.of(
                                context,
                              ).dividerColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: value
                            ? [
                                BoxShadow(
                                  color: Theme.of(
                                    context,
                                  ).primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ]
                            : [],
                      ),
                      child: Icon(
                        icon,
                        color: value
                            ? Colors.white
                            : Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: value
                                        ? Theme.of(context).primaryColor
                                        : Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                    fontSize: 16,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              _buildHintButton(title, hint),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Transform.scale(
                      scale: 1.15,
                      child: Checkbox(
                        value: value,
                        onChanged: (v) => onChanged(v ?? false),
                        activeColor: Theme.of(context).primaryColor,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: value
                              ? Theme.of(context).primaryColor
                              : Theme.of(context).dividerColor,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: value
                      ? Theme.of(context).primaryColor.withValues(alpha: 0.03)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                  ),
                ),
                child: followUp ?? const SizedBox(),
              ),
            ),
            crossFadeState: value && followUp != null
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSelector<T>({
    required Map<T, String> options,
    required T selectedValue,
    required Function(T) onChanged,
  }) {
    // For 2-3 options, display in a single row with equal width
    if (options.length <= 3) {
      return Row(
        children: options.entries.map((entry) {
          final isSelected = selectedValue == entry.key;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(
                              context,
                            ).dividerColor.withValues(alpha: 0.5),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    // For more than 3 options, use Wrap
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.entries.map((entry) {
        final isSelected = selectedValue == entry.key;
        return GestureDetector(
          onTap: () => onChanged(entry.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: Theme.of(
                          context,
                        ).primaryColor.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              entry.value,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBooleanCard({
    required String title,
    required String hint,
    required bool value,
    required Function(bool) onChanged,
    Widget? followUp,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: value
              ? Theme.of(context).primaryColor
              : Theme.of(context).dividerColor.withValues(alpha: 0.35),
          width: value ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: value
                ? Theme.of(context).primaryColor.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.shadow.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: value
                                ? Theme.of(context).primaryColor
                                : Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      _buildHintButton(title, hint),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildSlidableToggle(value: value, onChanged: onChanged),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.05),
                  ),
                ),
                child: followUp ?? const SizedBox(),
              ),
            ),
            crossFadeState: value && followUp != null
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  Widget _buildHintButton(String title, String hint) {
    return GestureDetector(
      onTap: () => _showPremiumHint(title, hint),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.question_mark_rounded,
          size: 14,
          color: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  void _showPremiumHint(String title, String hint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              hint,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.onSurface,
                height: 1.6,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledInput({
    required String label,
    required String hint,
    required TextEditingController controller,
    TextInputType? keyboardType,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          onChanged: (v) => setState(() {}),
          scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: Theme.of(context).cardColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).primaryColor,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEyeProgressIndicator(bool isLandscape) {
    return Container(
      padding: EdgeInsets.only(
        bottom: isLandscape ? 12 : 24,
        left: 32,
        right: 32,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_needsPatientDetails ? 4 : 3, (index) {
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;
          final nodeSize = isLandscape
              ? (isActive ? 32.0 : 28.0)
              : (isActive ? 42.0 : 36.0);

          IconData getNodeIcon() {
            if (_needsPatientDetails) {
              switch (index) {
                case 0:
                  return Icons.person_rounded;
                case 1:
                  return Icons.visibility_rounded;
                case 2:
                  return Icons.health_and_safety_rounded;
                default:
                  return Icons.checklist_rounded;
              }
            } else {
              switch (index) {
                case 0:
                  return Icons.visibility_rounded;
                case 1:
                  return Icons.health_and_safety_rounded;
                default:
                  return Icons.checklist_rounded;
              }
            }
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Node
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: nodeSize,
                height: nodeSize,
                decoration: BoxDecoration(
                  color: isActive || isCompleted
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isActive || isCompleted
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                    width: isActive ? (isLandscape ? 2 : 3) : 1,
                  ),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.3),
                            blurRadius: isLandscape ? 6 : 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  getNodeIcon(),
                  color: isActive || isCompleted
                      ? Colors.white
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.5),
                  size: isLandscape
                      ? (isActive ? 16 : 14)
                      : (isActive ? 20 : 18),
                ),
              ),
              // Line
              if (index < (_needsPatientDetails ? 3 : 2))
                Container(
                  width: isLandscape ? (_needsPatientDetails ? 20 : 30) : 40,
                  height: isLandscape ? 2 : 3,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: index < _currentStep
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSlidableToggle({
    required bool value,
    required Function(bool) onChanged,
    String leftLabel = 'No',
    String rightLabel = 'Yes',
  }) {
    return _DraggableToggle(
      value: value,
      onChanged: onChanged,
      leftLabel: leftLabel,
      rightLabel: rightLabel,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DraggableToggle extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;
  final String leftLabel;
  final String rightLabel;

  const _DraggableToggle({
    required this.value,
    required this.onChanged,
    required this.leftLabel,
    required this.rightLabel,
  });

  @override
  State<_DraggableToggle> createState() => _DraggableToggleState();
}

class _DraggableToggleState extends State<_DraggableToggle> {
  double? _dragPosition;
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    const double toggleWidth = 140;
    const double thumbWidth = 70;
    const double maxDragPosition = toggleWidth - thumbWidth - 8;

    // Calculate thumb position
    double thumbPosition;
    if (_isDragging && _dragPosition != null) {
      thumbPosition = _dragPosition!.clamp(0.0, maxDragPosition);
    } else {
      thumbPosition = widget.value ? maxDragPosition : 0;
    }

    return GestureDetector(
      onHorizontalDragStart: (details) {
        setState(() {
          _isDragging = true;
          // Start from the current actual position to avoid jumping
          _dragPosition = widget.value ? maxDragPosition : 0;
        });
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragPosition = (_dragPosition ?? 0) + details.delta.dx;
        });
      },
      onHorizontalDragEnd: (details) {
        // Snap to the closest side
        final shouldBeOn = thumbPosition > maxDragPosition / 2;
        if (shouldBeOn != widget.value) {
          widget.onChanged(shouldBeOn);
        }
        setState(() {
          _isDragging = false;
          _dragPosition = null;
        });
      },
      onTap: () => widget.onChanged(!widget.value),
      child: Container(
        width: toggleWidth,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
            // Animated background slider
            AnimatedPositioned(
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              left: thumbPosition + 4,
              top: 4,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: thumbWidth,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: _isDragging ? 0.12 : 0.08,
                      ),
                      blurRadius: _isDragging ? 12 : 8,
                      offset: Offset(0, _isDragging ? 3 : 2),
                    ),
                  ],
                ),
              ),
            ),
            // Labels
            IgnorePointer(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.leftLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: thumbPosition < maxDragPosition / 2
                              ? Theme.of(context).primaryColor
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        widget.rightLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: thumbPosition >= maxDragPosition / 2
                              ? Theme.of(context).primaryColor
                              : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withValues(alpha: 0.6),
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
}
