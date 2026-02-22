import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/eye_loader.dart';

class DoctorProfileScreen extends StatefulWidget {
  const DoctorProfileScreen({super.key});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  final _authService = AuthService();
  final _consultationService = ConsultationService();
  UserModel? _user;
  DoctorModel? _doctor;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  late TextEditingController _bioController;
  late TextEditingController _expController;
  late TextEditingController _specialtyController;
  late TextEditingController _degreeController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController();
    _expController = TextEditingController();
    _specialtyController = TextEditingController();
    _degreeController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _expController.dispose();
    _specialtyController.dispose();
    _degreeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = await _authService.getCurrentUserProfile();
    if (user != null) {
      final doctor = await _consultationService.getDoctorById(user.id);
      if (mounted) {
        setState(() {
          _user = user;
          _doctor = doctor;
          if (doctor != null) {
            _bioController.text = doctor.bio;
            _expController.text = doctor.experienceYears.toString();
            _specialtyController.text = doctor.specialty;
            _degreeController.text = doctor.degree;
          }
          _phoneController.text = user.phone;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_user == null || _doctor == null) return;

    setState(() => _isSaving = true);

    try {
      final experienceYears =
          int.tryParse(_expController.text) ?? _doctor!.experienceYears;

      // Update Professional Profile (DoctorModel)
      final updatedDoctor = _doctor!.copyWith(
        bio: _bioController.text.trim(),
        experienceYears: experienceYears,
        specialty: _specialtyController.text.trim(),
        degree: _degreeController.text.trim(),
      );

      final success = await _consultationService.updateDoctorProfile(
        updatedDoctor,
      );

      if (success) {
        // Update Basic Profile (UserModel - Phone) if changed
        if (_user!.phone != _phoneController.text.trim()) {
          final updatedUser = _user!.copyWith(
            phone: _phoneController.text.trim(),
          );
          await _authService.updateUserProfile(updatedUser);
          _user = updatedUser;
        }

        if (mounted) {
          setState(() {
            _doctor = updatedDoctor;
            _isEditing = false;
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated successfully!')),
          );
        }
      } else {
        throw Exception('Failed to update doctor profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: EyeLoader(size: 40))
          : _user == null
          ? const Center(child: Text('User not found'))
          : Stack(
              children: [
                // Background Decorations
                Positioned(
                  top: -100,
                  left: -100,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          context.primary.withValues(alpha: 0.08),
                          context.primary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -50,
                  right: -50,
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.secondary.withValues(alpha: 0.05),
                          AppColors.secondary.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      pinned: true,
                      centerTitle: false,
                      title: Text(
                        'My Profile',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      actions: [
                        if (_user != null)
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: IconButton(
                              onPressed: _isSaving
                                  ? null
                                  : () {
                                      if (_isEditing) {
                                        _saveProfile();
                                      } else {
                                        setState(() => _isEditing = true);
                                      }
                                    },
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      _isEditing
                                          ? Icons.check_circle_rounded
                                          : Icons.edit_note_rounded,
                                      color: _isEditing
                                          ? Colors.green
                                          : context.primary,
                                    ),
                            ),
                          ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 32),
                            _buildBioSection(),
                            const SizedBox(height: 40),
                            _buildSectionHeader('Professional Information'),
                            _buildInfoSection(),
                            const SizedBox(height: 48),
                            _buildLogoutButton(),
                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
              color: context.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: context.dividerColor.withValues(alpha: 0.05)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: context.primary.withValues(alpha: 0.1),
                  width: 6,
                ),
              ),
            ),
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary.withValues(alpha: 0.1),
                image: _user?.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(_user!.photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _user?.photoUrl == null
                  ? Center(
                      child: Text(
                        (_user!.firstName.isNotEmpty
                                ? _user!.firstName[0]
                                : '') +
                            (_user!.lastName.isNotEmpty
                                ? _user!.lastName[0]
                                : ''),
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w900,
                          color: context.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            Positioned(
              right: 4,
              bottom: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: context.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 20),
        if (_isEditing)
          Column(
            children: [
              _buildFullWidthTextField(
                _specialtyController,
                'Specialty',
                hint: 'e.g. Ophthalmology',
              ),
              const SizedBox(height: 12),
              _buildFullWidthTextField(
                _degreeController,
                'Degree',
                hint: 'e.g. MBBS, MS',
              ),
            ],
          )
        else
          Column(
            children: [
              Text(
                'Dr. ${_user!.fullName}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _doctor?.specialty.isNotEmpty == true
                      ? _doctor!.specialty.toUpperCase()
                      : 'CERTIFIED DOCTOR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: context.primary,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (_doctor?.degree.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _doctor!.degree,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: context.dividerColor.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildEditableTile(
            'Years of Experience',
            _expController,
            Icons.work_history_rounded,
            isEditable: _isEditing,
            keyboardType: TextInputType.number,
          ),
          _buildDivider(),
          _buildEditableTile(
            'Phone Number',
            _phoneController,
            Icons.phone_android_rounded,
            isEditable: _isEditing,
            keyboardType: TextInputType.phone,
          ),
          _buildDivider(),
          _buildInfoTile(
            'Email Address',
            _user!.email,
            Icons.alternate_email_rounded,
          ),
          _buildDivider(),
          _buildInfoTile(
            'Registration Number',
            _doctor?.registrationNumber ?? 'Not set',
            Icons.badge_rounded,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 200.ms).slideY(begin: 0.05);
  }

  Widget _buildBioSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Professional Bio'),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: context.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: context.dividerColor.withValues(alpha: 0.05),
            ),
          ),
          child: _isEditing
              ? TextField(
                  controller: _bioController,
                  maxLines: 5,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your expertise and background...',
                    hintStyle: TextStyle(
                      color: context.textSecondary.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  _doctor?.bio.isNotEmpty == true
                      ? _doctor!.bio
                      : 'No bio added yet. Tell patients about your expertise!',
                  style: TextStyle(
                    fontSize: 15,
                    color: _doctor?.bio.isNotEmpty == true
                        ? context.onSurface
                        : context.textSecondary.withValues(alpha: 0.5),
                    height: 1.5,
                  ),
                ),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms, delay: 100.ms);
  }

  Widget _buildEditableTile(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isEditable = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                if (isEditable)
                  TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  )
                else
                  Text(
                    controller.text,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
              ],
            ),
          ),
          if (isEditable)
            Icon(
              Icons.edit_rounded,
              size: 14,
              color: context.primary.withValues(alpha: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildFullWidthTextField(
    TextEditingController controller,
    String label, {
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: context.primary,
            ),
          ),
          TextField(
            controller: controller,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.dividerColor.withValues(alpha: 0.2),
            size: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 68,
      endIndent: 20,
      color: context.dividerColor.withValues(alpha: 0.05),
    );
  }

  Widget _buildLogoutButton() {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _authService.signOut().then(
          (_) => Navigator.pushReplacementNamed(context, '/login'),
        ),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Text(
                'LOGOUT FROM SESSION',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 400.ms);
  }
}
