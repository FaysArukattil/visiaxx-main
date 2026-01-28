import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/patient_questionnaire_service.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/models/questionnaire_model.dart';

/// Screen for adding a new patient with pre-test questionnaire
/// Used by receptionists in eye camp workflow
class AddPatientQuestionnaireScreen extends StatefulWidget {
  const AddPatientQuestionnaireScreen({super.key});

  @override
  State<AddPatientQuestionnaireScreen> createState() =>
      _AddPatientQuestionnaireScreenState();
}

class _AddPatientQuestionnaireScreenState
    extends State<AddPatientQuestionnaireScreen> {
  // Services
  final PatientService _patientService = PatientService();
  final PatientQuestionnaireService _questionnaireService =
      PatientQuestionnaireService();

  // Step tracker
  int _currentStep = 0; // 0 = Patient Details, 1-3 = Questionnaire steps
  bool _isMovingForward = true;
  final ScrollController _scrollController = ScrollController();

  // Patient form
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedSex;

  // Saved patient (after step 0)
  PatientModel? _savedPatient;
  String? _savedPatientId;

  // Questionnaire data
  ChiefComplaints _chiefComplaints = ChiefComplaints();
  SystemicIllness _systemicIllness = SystemicIllness();
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
  bool _lightSensitivitySevere = false;
  final _lightSensitivityDetailController = TextEditingController();
  String _cataractAffectedEye = 'both';

  @override
  void dispose() {
    _scrollController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
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
    super.dispose();
  }

  String get _stepTitle {
    switch (_currentStep) {
      case 0:
        return 'Patient Details';
      case 1:
        return 'Eye Symptoms';
      case 2:
        return 'Health Records';
      case 3:
        return 'Additional Info';
      default:
        return 'Add Patient';
    }
  }

  String get _stepSubtitle {
    final patientName = _firstNameController.text.isNotEmpty
        ? ' for ${_firstNameController.text}'
        : '';
    switch (_currentStep) {
      case 0:
        return 'Enter patient information';
      case 1:
        return 'Select symptoms$patientName';
      case 2:
        return 'Medical conditions$patientName';
      case 3:
        return 'Medications and surgery history$patientName';
      default:
        return '';
    }
  }

  bool _isStepValid() {
    if (_currentStep == 0) {
      final isFormValid = _formKey.currentState?.validate() ?? false;
      return isFormValid && _selectedSex != null;
    }
    if (_currentStep == 1) {
      // Validate required follow-ups
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
    if (_currentStep == 3) {
      if (_hasRecentSurgery && _surgeryDetailsController.text.trim().isEmpty) {
        return false;
      }
      return true;
    }
    return true;
  }

  Future<void> _nextStep() async {
    if (!_isStepValid()) return;

    if (_currentStep == 0) {
      // Save patient first
      await _savePatient();
    } else if (_currentStep == 3) {
      // Final step - save questionnaire
      await _saveQuestionnaire();
      return;
    }

    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    setState(() {
      _isMovingForward = true;
      _currentStep++;
    });
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

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      SnackbarUtils.showError(context, 'Please log in to add patients');
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: EyeLoader.fullScreen()),
    );

    final newPatient = PatientModel(
      id: _savedPatientId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim().isEmpty
          ? null
          : _lastNameController.text.trim(),
      age: int.parse(_ageController.text),
      sex: _selectedSex!,
      phone: _phoneController.text.trim().isEmpty
          ? null
          : '+91${_phoneController.text.trim()}',
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      createdAt: _savedPatient?.createdAt ?? DateTime.now(),
    );

    // If data hasn't changed, don't re-save to avoid redundant network calls
    if (_savedPatient != null &&
        _savedPatient!.firstName == newPatient.firstName &&
        _savedPatient!.lastName == newPatient.lastName &&
        _savedPatient!.age == newPatient.age &&
        _savedPatient!.sex == newPatient.sex &&
        _savedPatient!.phone == newPatient.phone &&
        _savedPatient!.notes == newPatient.notes) {
      // Data is same, just move to next step
      return;
    }

    try {
      final savedId = await _patientService.savePatient(
        practitionerId: user.uid,
        patient: newPatient,
      );

      _savedPatient = newPatient.copyWith(id: savedId);
      _savedPatientId = savedId;

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      SnackbarUtils.showSuccess(
        context,
        'Patient saved. Now add pre-test questions.',
      );
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      SnackbarUtils.showError(context, 'Failed to save patient: $e');
    }
  }

  Future<void> _saveQuestionnaire() async {
    if (_savedPatient == null || _savedPatientId == null) {
      SnackbarUtils.showError(context, 'Patient data not saved');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: EyeLoader.fullScreen()),
    );

    try {
      // Build follow-up objects
      final chiefComplaints = _buildChiefComplaintsWithFollowUps();

      final questionnaire = QuestionnaireModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        profileId: _savedPatientId!,
        profileType: 'patient',
        timestamp: DateTime.now(),
        chiefComplaints: chiefComplaints,
        systemicIllness: _systemicIllness,
        currentMedications: _medicationsController.text.isEmpty
            ? null
            : _medicationsController.text,
        hasRecentSurgery: _hasRecentSurgery,
        surgeryDetails: _hasRecentSurgery
            ? _surgeryDetailsController.text
            : null,
      );

      await _questionnaireService.savePatientQuestionnaire(
        practitionerId: user.uid,
        patientId: _savedPatientId!,
        questionnaire: questionnaire,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      SnackbarUtils.showSuccess(
        context,
        '${_savedPatient!.fullName} added with pre-test questions',
      );

      // Navigate back
      Navigator.pop(context, true);
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (!mounted) return;
      SnackbarUtils.showError(context, 'Failed to save questionnaire: $e');
    }
  }

  ChiefComplaints _buildChiefComplaintsWithFollowUps() {
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

    LightSensitivityFollowUp? lightFollowUp;
    if (_chiefComplaints.hasLightSensitivity) {
      lightFollowUp = LightSensitivityFollowUp(
        isSevere: _lightSensitivitySevere,
        details: _lightSensitivityDetailController.text,
      );
    }

    CataractFollowUp? cataractFollowUp;
    if (_chiefComplaints.hasPreviousCataractOperation) {
      cataractFollowUp = CataractFollowUp(affectedEye: _cataractAffectedEye);
    }

    return _chiefComplaints.copyWith(
      rednessFollowUp: rednessFollowUp,
      wateringFollowUp: wateringFollowUp,
      itchingFollowUp: itchingFollowUp,
      headacheFollowUp: headacheFollowUp,
      drynessFollowUp: drynessFollowUp,
      dischargeFollowUp: dischargeFollowUp,
      lightSensitivityFollowUp: lightFollowUp,
      cataractFollowUp: cataractFollowUp,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLandscape = size.width > size.height;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_currentStep > 0) {
          _previousStep();
        } else {
          final shouldExit = await _showExitConfirmation();
          if (shouldExit && mounted) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () {
              if (_currentStep > 0) {
                _previousStep();
              } else {
                Navigator.pop(context);
              }
            },
          ),
          title: Text(
            _stepTitle,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(isLandscape ? 30 : 60),
            child: _buildProgressIndicator(isLandscape),
          ),
        ),
        body: Column(
          children: [
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
            _buildBottomNavigation(isLandscape),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isLandscape) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isLandscape ? 8 : 12,
      ),
      child: Row(
        children: List.generate(4, (index) {
          final isActive = index <= _currentStep;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.primary
                    : AppColors.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep(bool isLandscape) {
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

  Widget _buildResponsiveGrid({
    required List<Widget> children,
    required bool isLandscape,
    double crossAxisSpacing = 20,
    double mainAxisSpacing = 0,
  }) {
    if (!isLandscape) {
      return Column(
        children: children
            .expand((w) => [w, SizedBox(height: mainAxisSpacing)])
            .toList(),
      );
    }

    final List<Widget> rows = [];
    for (int i = 0; i < children.length; i += 2) {
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: mainAxisSpacing),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[i]),
              SizedBox(width: crossAxisSpacing),
              Expanded(
                child: i + 1 < children.length ? children[i + 1] : Container(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildPatientDetailsStep(bool isLandscape) {
    return Container(
      key: const ValueKey(0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStepHeader('Patient Information', _stepSubtitle, isLandscape),
            SizedBox(height: isLandscape ? 8 : 24),
            // Use 2 columns in landscape for details to save space
            if (isLandscape)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _firstNameController,
                                label: 'First Name',
                                hint: 'First name',
                                textCapitalization: TextCapitalization.words,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTextField(
                                controller: _lastNameController,
                                label: 'Last Name',
                                hint: 'Last name',
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _ageController,
                          label: 'Age',
                          hint: 'Enter age',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final age = int.tryParse(value);
                            if (age == null || age < 1 || age > 150) {
                              return 'Invalid age';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sex',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        PremiumDropdown<String>(
                          label: 'Sex',
                          hintText: 'Select a gender',
                          value: _selectedSex,
                          items: const ['Male', 'Female', 'Other'],
                          itemLabelBuilder: (item) => item,
                          onChanged: (value) =>
                              setState(() => _selectedSex = value),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _phoneController,
                          label: 'Phone',
                          hint: '10-digit mobile number',
                          keyboardType: TextInputType.phone,
                          prefixText: '+91 ',
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          controller: _notesController,
                          label: 'Notes (Optional)',
                          hint: 'Any additional notes about the patient',
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ],
              )
            else ...[
              // Name row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: _firstNameController,
                      label: 'First Name',
                      hint: 'First name',
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: _lastNameController,
                      label: 'Last Name',
                      hint: 'Last name',
                      textCapitalization: TextCapitalization.words,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Age
              _buildTextField(
                controller: _ageController,
                label: 'Age',
                hint: 'Enter age',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Required';
                  final age = int.tryParse(value);
                  if (age == null || age < 1 || age > 150) return 'Invalid age';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Sex
              const Text(
                'Sex',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              PremiumDropdown<String>(
                label: 'Sex',
                hintText: 'Select a gender',
                value: _selectedSex,
                items: const ['Male', 'Female', 'Other'],
                itemLabelBuilder: (item) => item,
                onChanged: (value) => setState(() => _selectedSex = value),
              ),
              const SizedBox(height: 16),
              // Phone
              _buildTextField(
                controller: _phoneController,
                label: 'Phone',
                hint: '10-digit mobile number',
                keyboardType: TextInputType.phone,
                prefixText: '+91 ',
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
              ),
              // Notes
              const SizedBox(height: 16),
              _buildTextField(
                controller: _notesController,
                label: 'Notes (Optional)',
                hint: 'Any additional notes about the patient',
                maxLines: 3,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChiefComplaintsStep(bool isLandscape) {
    return Column(
      key: const ValueKey(1),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Eye Symptoms', _stepSubtitle, isLandscape),
        const SizedBox(height: 16),
        _buildResponsiveGrid(
          isLandscape: isLandscape,
          mainAxisSpacing: 0,
          children: [
            _buildQuestionCard(
              title: 'Redness',
              subtitle: 'Eyes appearing bloodshot',
              hint:
                  'Redness can be caused by allergies, fatigue, or dryness. If accompanied by pain, please consult a specialist immediately.',
              icon: Icons.remove_red_eye_outlined,
              value: _chiefComplaints.hasRedness,
              onChanged: (v) => setState(() {
                _chiefComplaints = _chiefComplaints.copyWith(hasRedness: v);
              }),
              followUp: _buildLabeledInput(
                controller: _rednessController,
                label: 'Duration',
                hint: 'e.g., 2 days, 1 week',
              ),
            ),
            _buildQuestionCard(
              title: 'Watering',
              subtitle: 'Excessive tearing',
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
                    controller: _wateringDaysController,
                    label: 'Days',
                    hint: 'Number of days',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pattern of watering:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
              subtitle: 'Irritated feeling',
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
                        const Expanded(
                          child: Text(
                            'Both eyes affected?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSlidableToggle(
                          value: _itchingBothEyes,
                          onChanged: (v) =>
                              setState(() => _itchingBothEyes = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabeledInput(
                    controller: _itchingLocationController,
                    label: 'Location',
                    hint: 'e.g., corner of eye',
                  ),
                ],
              ),
            ),
            _buildQuestionCard(
              title: 'Headache',
              subtitle: 'Pain around eyes/head',
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
                  _buildLabeledInput(
                    controller: _headacheLocationController,
                    label: 'Location',
                    hint: 'e.g., Forehead',
                  ),
                  const SizedBox(height: 12),
                  _buildLabeledInput(
                    controller: _headacheDurationController,
                    label: 'Duration',
                    hint: 'e.g., 1 hour',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Type of Pain:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModernSelector(
                    options: {'throbbing': 'Throbbing', 'mild': 'Mild'},
                    selectedValue: _headachePainType,
                    onChanged: (v) => setState(() => _headachePainType = v),
                  ),
                ],
              ),
            ),
            _buildQuestionCard(
              title: 'Dryness',
              subtitle: 'Dry/gritty feeling',
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
                        const Expanded(
                          child: Text(
                            'AC blowing on face?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSlidableToggle(
                          value: _acBlowingOnFace,
                          onChanged: (v) =>
                              setState(() => _acBlowingOnFace = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabeledInput(
                    controller: _screenTimeController,
                    label: 'Daily screen time (hours)',
                    hint: 'e.g., 8',
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            _buildQuestionCard(
              title: 'Sticky Discharge',
              subtitle: 'Mucus around lids',
              hint:
                  'Discharge can range from watery to thick/crusty. Green or yellow discharge may indicate a bacterial infection.',
              icon: Icons.bubble_chart_outlined,
              value: _chiefComplaints.hasStickyDischarge,
              onChanged: (v) => setState(() {
                _chiefComplaints = _chiefComplaints.copyWith(
                  hasStickyDischarge: v,
                );
              }),
              followUp: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Color of discharge:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildModernSelector(
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
                        const Expanded(
                          child: Text(
                            'Is it recurring?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildSlidableToggle(
                          value: _dischargeRegular,
                          onChanged: (v) =>
                              setState(() => _dischargeRegular = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildLabeledInput(
                    controller: _dischargeStartController,
                    label: 'When did it start?',
                    hint: 'e.g., 3 days ago',
                  ),
                ],
              ),
            ),
            _buildQuestionCard(
              title: 'Light Sensitivity',
              subtitle: 'Discomfort from bright light',
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
                        const Expanded(
                          child: Text(
                            'Is it severe?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
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
                  const SizedBox(height: 12),
                  _buildLabeledInput(
                    controller: _lightSensitivityDetailController,
                    label: 'When does it happen?',
                    hint: 'e.g., sunlight',
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader('Other Eye History'),
        _buildResponsiveGrid(
          isLandscape: isLandscape,
          children: [
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
                  const Text(
                    'Which eye was operated on?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
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
        ),
      ],
    );
  }

  Widget _buildMedicalHistoryStep(bool isLandscape) {
    return Column(
      key: const ValueKey(2),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Health Records', _stepSubtitle, isLandscape),
        const SizedBox(height: 16),
        _buildResponsiveGrid(
          isLandscape: isLandscape,
          children: [
            _buildQuestionCard(
              title: 'Hypertension',
              subtitle: 'High blood pressure',
              hint:
                  'Hypertension (High BP) can damage the small blood vessels in the retina, leading to hypertensive retinopathy.',
              icon: Icons.favorite_border_rounded,
              value: _systemicIllness.hasHypertension,
              onChanged: (v) => setState(() {
                _systemicIllness = _systemicIllness.copyWith(
                  hasHypertension: v,
                );
              }),
            ),
            _buildQuestionCard(
              title: 'Diabetes',
              subtitle: 'High blood sugar',
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
              subtitle: 'Severe headaches',
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
              subtitle: 'Congestion/Pressure',
              hint:
                  'Sinus inflammation can cause pressure that feels like pain behind the eyes or in the orbital area.',
              icon: Icons.face_rounded,
              value: _systemicIllness.hasSinus,
              onChanged: (v) => setState(() {
                _systemicIllness = _systemicIllness.copyWith(hasSinus: v);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdditionalQuestionsStep(bool isLandscape) {
    return Column(
      key: const ValueKey(3),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildStepHeader('Additional Information', _stepSubtitle, isLandscape),
        const SizedBox(height: 16),
        if (isLandscape)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildLabeledInput(
                  controller: _medicationsController,
                  label: 'Current Medications (Optional)',
                  hint: 'List any medications being taken',
                  maxLines: 5,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildBooleanCard(
                  title: 'Recent eye surgery?',
                  hint:
                      'Please mention any ocular or major systemic surgeries performed in the last 6 months.',
                  value: _hasRecentSurgery,
                  onChanged: (v) => setState(() => _hasRecentSurgery = v),
                  followUp: _buildLabeledInput(
                    controller: _surgeryDetailsController,
                    label: 'Surgery Details',
                    hint: 'Type of surgery and when',
                    maxLines: 2,
                  ),
                ),
              ),
            ],
          )
        else ...[
          _buildLabeledInput(
            controller: _medicationsController,
            label: 'Current Medications (Optional)',
            hint: 'List any medications being taken',
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          _buildBooleanCard(
            title: 'Recent eye surgery?',
            hint:
                'Please mention any ocular or major systemic surgeries performed in the last 6 months.',
            value: _hasRecentSurgery,
            onChanged: (v) => setState(() => _hasRecentSurgery = v),
            followUp: _buildLabeledInput(
              controller: _surgeryDetailsController,
              label: 'Surgery Details',
              hint: 'Type of surgery and when',
              maxLines: 2,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomNavigation(bool isLandscape) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isLandscape ? 48 : 20,
        vertical: isLandscape ? 12 : 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _previousStep,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Back',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isStepValid() ? _nextStep : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor: AppColors.primary.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      _currentStep == 3 ? 'Save Patient' : 'Next',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildStepHeader(String title, String subtitle, bool isLandscape) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isLandscape ? 20 : 22,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        if (!isLandscape) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          validator: validator,
          scrollPadding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 120,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefixText,
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: value
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.35),
          width: value ? 2 : 1,
        ),
        boxShadow: value
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                  spreadRadius: -2,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
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
                        color: value ? AppColors.primary : Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: value ? Colors.white : AppColors.textSecondary,
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
                                        ? AppColors.primary
                                        : AppColors.textPrimary,
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                        activeColor: AppColors.primary,
                        checkColor: Colors.white,
                        side: BorderSide(
                          color: value ? AppColors.primary : AppColors.border,
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
                      ? AppColors.primary.withValues(alpha: 0.03)
                      : AppColors.border.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
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
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: value
              ? AppColors.primary
              : AppColors.border.withValues(alpha: 0.35),
          width: value ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: value
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
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
                                ? AppColors.primary
                                : AppColors.textPrimary,
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
                  color: AppColors.primary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
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
          color: AppColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.question_mark_rounded,
          size: 14,
          color: AppColors.primary,
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
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  color: AppColors.border.withValues(alpha: 0.5),
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
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              hint,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
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
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.border.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
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

  Widget _buildSlidableToggle({
    required bool value,
    required Function(bool) onChanged,
  }) {
    return _DraggableToggle(value: value, onChanged: onChanged);
  }

  Widget _buildModernSelector<T>({
    required Map<T, String> options,
    required T selectedValue,
    required Function(T) onChanged,
  }) {
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
                  color: isSelected ? AppColors.primary : AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.border.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.bold
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 16),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Setup?'),
        content: const Text(
          'All progress for this patient will be lost. Are you sure you want to exit?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Setup'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Exit', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _DraggableToggle extends StatefulWidget {
  final bool value;
  final Function(bool) onChanged;

  const _DraggableToggle({required this.value, required this.onChanged});

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
          _dragPosition = widget.value ? maxDragPosition : 0;
        });
      },
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragPosition = (_dragPosition ?? 0) + details.delta.dx;
        });
      },
      onHorizontalDragEnd: (details) {
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
          color: AppColors.border.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Stack(
          children: [
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
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            IgnorePointer(
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        'No',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: thumbPosition < maxDragPosition / 2
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Yes',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: thumbPosition >= maxDragPosition / 2
                              ? AppColors.primary
                              : AppColors.textSecondary,
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
