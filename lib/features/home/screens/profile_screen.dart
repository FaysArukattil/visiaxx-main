import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/data_cleanup_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../data/models/user_model.dart';
import '../../eye_care_tips/screens/eye_care_tips_screen.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SessionMonitorService().stopMonitoring();
      await DataCleanupService.cleanupAllData(context);
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildSection(
              title: 'Account Settings',
              items: [
                _buildProfileItem(
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      'Settings',
                      'Settings functionality coming soon.',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Health & Wellness',
              items: [
                _buildProfileItem(
                  icon: Icons.tips_and_updates_outlined,
                  title: 'Eye Healthcare Tips',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const EyeCareTipsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Information',
              items: [
                _buildProfileItem(
                  icon: Icons.gavel_outlined,
                  title: 'Legal Notice & Terms',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      'Legal Notice & Terms',
                      'Our legal policies ensure your data privacy and outline the terms of using Visiaxx Digital Eye Clinic. Full document available upon request.',
                    );
                  },
                ),
                _buildProfileItem(
                  icon: Icons.lightbulb_outline,
                  title: 'Our Vision & Mission',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      'Our Vision & Mission',
                      'Vision: Create a future where comprehensive eye care is universally accessible and technology-driven.\n\nMission: Deliver high-quality, validated eye-care solutions through intuitive digital platforms.',
                    );
                  },
                ),
                _buildProfileItem(
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () {
                    _showInfoDialog(
                      context,
                      'About Us',
                      'Vision Optocare reshapes eye care with mobile-first technology and optometric precision. Visiaxx is our flagship digital eye clinic application.',
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              title: 'Support',
              items: [
                _buildProfileItem(
                  icon: Icons.support_agent,
                  title: 'Contact Us / Customer Care',
                  subtitle: '7208804568',
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: '7208804568'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Number copied to clipboard'),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLogoutButton(context),
            const SizedBox(height: 48),
            _buildQuote(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(
              user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          user.fullName,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1C1E),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 2),
        Text(
          user.phone,
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildSection({required String title, required List<Widget> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: items),
        ),
      ],
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1C1E),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.1)),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout, size: 20),
            SizedBox(width: 12),
            Text(
              'Logout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuote() {
    return Column(
      children: [
        Icon(
          Icons.format_quote,
          color: AppColors.primary.withValues(alpha: 0.2),
          size: 40,
        ),
        const SizedBox(height: 8),
        const Text(
          "Seeing life from 2026, we're just getting started.\nWe'll be here for quite a while.",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            color: Color(0xFF1A1C1E),
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
