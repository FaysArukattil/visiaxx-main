import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Select Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.primary.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: context.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: context.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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

    debugPrint(
      '[RegistrationScreen] 🚀 Attempting registration for role: $_selectedRole',
    );
    if (_selectedRole == UserRole.examiner) {
      debugPrint(
        '[RegistrationScreen] 🔑 Access code entered: "${_practitionerCodeController.text}"',
      );
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
          Navigator.of(context).pop(); // Close dialog
          Navigator.of(context).pop(); // Go back to login screen
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: theme.textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(child: Divider(thickness: 0.5)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: AppColors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Background Decoration
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 200,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withValues(alpha: 0.04),
              ),
            ),
          ),
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
                          // Left Side: Header Text
                          Expanded(
                            flex: 4,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                40,
                                24,
                                32,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Join Visiaxx',
                                    style: theme.textTheme.displaySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: context.primary,
                                          fontSize: 32,
                                        ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Experience premium digital eye diagnostics',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                  // Already have account
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        'Already have an account? ',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Right Side: Form
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(
                                12,
                                12,
                                24,
                                32,
                              ),
                              child: Form(
                                key: _formKey,
                                child: _buildRegistrationForm(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Portrait layout
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 550),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header text
                            Text(
                              'Join Visiaxx',
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: context.primary,
                                fontSize: 28,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Experience premium digital eye diagnostics',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 32),

                            _buildRegistrationForm(),

                            const SizedBox(height: 24),

                            // Already have account
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Already have an account? ',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationForm() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.black.withValues(alpha: 0.04)
                : AppColors.transparent,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error message
          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // --- Profile Photo Section (Mandatory for Doctors) ---
          if (_selectedRole == UserRole.doctor) ...[
            _buildSectionTitle('Profile Photo', Icons.camera_alt_outlined),
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: _showImageSourceActionSheet,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _profileImage == null && _errorMessage != null
                              ? AppColors.error
                              : context.primary,
                          width: 2,
                        ),
                        image: _profileImage != null
                            ? DecorationImage(
                                image: FileImage(_profileImage!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profileImage == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  color: context.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Select',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),
                  if (_profileImage != null)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _profileImage = null),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // --- Personal Info Section ---
          _buildSectionTitle('Personal Info', Icons.person_rounded),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _firstNameController,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
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
                  decoration: const InputDecoration(labelText: 'Last Name'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
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
                  decoration: const InputDecoration(labelText: 'Age'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Age?';
                    }
                    final age = int.tryParse(value);
                    if (age == null || age < 1 || age > 200) {
                      return '!';
                    }
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
                  onChanged: (value) {
                    setState(() => _selectedSex = value);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // --- Contact Info Section ---
          _buildSectionTitle('Contact Info', Icons.alternate_email_rounded),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Email Address'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Required';
              }
              if (!value.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+91 ',
              prefixStyle: TextStyle(fontWeight: FontWeight.bold),
            ),
            validator: (value) =>
                (value?.length != 10) ? '10 digits required' : null,
          ),
          const SizedBox(height: 24),

          // --- Role Section ---
          _buildSectionTitle('You are a', Icons.badge_rounded),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: _RoleCard(
                    title: 'User',
                    icon: Icons.person_outline_rounded,
                    isSelected: _selectedRole == UserRole.user,
                    onTap: () => setState(() => _selectedRole = UserRole.user),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: _RoleCard(
                    title: 'Practitioner',
                    icon: Icons.medical_services_outlined,
                    isSelected: _selectedRole == UserRole.examiner,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.examiner),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: _RoleCard(
                    title: 'Doctor',
                    icon: Icons.health_and_safety_outlined,
                    isSelected: _selectedRole == UserRole.doctor,
                    onTap: () =>
                        setState(() => _selectedRole = UserRole.doctor),
                  ),
                ),
              ],
            ),
          ),

          if (_selectedRole == UserRole.doctor) ...[
            const SizedBox(height: 24),
            _buildSectionTitle(
              'Doctor Profile',
              Icons.medical_information_outlined,
            ),
            TextFormField(
              controller: _doctorSpecialtyController,
              textCapitalization: TextCapitalization.words,
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
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _doctorDegreeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Degree',
                      hintText: 'e.g. MS, MD',
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
                    decoration: const InputDecoration(
                      labelText: 'Experience',
                      suffixText: 'years',
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _doctorBioController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Short Bio',
                hintText: 'Tell patients about your expertise...',
                alignLabelWithHint: true,
              ),
            ),
          ],

          if (_selectedRole == UserRole.examiner ||
              _selectedRole == UserRole.doctor) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _practitionerCodeController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Access Code',
                hintText: 'Enter secret code',
                prefixIcon: Icon(Icons.vpn_key_rounded),
              ),
              validator: (value) =>
                  ((_selectedRole == UserRole.examiner ||
                          _selectedRole == UserRole.doctor) &&
                      (value == null || value.isEmpty))
                  ? 'Required'
                  : null,
            ),
          ],
          const SizedBox(height: 24),

          // --- Security Section ---
          _buildSectionTitle('Security', Icons.lock_outline_rounded),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            validator: (value) =>
                (value?.length ?? 0) < 6 ? 'Min 6 chars' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: !_isPasswordVisible,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _handleRegister(),
            decoration: const InputDecoration(labelText: 'Confirm Password'),
            validator: (value) =>
                (value != _passwordController.text) ? 'No match' : null,
          ),
          const SizedBox(height: 40),

          // --- Action Button ---
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary,
                  context.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.2),
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
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: EyeLoader(size: 24, color: AppColors.white),
                    )
                  : const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'By creating an account, you agree to our\nTerms of Service and Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
              height: 1.4,
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
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? context.primary.withValues(alpha: 0.05)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? context.primary
                : theme.dividerColor.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: isSelected
                  ? context.primary
                  : theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? context.primary
                    : theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
