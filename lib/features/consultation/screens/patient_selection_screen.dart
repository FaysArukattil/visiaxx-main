import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/consultation_booking_model.dart';
import '../../../data/models/family_member_model.dart';
import '../../../data/providers/family_member_provider.dart';
import '../../../core/widgets/eye_loader.dart';

class PatientSelectionScreen extends StatefulWidget {
  const PatientSelectionScreen({super.key});

  @override
  State<PatientSelectionScreen> createState() => _PatientSelectionScreenState();
}

class _PatientSelectionScreenState extends State<PatientSelectionScreen> {
  final _authService = AuthService();
  bool _isForSelf = true;
  FamilyMemberModel? _selectedFamilyMember;

  // Storage for 'Myself' details
  String? _myFullname;
  int? _myAge;
  String? _myGender;

  bool _isLoading = true;

  DoctorModel? _doctor;
  ConsultationType? _type;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  String? _flat;
  String? _landmark;
  String? _pincode;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _type = args?['type'];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];
    _flat = args?['flat'];
    _landmark = args?['landmark'];
    _pincode = args?['pincode'];
  }

  Future<void> _loadInitialData() async {
    final user = await _authService.getCurrentUserProfile();
    if (user != null) {
      if (mounted) {
        setState(() {
          _myFullname = user.fullName;
          _myAge = user.age;
          _myGender = user.sex;
        });

        // Fetch family members
        await Provider.of<FamilyMemberProvider>(
          context,
          listen: false,
        ).loadFamilyMembers(user.id);

        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onContinue() {
    if (!_isForSelf && _selectedFamilyMember == null) {
      SnackbarUtils.showWarning(context, 'Please select a family member');
      return;
    }

    final String name = _isForSelf
        ? (_myFullname ?? '')
        : _selectedFamilyMember!.firstName;
    final int? age = _isForSelf ? _myAge : _selectedFamilyMember!.age;
    final String gender = _isForSelf
        ? (_myGender ?? 'Male')
        : _selectedFamilyMember!.sex;

    Navigator.pushNamed(
      context,
      '/slot-selection',
      arguments: {
        'doctor': _doctor,
        'type': _type,
        'latitude': _latitude,
        'longitude': _longitude,
        'exactAddress': _exactAddress,
        'flat': _flat,
        'landmark': _landmark,
        'pincode': _pincode,
        'patientName': name,
        'patientAge': age,
        'patientGender': gender,
        'isForSelf': _isForSelf,
        'familyMemberId': _isForSelf ? null : _selectedFamilyMember!.id,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: EyeLoader(size: 60)));
    }

    return Scaffold(
      body: Stack(
        children: [
          // Background Decor
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildHeader(context),
                  const SizedBox(height: 40),
                  _buildSectionTitle('Who is this Consultation for?'),
                  const SizedBox(height: 24),
                  _buildSelectionCards(context),
                  const SizedBox(height: 32),
                  if (!_isForSelf) ...[
                    _buildSectionTitle('Select Family Member'),
                    const SizedBox(height: 16),
                    _buildFamilyMemberList(context),
                  ] else ...[
                    _buildSectionTitle('Confirm Your Details'),
                    const SizedBox(height: 16),
                    _buildSelfDetails(context),
                  ],
                  const SizedBox(height: 40),
                  _buildContinueButton(context),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 20),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Patient Details',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: context.onSurface,
            letterSpacing: -1,
          ),
        ).animate().fadeIn().slideX(begin: -0.2),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: context.onSurface,
        letterSpacing: -0.5,
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildSelectionCards(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeCard(context, 'Myself', Icons.person_rounded, true),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildTypeCard(
            context,
            'Family Member',
            Icons.family_restroom_rounded,
            false,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1);
  }

  Widget _buildTypeCard(
    BuildContext context,
    String title,
    IconData icon,
    bool self,
  ) {
    final isSelected = _isForSelf == self;
    final color = isSelected ? context.primary : context.surface;

    return InkWell(
      onTap: () => setState(() => _isForSelf = self),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? context.primary
                : context.dividerColor.withValues(alpha: 0.1),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected ? Colors.white : context.primary,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelfDetails(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person, color: context.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _myFullname ?? 'User',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '${_myAge ?? '--'} years • ${_myGender ?? '--'}',
                  style: TextStyle(color: context.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildFamilyMemberList(BuildContext context) {
    return Consumer<FamilyMemberProvider>(
      builder: (context, provider, child) {
        if (provider.familyMembers.isEmpty) {
          return Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: context.textTertiary,
                ),
                const SizedBox(height: 16),
                Text(
                  'No family members found',
                  style: TextStyle(color: context.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please add them from your profile first.',
                  style: TextStyle(color: context.textTertiary, fontSize: 12),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: provider.familyMembers.length,
          itemBuilder: (context, index) {
            final member = provider.familyMembers[index];
            final isSelected = _selectedFamilyMember?.id == member.id;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _selectedFamilyMember = member),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.primary.withValues(alpha: 0.05)
                        : context.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? context.primary
                          : context.dividerColor.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: isSelected
                            ? context.primary
                            : context.primary.withValues(alpha: 0.1),
                        child: Icon(
                          Icons.person_outline,
                          color: isSelected ? Colors.white : context.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.firstName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isSelected
                                    ? context.primary
                                    : context.onSurface,
                              ),
                            ),
                            Text(
                              '${member.age} years • ${member.sex} • ${member.relationship}',
                              style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: context.primary),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _onContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 8,
          shadowColor: context.primary.withValues(alpha: 0.3),
        ),
        child: const Text(
          'Continue to Slot Selection',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2);
  }
}
