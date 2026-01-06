import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/family_member_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/models/family_member_model.dart';
import '../../../data/providers/test_session_provider.dart';

/// Profile selection screen - choose self or family member for testing
class ProfileSelectionScreen extends StatefulWidget {
  const ProfileSelectionScreen({super.key});

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  List<FamilyMemberModel> _familyMembers = [];
  bool _showAddForm = false;
  bool _isLoading = true;

  // Service
  final FamilyMemberService _familyMemberService = FamilyMemberService();

  // Form controllers
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
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
      final members = await _familyMemberService.getFamilyMembers(user.uid);
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

    // Fetch profile data for age
    final authService = AuthService();
    final userData = await authService.getUserData(userId);

    String userName = userData?.fullName ?? user.displayName ?? 'User';
    if (userName == 'User' && user.email != null) {
      userName = user.email!.split('@')[0];
    }
    int? age = userData?.age;

    if (!mounted) return;
    provider.selectSelfProfile(userId, userName, age);
    provider.startTest();
    Navigator.pushNamed(context, '/questionnaire');
  }

  void _selectFamilyMember(FamilyMemberModel member) {
    final provider = context.read<TestSessionProvider>();
    provider.selectFamilyMember(member);
    provider.startTest();
    Navigator.pushNamed(context, '/questionnaire');
  }

  Future<void> _addFamilyMember() async {
    if (_formKey.currentState!.validate()) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in to add family members'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      // ✅ Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final newMember = FamilyMemberModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
        firstName: _nameController.text.trim(),
        age: int.parse(_ageController.text),
        sex: _selectedSex,
        relationship: _selectedRelationship,
        createdAt: DateTime.now(),
      );

      try {
        debugPrint('[ProfileSelection] Saving member: ${newMember.firstName}');

        // Save to Firebase
        final savedId = await _familyMemberService.saveFamilyMember(
          userId: user.uid,
          member: newMember,
        );

        debugPrint('[ProfileSelection] ✅ Member saved with ID: $savedId');

        // Update local list with Firebase ID
        final savedMember = newMember.copyWith(id: savedId);

        // ✅ Close loading dialog
        if (mounted) Navigator.pop(context);

        if (!mounted) return;

        setState(() {
          _familyMembers.insert(0, savedMember);
          _showAddForm = false;
          _nameController.clear();
          _ageController.clear();
          _selectedSex = 'Male';
          _selectedRelationship = 'Spouse';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${savedMember.firstName} added successfully'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        debugPrint('[ProfileSelection] ❌ Error saving member: $e');

        // ✅ Close loading dialog
        if (mounted) Navigator.pop(context);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Who is taking the test?')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Self test card
            _buildProfileCard(
              title: 'Test for Yourself',
              subtitle: 'Start a vision test for your own eyes',
              icon: Icons.person,
              color: AppColors.primary,
              onTap: _selectSelf,
            ),
            const SizedBox(height: 24),
            // Family members section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Family Members',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showAddForm = !_showAddForm;
                    });
                  },
                  icon: Icon(_showAddForm ? Icons.close : Icons.add),
                  label: Text(_showAddForm ? 'Cancel' : 'Add Member'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Add family member form
            if (_showAddForm) ...[
              _buildAddMemberForm(),
              const SizedBox(height: 16),
            ],
            // Family members list
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_familyMembers.isEmpty && !_showAddForm)
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
                      Icons.family_restroom,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No family members added',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add family members to test their vision',
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
                _familyMembers.length,
                (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildFamilyMemberCard(_familyMembers[index]),
                ),
              ),
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: Colors.white, size: 36),
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyMemberCard(FamilyMemberModel member) {
    return GestureDetector(
      onTap: () => _selectFamilyMember(member),
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
                member.firstName[0].toUpperCase(),
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
                    member.firstName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${member.relationship} • ${member.age} years • ${member.sex}',
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

  Widget _buildAddMemberForm() {
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
              'Add Family Member',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'First Name *',
                hintText: 'Enter name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
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
            DropdownButtonFormField<String>(
              initialValue: _selectedRelationship,
              decoration: const InputDecoration(labelText: 'Relationship *'),
              items: _relationships.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedRelationship = value!);
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _addFamilyMember,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Save Family Member'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
