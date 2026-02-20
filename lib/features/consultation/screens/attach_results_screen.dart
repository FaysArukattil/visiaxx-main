import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
// Redundant import removed
import '../../../core/services/test_result_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../../data/models/test_result_model.dart';
import '../../home/widgets/app_bar_widget.dart';

class AttachResultsScreen extends StatefulWidget {
  const AttachResultsScreen({super.key});

  @override
  State<AttachResultsScreen> createState() => _AttachResultsScreenState();
}

class _AttachResultsScreenState extends State<AttachResultsScreen> {
  final _testResultService = TestResultService();
  final _authService = AuthService();

  DoctorModel? _doctor;
  DateTime? _date;
  TimeSlotModel? _slot;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;

  List<TestResultModel> _results = [];
  final List<String> _selectedResultIds = [];
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _date = args?['date'];
    _slot = args?['slot'];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];

    if (_doctor != null) {
      _loadResults();
    }
  }

  Future<void> _loadResults() async {
    setState(() => _isLoading = true);
    final user = _authService.currentUser;
    if (user != null) {
      // Assuming TestResultService has a way to get results by user UID
      // Based on my knowledge of the codebase, it likely uses UID in Firestore
      final results = await _testResultService.getTestResults(user.uid);
      setState(() {
        _results = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Attach Results'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Select any previous test results you want to share with Dr. ${_doctor?.fullName ?? ''}',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _results.isEmpty
                ? _buildEmptyState()
                : _buildResultsList(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final result = _results[index];
        final isSelected = _selectedResultIds.contains(result.id);

        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: isSelected
                  ? context.primary
                  : Theme.of(context).dividerColor.withValues(alpha: 0.1),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: CheckboxListTile(
            value: isSelected,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedResultIds.add(result.id);
                } else {
                  _selectedResultIds.remove(result.id);
                }
              });
            },
            title: Text(
              result.testType.toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Date: ${DateFormat('dd MMM yyyy').format(result.timestamp)}',
              style: const TextStyle(fontSize: 12),
            ),
            secondary: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.description_outlined, color: context.primary),
            ),
            activeColor: context.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text('No previous test results found.'),
          const SizedBox(height: 8),
          const Text(
            'You can still proceed with your booking.',
            style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _navigateToConfirmation(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => _navigateToConfirmation(),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.primary,
                minimumSize: const Size(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                _selectedResultIds.isEmpty ? 'Proceed' : 'Attach & Proceed',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToConfirmation() {
    Navigator.pushNamed(
      context,
      '/booking-confirmation',
      arguments: {
        'doctor': _doctor,
        'date': _date,
        'slot': _slot,
        'attachedResultIds': _selectedResultIds,
        'latitude': _latitude,
        'longitude': _longitude,
        'exactAddress': _exactAddress,
      },
    );
  }
}
