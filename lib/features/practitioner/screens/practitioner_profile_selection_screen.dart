import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/services/patient_service.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/providers/test_session_provider.dart';

/// Profile selection screen for practitioners
/// Shows "Add Patient" instead of "Test for Yourself"
/// No relationship field for patients
class PractitionerProfileSelectionScreen extends StatefulWidget {
  final bool isComprehensive;

  const PractitionerProfileSelectionScreen({
    super.key,
    this.isComprehensive = false,
  });

  @override
  State<PractitionerProfileSelectionScreen> createState() =>
      _PractitionerProfileSelectionScreenState();
}

class _PractitionerProfileSelectionScreenState
    extends State<PractitionerProfileSelectionScreen> {
  List<PatientModel> _patients = [];
  bool _showAddForm = false;
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
    final provider = context.read<TestSessionProvider>();
    // Use patient as a family member equivalent for test session
    provider.selectPatientProfile(patient);

    if (widget.isComprehensive) {
      provider.startComprehensiveTest();
    } else {
      provider.startTest();
    }

    Navigator.pushNamed(context, '/questionnaire');
  }

  Future<void> _addPatient() async {
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

      final newPatient = PatientModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim().isEmpty
            ? null
            : _lastNameController.text.trim(),
        age: int.parse(_ageController.text),
        sex: _selectedSex,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        createdAt: DateTime.now(),
      );

      try {
        debugPrint(
          '[PractitionerProfile] Saving patient: ${newPatient.firstName}',
        );

        // Save to Firebase
        final savedId = await _patientService.savePatient(
          practitionerId: user.uid,
          patient: newPatient,
        );

        debugPrint('[PractitionerProfile] … Patient saved with ID: $savedId');

        // Update local list with Firebase ID
        final savedPatient = newPatient.copyWith(id: savedId);

        // Close loading dialog
        if (mounted) Navigator.pop(context);

        if (!mounted) return;

        setState(() {
          _patients.insert(0, savedPatient);
          _showAddForm = false;
          _clearForm();
        });

        if (!mounted) return;
        SnackbarUtils.showSuccess(
          context,
          '… ${savedPatient.fullName} added successfully',
        );
      } catch (e) {
        debugPrint('[PractitionerProfile] Œ Error saving patient: $e');

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
      appBar: AppBar(
        title: const Text('Select Patient'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadPatients();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Add new patient card
            _buildAddPatientCard(),
            const SizedBox(height: 24),

            // Search bar
            if (_patients.isNotEmpty) ...[
              TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Search patients...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Patients section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Patients',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAddForm = !_showAddForm;
                    });
                  },
                  icon: Icon(_showAddForm ? Icons.close : Icons.add),
                  label: Text(_showAddForm ? 'Cancel' : 'New Patient'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Add patient form
            if (_showAddForm) ...[
              _buildAddPatientForm(),
              const SizedBox(height: 16),
            ],

            // Patients list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: EyeLoader.fullScreen(),
                ),
              )
            else if (_filteredPatients.isEmpty && !_showAddForm)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isEmpty
                          ? 'No patients added yet'
                          : 'No patients match "$_searchQuery"',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a patient to start vision testing',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
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

  Widget _buildAddPatientCard() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAddForm = true;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.person_add,
                color: AppColors.white,
                size: 36,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Register a new patient for vision testing',
                    style: TextStyle(
                      color: AppColors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard(PatientModel patient) {
    return GestureDetector(
      onTap: () => _selectPatient(patient),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
              radius: 28,
              child: Text(
                patient.firstName[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${patient.age} years €¢ ${patient.sex}${patient.phone != null ? ' €¢ ${patient.phone}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddPatientForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add New Patient',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Name row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      hintText: 'First name',
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
                    decoration: const InputDecoration(
                      labelText: 'Last Name',
                      hintText: 'Last name',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Age and Sex row
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Age *',
                      hintText: 'Age',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      final age = int.tryParse(value);
                      if (age == null || age < 1 || age > 120) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSex,
                    decoration: const InputDecoration(labelText: 'Sex *'),
                    items: const [
                      DropdownMenuItem(value: 'Male', child: Text('Male')),
                      DropdownMenuItem(value: 'Female', child: Text('Female')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedSex = value!);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone (optional)',
                hintText: 'Contact number',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any additional notes...',
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addPatient,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Save Patient'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


