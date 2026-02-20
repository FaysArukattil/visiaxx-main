import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/user_model.dart';
import '../../home/widgets/app_bar_widget.dart';
import 'patient_results_view_screen.dart'; // We can use this or create a full medical history view

class DoctorPatientsScreen extends StatefulWidget {
  const DoctorPatientsScreen({super.key});

  @override
  State<DoctorPatientsScreen> createState() => _DoctorPatientsScreenState();
}

class _DoctorPatientsScreenState extends State<DoctorPatientsScreen> {
  final _consultationService = ConsultationService();
  final _authService = AuthService();
  List<UserModel> _patients = [];
  List<UserModel> _filteredPatients = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    final uid = _authService.currentUserId;
    if (uid != null) {
      final patients = await _consultationService.getDoctorPatients(uid);
      setState(() {
        _patients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    }
  }

  void _filterPatients(String query) {
    setState(() {
      _filteredPatients = _patients
          .where(
            (p) =>
                p.fullName.toLowerCase().contains(query.toLowerCase()) ||
                p.email.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'My Patients'),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                ? _buildEmptyState()
                : _buildPatientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: TextField(
        controller: _searchController,
        onChanged: _filterPatients,
        decoration: InputDecoration(
          hintText: 'Search patients by name or email...',
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: Theme.of(context).cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: context.primary),
          ),
        ),
      ),
    );
  }

  Widget _buildPatientsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      itemCount: _filteredPatients.length,
      itemBuilder: (context, index) {
        final patient = _filteredPatients[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: context.dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: context.primary.withValues(alpha: 0.1),
              child: Text(
                patient.firstName[0] + patient.lastName[0],
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              patient.fullName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '${patient.age} years • ${patient.sex.toUpperCase()}',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // For now, navigate to a view that shows their results
              // Since we don't have a "fetch all results for patient" by UID easily in PatientResultsViewScreen
              // (it takes a list of IDs), we might need to adjust or create a new screen.
              // But we can fetch all bookings for this patient and doctor to get the result IDs.
              _navigateToPatientHistory(patient);
            },
          ),
        );
      },
    );
  }

  Future<void> _navigateToPatientHistory(UserModel patient) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final uid = _authService.currentUserId;
    if (uid != null) {
      final bookings = await _consultationService.getDoctorBookings(uid);
      final patientBookings = bookings
          .where((b) => b.patientId == patient.id)
          .toList();

      final resultIds = patientBookings
          .expand((b) => b.attachedResultIds)
          .toSet()
          .toList();

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PatientResultsViewScreen(
              resultIds: resultIds,
              patientName: patient.fullName,
            ),
          ),
        );
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: context.primary.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          const Text('No patients yet'),
          const SizedBox(height: 8),
          Text(
            'Patients you consult with will appear here.',
            style: TextStyle(color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}
