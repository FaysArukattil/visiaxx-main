import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/family_member_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/family_member_model.dart';
import '../../../data/providers/test_session_provider.dart';
import '../../../core/widgets/eye_loader.dart';
import '../../../core/widgets/premium_dropdown.dart';
import '../../../core/utils/snackbar_utils.dart';

/// Profile selection screen - choose self or family member for testing
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  List<FamilyMemberModel> _familyMembers = [];
  bool _isLoading = true;

  // Service
  final FamilyMemberService _familyMemberService = FamilyMemberService();

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _phoneController = TextEditingController();
  String _selectedSex = 'Male';
  String _selectedRelationship = 'Spouse';

  final List<String> _relationships = [
    'Spouse',
    'Child',
    'Parent',
    'Sibling',
    'Grandparent',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  /// Load family members from Firebase
  Future<void> _loadFamilyMembers() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final members = await _familyMemberService
          .getFamilyMembers(user.uid)
          .timeout(
            const Duration(
              seconds: 10,
            ), // Increased from 2s to handle slower initial loads
            onTimeout: () {
              debugPrint(
                '[ProfileSelection] Family member fetch timed out after 10s',
              );
              return _familyMembers;
            },
          );
      if (mounted) {
        setState(() {
          _familyMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ProfileSelection] Error loading family members: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _selectSelf() async {
    final provider = context.read<TestSessionProvider>();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      provider.selectSelfProfile('guest_id', 'User');
      provider.startTest();
      Navigator.pushNamed(context, '/questionnaire');
      return;
    }

    // Use actual user data if available
    final String userId = user.uid;

    // Fetch profile data for age with FAST TIMEOUT
    final authService = AuthService();
    final userData = await authService
        .getUserData(userId)
        .timeout(
          const Duration(seconds: 3), // Increased from 1s
          onTimeout: () {
            debugPrint(
              '[ProfileSelection] Lightning Profile fetch timed out, using fallback',
            );
            return null;
          },
        );

    String userName = userData?.fullName ?? user.displayName ?? 'User';
    if (userName == 'User' && user.email != null) {
      userName = user.email!.split('@')[0];
    }
    int? age = userData?.age;

    if (!mounted) return;
    provider.selectSelfProfile(userId, userName, age);
    _proceedWithTest(provider);
  }

  void _selectFamilyMember(FamilyMemberModel member) {
    final provider = context.read<TestSessionProvider>();
    provider.selectFamilyMember(member);
    _proceedWithTest(provider);
  }

  void _proceedWithTest(TestSessionProvider provider) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final testType = args?['testType'] as String?;

    if (testType != null) {
      provider.startIndividualTest(testType);
      switch (testType) {
        case 'visual_acuity':
          Navigator.pushNamed(context, '/visual-acuity-standalone');
          break;
        case 'color_vision':
          Navigator.pushNamed(context, '/color-vision-standalone');
          break;
        case 'amsler_grid':
          Navigator.pushNamed(context, '/amsler-grid-standalone');
          break;
        case 'reading_test':
          Navigator.pushNamed(context, '/reading-test-standalone');
          break;
        case 'contrast_sensitivity':
          Navigator.pushNamed(context, '/contrast-sensitivity-standalone');
          break;
        case 'mobile_refractometry':
          Navigator.pushNamed(context, '/mobile-refractometry-standalone');
          break;
        default:
          Navigator.pushNamed(context, '/questionnaire');
      }
    } else {
      provider.startTest();
      Navigator.pushNamed(context, '/questionnaire');
    }
  }

  Future<void> _addFamilyMember({
    bool isEditing = false,
    String? memberId,
  }) async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) {
          SnackbarUtils.showError(
            context,
            'Please log in to ${isEditing ? 'update' : 'add'} family members',
          );
        }
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: EyeLoader(size: 60)),
      );

      final memberData = FamilyMemberModel(
        id: isEditing && memberId != null
            ? (memberId.contains('_') ? memberId.split('_').last : memberId)
            : DateTime.now().millisecondsSinceEpoch.toString(),
        firstName: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        sex: _selectedSex,
        relationship: _selectedRelationship,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : '+91${_phoneController.text.trim()}',
        createdAt: DateTime.now(),
      );

      try {
        debugPrint(
          '[ProfileSelection] ${isEditing ? 'Updating' : 'Saving'} member: ${memberData.firstName}',
        );

        String finalId;
        if (isEditing && memberId != null) {
          await _familyMemberService
              .updateFamilyMember(
                userId: user.uid,
                memberId: memberId,
                member: memberData,
              )
              .timeout(const Duration(seconds: 5));
          finalId = memberId;
        } else {
          finalId = await _familyMemberService
              .saveFamilyMember(userId: user.uid, member: memberData)
              .timeout(const Duration(seconds: 5));
        }

        debugPrint(
          '[ProfileSelection] Member ${isEditing ? 'updated' : 'saved'} with ID: $finalId',
        );

        if (mounted) Navigator.pop(context); // Close loader

        final savedMember = memberData.copyWith(id: finalId);

        if (mounted) {
          setState(() {
            if (isEditing) {
              final index = _familyMembers.indexWhere((m) => m.id == memberId);
              if (index != -1) {
                // Remove old identity if it changed
                if (memberId != savedMember.identityString) {
                  _familyMembers.removeAt(index);
                  _familyMembers.insert(0, savedMember);
                } else {
                  _familyMembers[index] = savedMember;
                }
              }
            } else {
              _familyMembers.insert(0, savedMember);
            }
            _nameController.clear();
            _ageController.clear();
            _phoneController.clear();
          });

          // Close bottom sheet
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }

          SnackbarUtils.showSuccess(
            context,
            '${savedMember.firstName} ${isEditing ? 'updated' : 'added'} successfully',
          );
        }
      } catch (e) {
        debugPrint(
          '[ProfileSelection] Warning: Action timed out or errored: $e',
        );

        if (mounted) Navigator.pop(context); // Close loader

        if (e.toString().contains('TimeoutException') ||
            e.toString().contains('UNAVAILABLE')) {
          // It's likely queued in Firestore local persistence
          if (mounted) {
            setState(() {
              if (isEditing) {
                final index = _familyMembers.indexWhere(
                  (m) => m.id == memberId,
                );
                if (index != -1) {
                  _familyMembers[index] = memberData;
                }
              } else {
                _familyMembers.insert(0, memberData);
              }
              _nameController.clear();
              _ageController.clear();
              _phoneController.clear();
            });

            // Close bottom sheet
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }

            SnackbarUtils.showInfo(
              context,
              'Saved locally. Will sync when online.',
            );
          }
        } else {
          if (mounted) {
            SnackbarUtils.showError(
              context,
              'Failed to ${isEditing ? 'update' : 'save'}: $e',
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: context.scaffoldBackground,
        elevation: 0,
        toolbarHeight: 20, // Reduced height since title is removed
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_familyMembers.isEmpty) {
            setState(() => _isLoading = true);
          }
          await _loadFamilyMembers();
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            // Hero Section
            _buildProfileCard(
              title: 'Test My Vision',
              subtitle: 'Quickly assess your own eye health',
              icon: Icons.remove_red_eye_rounded,
              color: context.primary,
              onTap: _selectSelf,
            ),
            const SizedBox(height: 32),

            // Family Profiles Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Family Profiles',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: context.textPrimary,
                      letterSpacing: -0.8,
                    ),
                  ),
                ),
                InkWell(
                  onTap: _showAddMemberSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: context.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.primary.withValues(alpha: 0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: context.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Add New',
                          style: TextStyle(
                            color: context.primary,
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

            // Family members list
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: EyeLoader(size: 40), // Smaller, non-blocking loader
                ),
              )
            else if (_familyMembers.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.dividerColor.withValues(alpha: 0.2),
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
                        color: context.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.family_restroom_rounded,
                        size: 48,
                        color: context.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Add family profiles to test for specific family members',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add family members to test their vision',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(
                _familyMembers.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFamilyMemberCard(_familyMembers[index]),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
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
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMemberCard(FamilyMemberModel member) {
    return GestureDetector(
      onTap: () => _selectFamilyMember(member),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.dividerColor.withValues(alpha: 0.2),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: context.primary.withValues(alpha: 0.04),
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
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    context.primary,
                    context.primary.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  member.firstName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
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
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      color: context.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${member.relationship} • ${member.age} years • ${member.sex}${member.phone != null ? ' • ${member.phone?.replaceFirst('+91', '+91 ')}' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
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
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: context.textSecondary,
                      ),
                      onPressed: () {
                        // Handle edit
                        _showEditMemberSheet(member);
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: context.error,
                      ),
                      onPressed: () {
                        // Handle delete
                        _confirmDeleteMember(member);
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
                    color: context.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: context.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMember(FamilyMemberModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: Text(
          'Are you sure you want to remove ${member.firstName}? Previous test results will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: context.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await _familyMemberService.deleteFamilyMember(user.uid, member.id);
        if (mounted) {
          setState(() {
            _familyMembers.removeWhere((m) => m.id == member.id);
          });
          SnackbarUtils.showSuccess(context, 'Profile removed');
        }
      } catch (e) {
        if (mounted) SnackbarUtils.showError(context, 'Failed to delete: $e');
      }
    }
  }

  void _showEditMemberSheet(FamilyMemberModel member) {
    _nameController.text = member.firstName;
    _ageController.text = member.age.toString();
    _phoneController.text = member.phone?.replaceFirst('+91', '') ?? '';
    _selectedSex = member.sex;
    _selectedRelationship = member.relationship;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: _buildAddMemberForm(
                      setSheetState,
                      isEditing: true,
                      memberId: member.id,
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

  void _showAddMemberSheet() {
    _nameController.clear();
    _ageController.clear();
    _phoneController.clear();
    _selectedSex = 'Male';
    _selectedRelationship = 'Spouse';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.dividerColor.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: _buildAddMemberForm(setSheetState),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddMemberForm(
    StateSetter setSheetState, {
    bool isEditing = false,
    String? memberId,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_add_rounded,
                  color: context.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? 'Edit Profile' : 'Add Family Member',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: context.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      isEditing
                          ? 'Update your family member details'
                          : 'Register a new family member for vision testing',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter name',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dividerColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dividerColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: (value) =>
                (value == null || value.isEmpty) ? 'Required' : null,
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
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Age',
                    hintText: 'Age',
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: context.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.dividerColor,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: context.dividerColor,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: context.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
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
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
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
          ),
          const SizedBox(height: 24),
          PremiumDropdown<String>(
            label: 'Relationship',
            value: _selectedRelationship,
            items: _relationships,
            itemLabelBuilder: (r) => r,
            onChanged: (value) {
              setSheetState(() => _selectedRelationship = value);
            },
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            decoration: InputDecoration(
              labelText: 'Phone Number',
              prefixText: '+91 ',
              prefixStyle: const TextStyle(fontWeight: FontWeight.bold),
              hintText: '10-digit number',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              filled: true,
              fillColor: context.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dividerColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.dividerColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: context.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  context.primary,
                  context.primary.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: context.primary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () =>
                  _addFamilyMember(isEditing: isEditing, memberId: memberId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isEditing ? 'Update Family Profile' : 'Save Family Profile',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
