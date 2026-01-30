import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/network_connectivity_provider.dart';
import 'package:flutter/services.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visiaxx/core/services/review_service.dart';
import 'package:visiaxx/features/home/screens/settings_screen.dart';
import 'package:visiaxx/features/home/widgets/review_dialog.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/data_cleanup_service.dart';
import '../../../core/services/session_monitor_service.dart';
import '../../../data/models/user_model.dart';
import '../../eye_care_tips/screens/eye_care_tips_screen.dart';
import '../../../core/utils/snackbar_utils.dart';

class ProfileScreen extends StatelessWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  Future<void> _handleLogout(BuildContext context) async {
    final connectivity = Provider.of<NetworkConnectivityProvider>(
      context,
      listen: false,
    );
    if (!connectivity.isOnline) {
      SnackbarUtils.showNoInternet(
        context,
        customMessage: "Can't logout without internet",
      );
      return;
    }

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
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      SessionMonitorService().stopMonitoring();
      if (!context.mounted) return;
      await DataCleanupService.cleanupAllData(context);
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
      }
    }
  }

  void _showOptionDetails(BuildContext context, String title, Widget content) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: content,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('My Profile'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileHeader(context),
            const SizedBox(height: 32),
            _buildSection(
              context: context,
              title: 'Account Settings',
              items: [
                _buildProfileItem(
                  context: context,
                  icon: Icons.settings_outlined,
                  title: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context: context,
              title: 'Health & Wellness',
              items: [
                _buildProfileItem(
                  context: context,
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
              context: context,
              title: 'Information',
              items: [
                _buildProfileItem(
                  context: context,
                  icon: Icons.gavel_outlined,
                  title: 'Legal Notice & Terms',
                  onTap: () {
                    _showOptionDetails(
                      context,
                      'Legal Notice & Terms',
                      _buildLegalContent(context),
                    );
                  },
                ),
                _buildProfileItem(
                  context: context,
                  icon: Icons.lightbulb_outline,
                  title: 'Our Vision & Mission',
                  onTap: () {
                    _showOptionDetails(
                      context,
                      'Our Vision & Mission',
                      _buildVisionMissionContent(context),
                    );
                  },
                ),
                _buildProfileItem(
                  context: context,
                  icon: Icons.info_outline,
                  title: 'About Us',
                  onTap: () {
                    _showOptionDetails(
                      context,
                      'About Us',
                      _buildAboutUsContent(context),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context: context,
              title: 'Support',
              items: [
                _buildProfileItem(
                  context: context,
                  icon: Icons.support_agent,
                  title: 'Contact Us',
                  onTap: () {
                    _showOptionDetails(
                      context,
                      'Contact Us',
                      _buildContactContent(context),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSection(
              context: context,
              title: 'Feedback',
              items: [
                _buildProfileItem(
                  context: context,
                  icon: Icons.reviews_outlined,
                  title: 'Give us Feedback',
                  subtitle: 'Share your experience',
                  onTap: () => _showReviewDialog(context),
                ),
                _buildProfileItem(
                  context: context,
                  icon: Icons.store_outlined,
                  title: Platform.isIOS
                      ? 'Rate us on App Store'
                      : 'Rate us on Play Store',
                  subtitle: 'Help us grow',
                  onTap: () => _openStoreRating(),
                ),
              ],
            ),

            const SizedBox(height: 32),
            _buildLogoutButton(context),
            const SizedBox(height: 48),
            _buildQuote(),
            const SizedBox(height: 32),
            const Center(
              child: Text(
                'By using Visiaxx, you agree to our Terms & Policies',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
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
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          user.phone.replaceFirst('+91', '+91 '),
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildSection({
    required BuildContext context,
    required String title,
    required List<Widget> items,
  }) {
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
              color: AppColors.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
    required BuildContext context,
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
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
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
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 14,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _handleLogout(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).cardColor,
          foregroundColor: Theme.of(context).colorScheme.error,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
            ),
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

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'vnoptocare@gmail.com',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    }
  }

  Future<void> _launchMaps() async {
    // Open Mumbai in Google Maps
    final Uri googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=Mumbai',
    );
    if (await canLaunchUrl(googleMapsUri)) {
      await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showReviewDialog(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final reviewService = ReviewService();
    final hasReviewed = await reviewService.hasUserReviewed(user.uid);

    if (hasReviewed) {
      // Show confirmation dialog
      if (context.mounted) {
        final reviewCount = await reviewService.getReviewCount(user.uid);
        if (!context.mounted) return;
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.star, color: AppColors.primary, size: 24),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Submit Another Review?',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Text(
              'You have already submitted ${reviewCount == 1 ? 'a review' : '$reviewCount reviews'}. Would you like to send one more?',
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Yes, Continue'),
              ),
            ],
          ),
        );

        if (shouldProceed == true && context.mounted) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: AppColors.transparent,
            builder: (context) => const ReviewDialog(),
          );
        }
      }
      return;
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.transparent,
        builder: (context) => const ReviewDialog(),
      );
    }
  }

  Future<void> _openStoreRating() async {
    try {
      final inAppReview = InAppReview.instance;

      // Try to show in-app review first
      if (await inAppReview.isAvailable()) {
        await inAppReview.requestReview();
      } else {
        // Fallback to opening store listing
        await inAppReview.openStoreListing(
          appStoreId:
              '', // iOS App Store ID - will be configured when available
        );
      }
    } catch (e) {
      debugPrint('Error opening store rating: $e');
    }
  }

  Widget _buildContactContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Get in Touch',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          'Our customer support team is available to assist you with any queries or technical issues.',
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        _buildContactDetailItem(
          context: context,
          icon: Icons.phone_outlined,
          title: 'Phone',
          value: '7208996265',
          onTap: () async {
            final Uri phoneUri = Uri(scheme: 'tel', path: '7208996265');
            if (await canLaunchUrl(phoneUri)) {
              await launchUrl(phoneUri);
            } else {
              Clipboard.setData(const ClipboardData(text: '7208996265'));
              if (context.mounted) {
                SnackbarUtils.showSuccess(
                  context,
                  'Number copied to clipboard',
                );
              }
            }
          },
        ),
        _buildContactDetailItem(
          context: context,
          icon: Icons.chat_outlined,
          title: 'WhatsApp',
          value: '7208996265',
          onTap: () async {
            final Uri whatsappUri = Uri.parse('https://wa.me/917208996265');
            if (await canLaunchUrl(whatsappUri)) {
              await launchUrl(
                whatsappUri,
                mode: LaunchMode.externalApplication,
              );
            } else {
              Clipboard.setData(const ClipboardData(text: '7208996265'));
              if (context.mounted) {
                SnackbarUtils.showSuccess(context, 'WhatsApp number copied');
              }
            }
          },
        ),
        _buildContactDetailItem(
          context: context,
          icon: Icons.email_outlined,
          title: 'Email',
          value: 'vnoptocare@gmail.com',
          showCopyIcon: false,
          onTap: _launchEmail,
        ),
        _buildContactDetailItem(
          context: context,
          icon: Icons.location_on_outlined,
          title: 'Office',
          value: 'Vision Optocare, Mumbai',
          showCopyIcon: false,
          onTap: _launchMaps,
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.report_problem_outlined,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'For serious issues, please message us on WhatsApp for immediate assistance.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Working hours: 9:00 AM - 6:00 PM (Monday to Saturday)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactDetailItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    bool showCopyIcon = true,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
      ),
      subtitle: Text(
        value,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      trailing: showCopyIcon
          ? const Icon(
              Icons.copy_outlined,
              size: 16,
              color: AppColors.textTertiary,
            )
          : null,
    );
  }

  Widget _buildLegalContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Disclaimer & Terms of Use',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16),
        Text(
          'Visiaxx Digital Eye Clinic is a vision screening platform developed by Vision Optocare. By using this application, you acknowledge and agree to the following:',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        SizedBox(height: 16),
        _LegalSection(
          title: '1. Screening Tool Only',
          content:
              'Visiaxx is designed for vision screening and monitoring purposes. It is NOT a diagnostic tool and does not provide a definitive medical diagnosis.',
        ),
        _LegalSection(
          title: '2. Potential for Errors',
          content:
              'While we strive for accuracy using clinical standards and AI analysis, results may vary due to lighting, device calibration, user error, or environmental factors.',
        ),
        _LegalSection(
          title: '3. No Medical Liability',
          content:
              'Vision Optocare and its affiliates are not responsible for your health outcomes. The results provided should not be used as a substitute for professional medical advice, diagnosis, or treatment.',
        ),
        _LegalSection(
          title: '4. Consult a Professional',
          content:
              'If you experience any symptoms or have concerns about your vision, you MUST consult a certified doctor or optometrist immediately.',
        ),
        _LegalSection(
          title: '5. Data Collection',
          content:
              'We collect test data, including vision scores, Amsler grid tracings, and user-provided information, to generate reports, improve our AI algorithms, and conduct clinical research. Your privacy is protected in accordance with our data policy.',
        ),
        _LegalSection(
          title: '6. System Improvement & Data Collection',
          content:
              'When you submit a review, feedback, or technical bug report, we collect your name, age, and descriptive details. Technical reports are stored in a dedicated secure database section and shared with our development team. This data is used exclusively to improve our AI algorithms, resolve technical glitches, and enhance the overall reliability of the Visiaxx Digital Eye Clinic.',
        ),
        const SizedBox(height: 20),
        const Text(
          'By continuing to use Visiaxx, you accept these terms and conditions.',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildVisionMissionContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AboutSection(
          context: context,
          title: 'Our Vision',
          content:
              'We envision a world where eye care is universally accessible through AI, tele-optometry, and digital screening €” promoting proactive vision health for all.',
        ),
        SizedBox(height: 24),
        _AboutSection(
          context: context,
          title: 'Our Mission',
          content:
              'Our mission is to deliver affordable, preventive, and smart eye care through innovative digital platforms.',
        ),
      ],
    );
  }

  Widget _buildAboutUsContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AboutSection(
          context: context,
          title: 'Who We Are',
          content:
              'Vision Optocare is a forward-thinking digital health startup focused on reshaping how primary eye care is delivered. By merging optometric precision with mobile-first technology, we aim to make vision care more accessible and data-driven across the globe.',
        ),
        const SizedBox(height: 24),
        _AboutSection(
          context: context,
          title: 'Our Product',
          content:
              'Our flagship solution, the Visiaxx Digital Eye Clinic App, empowers users to conduct clinically approved vision screenings directly from their smartphones. Feature-rich, validated, and user-centric, Visiaxx is your personal eye care companion.',
        ),
        const SizedBox(height: 24),
        Text(
          'Our Expertise',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        const _ExpertiseItem(
          icon: Icons.visibility_outlined,
          title: 'Visual Acuity Test',
          description:
              'Precision-calibrated Tumbling E chart with real-time distance monitoring for accurate visual clarity assessment.',
        ),
        const _ExpertiseItem(
          icon: Icons.palette_outlined,
          title: 'Color Blindness Screening',
          description:
              'Comprehensive Ishihara-based digital plates to detect Red-Green and other color perception deficiencies.',
        ),
        const _ExpertiseItem(
          icon: Icons.grid_on_outlined,
          title: 'Amsler Grid Assessment',
          description:
              'Advanced diagnostic tool for monitoring macular health and identifying early signs of retinal distortion or AMD.',
        ),
        const _ExpertiseItem(
          icon: Icons.contrast_outlined,
          title: 'Contrast Sensitivity',
          description:
              'Clinical-grade Pelli-Robson implementation to evaluate functional vision and light-to-dark transition quality.',
        ),
        const _ExpertiseItem(
          icon: Icons.chrome_reader_mode_outlined,
          title: 'Reading & Near Vision',
          description:
              'Specialized short-distance testing for presbyopia and reading comfort assessment in daily environments.',
        ),
        const _ExpertiseItem(
          icon: Icons.psychology_outlined,
          title: 'AI Image Processing',
          description:
              'State-of-the-art computer vision algorithms for precise face tracking, distance calibration, and result validation.',
        ),
        const SizedBox(height: 24),
        _AboutSection(
          context: context,
          title: 'Why It Matters',
          content:
              'With over 80% of vision issues being preventable, millions still go undiagnosed due to lack of access. Visiaxx bridges this gap by enabling early detection, personalized insights, and continuous monitoring of visual health.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Text(
                'We provide an outstanding purchasing experience to our users. Our collection includes a wide variety of frames, sunglasses, and contact lenses.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1C1E),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Doctor consultation available with prior online appointment.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuote() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 1.5,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Seeing life from 2026, we're just getting started.\nWe'll be here for quite a while.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: AppColors.textTertiary,
              height: 1.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpertiseItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _ExpertiseItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1C1E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
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
}

class _LegalSection extends StatelessWidget {
  final String title;
  final String content;

  const _LegalSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final BuildContext context;
  final String title;
  final String content;

  const _AboutSection({
    required this.context,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          content,
          style: const TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }
}
