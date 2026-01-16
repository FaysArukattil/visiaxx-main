import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/snackbar_utils.dart';
import '../../../core/widgets/eye_loader.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _notificationsEnabled = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When user returns from settings, recheck permission
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    setState(() {
      _notificationsEnabled = status.isGranted;
      _isLoading = false;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    if (value) {
      // Request permission to enable
      final status = await Permission.notification.request();

      if (status.isGranted) {
        setState(() {
          _notificationsEnabled = true;
        });
        if (mounted) {
          _showSuccessSnackbar('Notifications enabled successfully');
        }
      } else if (status.isPermanentlyDenied || status.isDenied) {
        // Instantly open settings without dialog
        await openAppSettings();
      }
    } else {
      // Show info that user needs to disable in settings
      _showDisableInfoSnackbar();
      // Instantly open settings to disable
      await openAppSettings();
    }
  }

  void _showDisableInfoSnackbar() {
    SnackbarUtils.showInfo(
      context,
      'Please disable notifications in your device settings',
    );
  }

  void _showSuccessSnackbar(String message) {
    SnackbarUtils.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: EyeLoader.fullScreen())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notifications Section
                  _buildSectionTitle('Notifications'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _buildToggleItem(
                        icon: Icons.notifications_outlined,
                        title: 'Push Notifications',
                        subtitle: _notificationsEnabled
                            ? 'Receiving eye health updates'
                            : 'Tap to enable in device settings',
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                      ),
                    ],
                  ),

                  // Show helpful button when notifications are off
                  if (!_notificationsEnabled) ...[
                    const SizedBox(height: 12),
                    _buildNotificationHelperButton(),
                  ],

                  const SizedBox(height: 24),

                  // App Preferences Section
                  _buildSectionTitle('App Preferences'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _buildNavigationItem(
                        icon: Icons.language,
                        title: 'Language',
                        subtitle: 'English (United States)',
                        onTap: () {
                          _showComingSoonDialog('Language Selection');
                        },
                      ),
                      const Divider(height: 1, indent: 68),
                      _buildNavigationItem(
                        icon: Icons.palette_outlined,
                        title: 'Theme',
                        subtitle: 'Light Mode',
                        onTap: () {
                          _showComingSoonDialog('Theme Selection');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Privacy & Security Section
                  _buildSectionTitle('Privacy & Security'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _buildNavigationItem(
                        icon: Icons.security,
                        title: 'Privacy Policy',
                        onTap: () {
                          _showComingSoonDialog('Privacy Policy');
                        },
                      ),
                      const Divider(height: 1, indent: 68),
                      _buildNavigationItem(
                        icon: Icons.lock_outline,
                        title: 'Data & Security',
                        onTap: () {
                          _showComingSoonDialog('Data & Security');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Support Section
                  _buildSectionTitle('Support'),
                  const SizedBox(height: 12),
                  _buildSettingsCard(
                    children: [
                      _buildNavigationItem(
                        icon: Icons.help_outline,
                        title: 'Help Center',
                        onTap: () {
                          _showComingSoonDialog('Help Center');
                        },
                      ),
                      const Divider(height: 1, indent: 68),
                      _buildNavigationItem(
                        icon: Icons.bug_report_outlined,
                        title: 'Report a Bug',
                        onTap: () {
                          _showComingSoonDialog('Bug Report');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // App Version
                  _buildAppVersion(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // iOS-style toggle with primary color
          Transform.scale(
            scale: 0.85,
            child: CupertinoSwitch(
              value: value,
              activeTrackColor: AppColors.primary,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationHelperButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: AppColors.warning, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications are turned off',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Enable them to receive important eye health updates',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () async {
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Enable',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            )
          : null,
      trailing: const Icon(
        Icons.chevron_right,
        size: 20,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'About Notifications',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'We\'ll send you reminders for eye tests, health tips, and important updates. You can manage these preferences anytime in your device settings.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppVersion() {
    return Center(
      child: Column(
        children: [
          Text(
            'Visiaxx Digital Eye Clinic',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version 1.0.0',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.rocket_launch, color: AppColors.primary),
            const SizedBox(width: 12),
            const Text('Coming Soon'),
          ],
        ),
        content: Text(
          '$feature will be available in a future update. Stay tuned!',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}

