import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/services/patient_service.dart';
import '../../../core/services/patient_questionnaire_service.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/models/questionnaire_model.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/widgets/premium_search_bar.dart';

/// Profile selection screen for practitioners
/// Shows "Add Patient" instead of "Test for Yourself"
/// No relationship field for patients
class PractitionerProfileSelectionScreen extends StatefulWidget {
  final bool isComprehensive;
  final String? testType;

  const PractitionerProfileSelectionScreen({
    super.key,
    this.isComprehensive = false,
    this.testType,
  });

  @override
  State<PractitionerProfileSelectionScreen> createState() =>
      _PractitionerProfileSelectionScreenState();
}

class _PractitionerProfileSelectionScreenState
    extends State<PractitionerProfileSelectionScreen> {
  List<PatientModel> _patients = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Service
  final PatientService _patientService = PatientService();

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  String _selectedSex = 'Male';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  /// Load patients from Firebase
  Future<void> _loadPatients() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final patients = await _patientService.getPatients(user.uid);
      if (mounted) {
        setState(() {
          _patients = patients;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PractitionerProfile] Error loading patients: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _selectPatient(PatientModel patient) {
    // Check if patient has pre-test questions
    if (patient.hasPreTestQuestions) {
      // Load the questionnaire and show review popup
      _loadAndShowReview(patient);
    } else {
      _proceedWithPatient(patient, null);
    }
  }

  Future<void> _loadAndShowReview(PatientModel patient) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show a quick loader if needed, but usually we can just load and show
    try {
      final questionnaireService = PatientQuestionnaireService();
      final questionnaire = await questionnaireService.getPatientQuestionnaire(
        practitionerId: user.uid,
        patientId: patient.id,
      );

      if (mounted && questionnaire != null) {
        _showPretestReviewPopup(patient, questionnaire);
      } else if (mounted) {
        // Fallback if questionnaire somehow not found despite the flag
        _proceedWithPatient(patient, null);
      }
    } catch (e) {
      debugPrint('[PractitionerProfile] Error loading review: $e');
      if (mounted) _proceedWithPatient(patient, null);
    }
  }

  void _showPretestReviewPopup(
    PatientModel patient,
    QuestionnaireModel questionnaire,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final size = MediaQuery.of(context).size;
        final isLandscape = size.width > size.height;

        return Container(
          height: isLandscape ? size.height * 0.9 : size.height * 0.75,
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'PRE-TEST DATA FOUND',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            patient.fullName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildReviewSection(
                        'Primary Symptoms',
                        _buildChiefComplaintsReview(
                          questionnaire.chiefComplaints,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildReviewSection(
                        'Systemic Illnesses',
                        _buildSystemicIllnessReview(
                          questionnaire.systemicIllness,
                        ),
                      ),
                      if (questionnaire.currentMedications?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 24),
                        _buildReviewSection('Current Medications', [
                          questionnaire.currentMedications!,
                        ]),
                      ],
                      if (questionnaire.hasRecentSurgery) ...[
                        const SizedBox(height: 24),
                        _buildReviewSection('Recent Surgery History', [
                          questionnaire.surgeryDetails ?? 'Yes',
                        ]),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.fromLTRB(
                  24,
                  16,
                  24,
                  MediaQuery.of(context).padding.bottom + 16,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _proceedWithPatient(
                            patient,
                            null,
                            goToQuestionnaire: true,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.warning),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Modify',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _proceedWithPatient(patient, questionnaire);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text(
                          'Continue with Data',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.isEmpty
              ? [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.border.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'None reported',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ]
              : items
                    .map(
                      (item) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                    .toList(),
        ),
      ],
    );
  }

  List<String> _buildChiefComplaintsReview(ChiefComplaints cc) {
    final items = <String>[];
    if (cc.hasRedness) items.add('Redness');
    if (cc.hasWatering) items.add('Watering');
    if (cc.hasItching) items.add('Itching');
    if (cc.hasHeadache) items.add('Headache');
    if (cc.hasDryness) items.add('Dryness');
    if (cc.hasStickyDischarge) items.add('Sticky Discharge');
    if (cc.hasLightSensitivity) items.add('Light Sensitivity');
    if (cc.hasPreviousCataractOperation) items.add('Previous Cataract Op');
    if (cc.hasFamilyGlaucomaHistory) items.add('Family Glaucoma History');
    return items;
  }

  List<String> _buildSystemicIllnessReview(SystemicIllness si) {
    final items = <String>[];
    if (si.hasHypertension) items.add('Hypertension');
    if (si.hasDiabetes) items.add('Diabetes');
    if (si.hasCopd) items.add('COPD');
    if (si.hasAsthma) items.add('Asthma');
    if (si.hasMigraine) items.add('Migraine');
    if (si.hasSinus) items.add('Sinus');
    return items;
  }

  /// Proceed with test after patient selection logic
  void _proceedWithPatient(
    PatientModel patient,
    QuestionnaireModel? questionnaire, {
    bool goToQuestionnaire = false,
  }) {
    final provider = context.read<TestSessionProvider>();
    provider.selectPatientProfile(patient);

    // If we have a questionnaire, set it in the provider
    if (questionnaire != null) {
      provider.setQuestionnaire(questionnaire);
    }

    if (goToQuestionnaire) {
      // Force go to questionnaire
      Navigator.pushNamed(context, '/questionnaire');
      return;
    }

    if (widget.testType != null) {
      // Individual test flow
      provider.startIndividualTest(widget.testType!);

      // Determine standalone route
      String route;
      switch (widget.testType) {
        case 'visual_acuity':
          route = '/visual-acuity-standalone';
          break;
        case 'color_vision':
          route = '/color-vision-standalone';
          break;
        case 'amsler_grid':
          route = '/amsler-grid-standalone';
          break;
        case 'reading_test':
          route = '/reading-test-standalone';
          break;
        case 'contrast_sensitivity':
          route = '/contrast-sensitivity-standalone';
          break;
        case 'mobile_refractometry':
          route = '/mobile-refractometry-standalone';
          break;
        default:
          route = '/home'; // Safeguard
      }
      Navigator.pushReplacementNamed(context, route);
    } else if (widget.isComprehensive) {
      provider.startComprehensiveTest();
      // If questionnaire exists, skip to test instructions
      if (questionnaire != null) {
        Navigator.pushNamed(context, '/test-instructions');
      } else {
        Navigator.pushNamed(context, '/questionnaire');
      }
    } else {
      provider.startTest();
      // If questionnaire exists, skip to test instructions
      if (questionnaire != null) {
        Navigator.pushNamed(context, '/test-instructions');
      } else {
        Navigator.pushNamed(context, '/questionnaire');
      }
    }
  }

  Future<void> _addPatient({bool isEditing = false, String? patientId}) async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        SnackbarUtils.showError(context, 'Please log in to add patients');
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: EyeLoader.fullScreen()),
      );

      final patientData = PatientModel(
        id: isEditing && patientId != null
            ? (patientId.contains('_') ? patientId.split('_').last : patientId)
            : DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        age: int.parse(_ageController.text),
        sex: _selectedSex,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : '+91${_phoneController.text.trim()}',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      try {
        debugPrint(
          '[PractitionerProfile] ${isEditing ? 'Updating' : 'Saving'} patient: ${patientData.firstName}',
        );

        String finalId;
        if (isEditing && patientId != null) {
          finalId = await _patientService.savePatient(
            practitionerId: user.uid,
            patient: patientData,
            oldIdentity: patientId,
          );
        } else {
          finalId = await _patientService.savePatient(
            practitionerId: user.uid,
            patient: patientData,
          );
        }

        debugPrint(
          '[PractitionerProfile] ... Patient ${isEditing ? 'updated' : 'saved'} with ID: $finalId',
        );

        // Update local list with Firebase ID
        final savedPatient = patientData.copyWith(id: finalId);

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (!mounted) return;

        setState(() {
          if (isEditing) {
            final index = _patients.indexWhere((p) => p.id == patientId);
            if (index != -1) {
              // Remove old identity if it changed
              if (patientId != savedPatient.identityString) {
                _patients.removeAt(index);
                _patients.insert(
                  0,
                  savedPatient,
                ); // Wait, this should be savedPatient!
              } else {
                _patients[index] = savedPatient;
              }
            }
          } else {
            _patients.insert(0, savedPatient);
          }
          _clearForm();
        });

        // Close bottom sheet if open
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (!mounted) return;
        SnackbarUtils.showSuccess(
          context,
          '${savedPatient.fullName} ${isEditing ? 'updated' : 'added'} successfully',
        );
      } catch (e) {
        debugPrint('[PractitionerProfile] Error saving patient: $e');

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (!mounted) return;
        SnackbarUtils.showError(context, 'Failed to save: ${e.toString()}');
      }
    }
  }

  void _clearForm() {
    _firstNameController.clear();
    _lastNameController.clear();
    _ageController.clear();
    _phoneController.clear();
    _notesController.clear();
    _selectedSex = 'Male';
  }

  List<PatientModel> get _filteredPatients {
    if (_searchQuery.isEmpty) return _patients;

    final query = _searchQuery.toLowerCase();
    return _patients.where((patient) {
      return patient.firstName.toLowerCase().contains(query) ||
          (patient.lastName?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: AppColors.white,
        elevation: 0,
        toolbarHeight: 20,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_patients.isEmpty) {
            setState(() => _isLoading = true);
          }
          await _loadPatients();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            // Hero Section
            _buildAddPatientCard(),
            const SizedBox(height: 32),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Patient Profiles',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showAddPatientSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Add New',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search bar
            if (_patients.isNotEmpty) ...[
              PremiumSearchBar(
                hintText: 'Search patients...',
                initialValue: _searchQuery,
                onChanged: (value) => setState(() => _searchQuery = value),
                onClear: () => setState(() => _searchQuery = ''),
              ),
              const SizedBox(height: 28),
            ],

            // Patients list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(48),
                  child: EyeLoader.fullScreen(),
                ),
              )
            else if (_filteredPatients.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No patients added yet'
                          : 'No patients match "$_searchQuery"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a patient to start vision testing',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(
                _filteredPatients.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildPatientCard(_filteredPatients[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddPatientSheet({PatientModel? patient}) {
    if (patient != null) {
      _firstNameController.text = patient.firstName;
      _lastNameController.text = patient.lastName ?? '';
      _ageController.text = patient.age.toString();
      _phoneController.text = patient.phone?.replaceFirst('+91', '') ?? '';
      _notesController.text = patient.notes ?? '';
      _selectedSex = patient.sex;
    } else {
      _clearForm();
    }

    final isEditing = patient != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final size = MediaQuery.of(context).size;
          final isLandscape =
              MediaQuery.of(context).orientation == Orientation.landscape;
          final viewInsets = MediaQuery.of(context).viewInsets;
          final isKeyboardOpen = viewInsets.bottom > 0;

          return Container(
            height: isLandscape ? size.height * 0.95 : size.height * 0.85,
            decoration: const BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Fixed Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEditing
                              ? Icons.edit_rounded
                              : Icons.person_add_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? 'Edit Patient Profile'
                                  : 'Add New Patient',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              isEditing
                                  ? 'Update patient details'
                                  : 'Register a new patient profile',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      20,
                      24,
                      24 + viewInsets.bottom,
                    ),
                    child: _buildAddPatientForm(
                      setSheetState,
                      isLandscape,
                      isEditing: isEditing,
                      patientId: patient?.id,
                    ),
                  ),
                ),
                // Fixed Footer
                Container(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    16,
                    24,
                    (isKeyboardOpen
                        ? 16
                        : MediaQuery.of(context).padding.bottom + 24),
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.8),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _addPatient(
                          isEditing: isEditing,
                          patientId: patient?.id,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: AppColors.white,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isEditing
                              ? 'Update Patient Profile'
                              : 'Save Patient Profile',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddPatientCard() {
    return GestureDetector(
      onTap: () => _showAddPatientSheet(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.person_add_rounded,
                color: AppColors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Add New Patient',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Register a new profile for testing',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () => _selectPatient(patient),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -2,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      patient.firstName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),
                // Pre-test indicator badge
                if (patient.hasPreTestQuestions)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.assignment_turned_in,
                        size: 10,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${patient.age} years • ${patient.sex}${patient.phone != null ? ' • ${patient.phone?.replaceFirst('+91', '+91 ')}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        _showAddPatientSheet(patient: patient);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.error,
                      ),
                      onPressed: () {
                        _confirmDeletePatient(patient);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePatient(PatientModel patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Patient Profile'),
        content: Text(
          'Are you sure you want to remove ${patient.fullName}? Previous test results will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await _patientService.deletePatient(user.uid, patient.id);
        if (mounted) {
          setState(() {
            _patients.removeWhere((p) => p.id == patient.id);
          });
          SnackbarUtils.showSuccess(context, 'Patient profile removed');
        }
      } catch (e) {
        if (mounted) SnackbarUtils.showError(context, 'Failed to delete: $e');
      }
    }
  }

  Widget _buildAddPatientForm(
    StateSetter setSheetState,
    bool isLandscape, {
    bool isEditing = false,
    String? patientId,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    hintText: 'First name',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.error,
                        width: 1,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  scrollPadding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                  ),
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
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    hintText: 'Last name',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  scrollPadding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLandscape)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(3),
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        final n = int.tryParse(newValue.text);
                        if (n != null && n <= 200) return newValue;
                        return oldValue;
                      }),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Age',
                      hintText: 'Enter age',
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    scrollPadding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 120,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 1 || age > 200) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: PremiumDropdown<String>(
                    label: 'Sex',
                    value: _selectedSex,
                    items: const ['Male', 'Female', 'Other'],
                    itemLabelBuilder: (s) => s,
                    onChanged: (value) {
                      setSheetState(() => _selectedSex = value);
                    },
                  ),
                ),
              ],
            )
          else ...[
            // Age field
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
                TextInputFormatter.withFunction((oldValue, newValue) {
                  if (newValue.text.isEmpty) return newValue;
                  final n = int.tryParse(newValue.text);
                  if (n != null && n <= 200) return newValue;
                  return oldValue;
                }),
              ],
              decoration: InputDecoration(
                labelText: 'Age',
                hintText: 'Enter age',
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.border,
                    width: 1.5,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 2,
                  ),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.error,
                    width: 1,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              scrollPadding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 120,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Required';
                }
                final age = int.tryParse(value);
                if (age == null || age < 1 || age > 200) {
                  return 'Invalid';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Sex selector
            PremiumDropdown<String>(
              label: 'Sex',
              value: _selectedSex,
              items: const ['Male', 'Female', 'Other'],
              itemLabelBuilder: (s) => s,
              onChanged: (value) {
                setSheetState(() => _selectedSex = value);
              },
            ),
          ],
          const SizedBox(height: 16),
          // Phone
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '10-digit number',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.phone, size: 20),
              prefixText: '+91 ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.error, width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
            ),
            validator: (value) {
              if (value != null && value.isNotEmpty && value.length != 10) {
                return 'Enter exactly 10 digits';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          // Notes
          TextFormField(
            controller: _notesController,
            maxLines: 3,
            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 120,
            ),
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'Any additional notes...',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.note, size: 20),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.border,
                  width: 1.5,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
