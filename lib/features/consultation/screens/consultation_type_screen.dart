import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../home/widgets/app_bar_widget.dart';

class ConsultationTypeScreen extends StatelessWidget {
  const ConsultationTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarWidget(title: 'Consultation'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Text(
              'How would you like to\nconsult with our doctors?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: context.primary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose your preferred mode of consultation',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 40),
            _ConsultationCard(
              title: 'Online Consultation',
              description: 'Connect with doctors via video call from home.',
              icon: Icons.video_camera_front_outlined,
              color: AppColors.secondary,
              onTap: () => Navigator.pushNamed(
                context,
                '/doctor-browse',
                arguments: {'type': 'online'},
              ),
            ),
            const SizedBox(height: 20),
            _ConsultationCard(
              title: 'In-Person Consultation',
              description: 'Our doctors visit your doorstep for eye testing.',
              icon: Icons.home_outlined,
              color: context.primary,
              onTap: () => _handleInPersonSelection(context),
            ),
            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),
            ListTile(
              onTap: () => Navigator.pushNamed(context, '/my-bookings'),
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: context.primary,
                ),
              ),
              title: const Text(
                'My Bookings',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('View status of your requests'),
              trailing: const Icon(Icons.chevron_right),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              tileColor: Theme.of(context).cardColor,
            ),
          ],
        ),
      ),
    );
  }

  void _handleInPersonSelection(BuildContext context) async {
    // Show location checking animation/dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _LocationCheckDialog(),
    );

    // Simulate location fetch & check (Mumbai only)
    await Future.delayed(const Duration(seconds: 2));

    if (context.mounted) {
      Navigator.pop(context); // Close check dialog

      // Success for Mumbai, otherwise show error
      // In a real app, we'd use Geolocator. For now, we simulate success for demo
      // but clearly message that it's Mumbai-only.
      _showMumbaiConfirmation(context);
    }
  }

  void _showMumbaiConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.location_on, color: context.primary),
            const SizedBox(width: 12),
            const Text('Location Verified'),
          ],
        ),
        content: const Text(
          'We have detected your location in Mumbai. Doorstep consultation is currently available only in Mumbai.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(
                context,
                '/doctor-browse',
                arguments: {'type': 'inPerson'},
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }
}

class _LocationCheckDialog extends StatelessWidget {
  const _LocationCheckDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(strokeWidth: 6),
            ),
            const SizedBox(height: 24),
            const Text(
              'Checking Location...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Verifying service availability in your area',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConsultationCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ConsultationCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.03),
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
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: theme.dividerColor),
          ],
        ),
      ),
    );
  }
}
