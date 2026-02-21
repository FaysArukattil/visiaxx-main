import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../data/models/user_model.dart';
import '../../../core/widgets/verification_dialog.dart';

/// Registration screen with Firebase authentication
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _practitionerCodeController = TextEditingController();
  final _doctorSpecialtyController = TextEditingController();
  final _doctorDegreeController = TextEditingController();
  final _doctorBioController = TextEditingController();
  final _doctorExperienceController = TextEditingController();
  final _authService = AuthService();

  String _selectedSex = 'Male';
  UserRole _selectedRole = UserRole.user;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('[RegistrationScreen] Error picking image: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to pick image: $e';
        });
      }
    }
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.dividerColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Professional Photo',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a source for your profile picture',
                style: TextStyle(color: context.textSecondary),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildImageSourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _buildImageSourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSourceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  context.primary.withValues(alpha: 0.1),
                  context.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: context.primary.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: context.primary, size: 32),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: TextStyle(
              color: context.primary,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _practitionerCodeController.dispose();
    _doctorSpecialtyController.dispose();
    _doctorDegreeController.dispose();
    _doctorBioController.dispose();
    _doctorExperienceController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedRole == UserRole.doctor && _profileImage == null) {
      setState(() => _errorMessage = 'Profile photo is required for doctors.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    Map<String, dynamic>? doctorData;
    if (_selectedRole == UserRole.doctor) {
      doctorData = {
        'specialty': _doctorSpecialtyController.text.trim(),
        'degree': _doctorDegreeController.text.trim(),
        'bio': _doctorBioController.text.trim(),
        'experienceYears': int.tryParse(_doctorExperienceController.text) ?? 0,
        'rating': 0.0,
        'reviewCount': 0,
        'availableServices': ['Online', 'In-Person'],
      };
    }

    try {
      final result = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        age: int.tryParse(_ageController.text) ?? 0,
        sex: _selectedSex,
        phone: '+91${_phoneController.text.trim()}',
        role: _selectedRole,
        practitionerCode:
            (_selectedRole == UserRole.examiner ||
                _selectedRole == UserRole.doctor)
            ? _practitionerCodeController.text.trim()
            : null,
        doctorData: doctorData,
        profileImage: _profileImage,
      );

      if (result.isSuccess) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showSuccessDialog();
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                result.message?.contains('network-request-failed') == true
                ? 'No internet connection. Please check your network and try again.'
                : result.message;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An unexpected error occurred. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VerificationDialog(
        isSuccess: true,
        title: 'Registration Successful!',
        message:
            'A verification email has been sent to your email address. Please verify your account before signing in.',
        confirmLabel: 'Go to Sign In',
        onConfirm: () {
          Navigator.of(context).pop();
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20, top: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: context.primary),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
              color: context.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.primary.withValues(alpha: 0.2),
                    context.primary.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Layering
          Positioned(
            top: -100,
            right: -100,
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
          ).animate().fadeIn(duration: 800.ms),
          Positioned(
            bottom: -50,
            left: -100,
            child: Container(
              width: 350,
              height: 350,
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
          ).animate().fadeIn(duration: 800.ms, delay: 300.ms),

          SafeArea(
            child: OrientationBuilder(
              builder: (context, orientation) {
                final isLandscape = orientation == Orientation.landscape;

                if (isLandscape) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Side: Premium Context
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                40,
                                60,
                                40,
                                40,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildBackButton(),
                                  const SizedBox(height: 48),
                                  Text(
                                    'Create New\nAccount',
                                    style: theme.textTheme.displayMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: context.primary,
                                          fontSize: 38,
                                          letterSpacing: -1.5,
                                          height: 1.1,
                                        ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Begin your journey with premium digital eye care diagnostic tools.',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: context.textSecondary,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 60),
                                  _buildSignInLink(),
                                ],
                              ),
                            ),
                          ),
                          // Right Side: High-Fidelity Form
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                40,
                                40,
                              ),
                              child: Form(
                                key: _formKey,
                                child: _buildRegistrationForm(
                                  isLandscape: true,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideX(begin: 0.05),
                  );
                }

                // Portrait layout
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildBackButton(),
                            const SizedBox(height: 32),
                            Text(
                              'Create Account',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.primary,
                                fontSize: 30,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Join our premium eye diagnostic ecosystem',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: context.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildRegistrationForm(isLandscape: false),
                            const SizedBox(height: 32),
                            _buildSignInLink(),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.05),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: context.primary.withValues(alpha: 0.1)),
        ),
        child: Icon(Icons.arrow_back_rounded, color: context.primary, size: 20),
      ),
    );
  }

  Widget _buildSignInLink() {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(color: context.textSecondary),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Text(
              'Sign In',
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm({required bool isLandscape}) {
    return Container(
      padding: EdgeInsets.all(isLandscape ? 32 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.02),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: context.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.05),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          _buildSectionTitle('You are a', Icons.badge_rounded),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _RoleCard(
                  title: 'User',
                  icon: Icons.person_outline_rounded,
                  isSelected: _selectedRole == UserRole.user,
                  onTap: () => setState(() => _selectedRole = UserRole.user),
                ),
                const SizedBox(width: 12),
                _RoleCard(
                  title: 'Practitioner',
                  icon: Icons.medical_services_outlined,
                  isSelected: _selectedRole == UserRole.examiner,
                  onTap: () =>
                      setState(() => _selectedRole = UserRole.examiner),
                ),
                const SizedBox(width: 12),
                _RoleCard(
                  title: 'Doctor',
                  icon: Icons.health_and_safety_outlined,
                  isSelected: _selectedRole == UserRole.doctor,
                  onTap: () => setState(() => _selectedRole = UserRole.doctor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedRole == UserRole.doctor) ...[
            const SizedBox(height: 12),
            Center(
              child:
                  Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: context.primary.withValues(alpha: 0.2),
                                width: 4,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: _showImageSourceActionSheet,
                            child: Container(
                              width: 95,
                              height: 95,
                              decoration: BoxDecoration(
                                color: context.primary.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                image: _profileImage != null
                                    ? DecorationImage(
                                        image: FileImage(_profileImage!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.add_a_photo_rounded,
                                      color: context.primary,
                                      size: 28,
                                    )
                                  : null,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: context.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.surface,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _profileImage == null
                                    ? Icons.add_rounded
                                    : Icons.edit_rounded,
                                color: AppColors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      )
                      .animate(target: _profileImage != null ? 1 : 0)
                      .shimmer(duration: 1.seconds),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'PROFESSIONAL PHOTO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: context.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionTitle('Personal Info', Icons.person_rounded),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: 'First Name'),
                  validator: (value) =>
                      (value == null || value.isEmpty) ? 'Required' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _lastNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: const InputDecoration(labelText: 'Age'),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Age?';
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 200) return '!';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: PremiumDropdown<String>(
                  label: 'Sex',
                  value: _selectedSex,
                  items: const ['Male', 'Female', 'Other'],
                  itemLabelBuilder: (s) => s,
                  onChanged: (value) => setState(() => _selectedSex = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          _buildSectionTitle('Contact Info', Icons.alternate_email_rounded),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Email Address'),
            validator: (value) {
              if (value == null || value.isEmpty) return 'Required';
              if (!value.contains('@')) return 'Invalid Email';
              return null;
            },
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontWeight: FontWeight.w600),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+91 ',
              prefixStyle: TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
              ),
            ),
            validator: (value) => (value?.length != 10) ? '10 digits' : null,
          ),
          const SizedBox(height: 24),

          if (_selectedRole == UserRole.doctor) ...[
            _buildSectionTitle(
              'Professional Profile',
              Icons.medical_information_rounded,
            ),
            TextFormField(
              controller: _doctorSpecialtyController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Specialty',
                hintText: 'e.g. Ophthalmologist',
              ),
              validator: (value) =>
                  (_selectedRole == UserRole.doctor &&
                      (value == null || value.isEmpty))
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _doctorDegreeController,
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Degree',
                      hintText: 'MS, MD',
                    ),
                    validator: (value) =>
                        (_selectedRole == UserRole.doctor &&
                            (value == null || value.isEmpty))
                        ? 'Required'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _doctorExperienceController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Experience',
                      suffixText: 'yrs',
                    ),
                    validator: (value) =>
                        (_selectedRole == UserRole.doctor &&
                            (value == null || value.isEmpty))
                        ? 'Required'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _doctorBioController,
              maxLines: 2,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Personal Bio',
                hintText: 'Tell us about your expertise...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
          ],

          if (_selectedRole == UserRole.examiner ||
              _selectedRole == UserRole.doctor) ...[
            _buildSectionTitle('Verification', Icons.security_rounded),
            TextFormField(
              controller: _practitionerCodeController,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Access Code',
                hintText: 'Enter registration code',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
              validator: (value) =>
                  ((_selectedRole == UserRole.examiner ||
                          _selectedRole == UserRole.doctor) &&
                      (value == null || value.isEmpty))
                  ? 'Required'
                  : null,
            ),
            const SizedBox(height: 24),
          ],

          _buildSectionTitle('Security', Icons.lock_outline_rounded),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) =>
                (value?.length ?? 0) < 6 ? 'Min 6 chars' : null,
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRegister(),
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: const InputDecoration(labelText: 'Confirm Password'),
            validator: (value) =>
                (value != _passwordController.text) ? 'Mismatch' : null,
          ),
          const SizedBox(height: 48),

          Container(
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary,
                  context.primary.withValues(alpha: 0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.transparent,
                shadowColor: AppColors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: _isLoading
                  ? const EyeLoader(size: 32, color: AppColors.white)
                  : const Text(
                      'CREATE ACCOUNT',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'By creating an account, you agree to our Terms of Service\nand Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: AppColors.textTertiary,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        width: 140,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primary.withValues(alpha: 0.08)
              : context.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? context.primary
                : context.dividerColor.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? context.primary
                    : context.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected ? AppColors.white : context.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                color: isSelected ? context.primary : context.textSecondary,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
