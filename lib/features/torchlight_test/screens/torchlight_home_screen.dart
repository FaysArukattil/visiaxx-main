import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../data/providers/test_session_provider.dart';

class TorchlightHomeScreen extends StatelessWidget {
  const TorchlightHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: AppBar(
        title: const Text('Torchlight Examination'),
        backgroundColor: context.scaffoldBackground,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 32),
                    _TestCard(
                      title: 'Pupillary Examination',
                      description:
                          'Check pupil size, symmetry, and light reflexes (direct, consensual, and RAPD).',
                      icon: Icons.remove_red_eye_rounded,
                      color: context.primary,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 20),
                    _TestCard(
                      title: 'Extraocular Muscle Test',
                      description:
                          'Evaluate eye movements across different planes to check for muscle or nerve issues.',
                      icon: Icons.open_with_rounded,
                      color: context.primary,
                      screenWidth: screenWidth,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
            _buildBottomAction(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: context.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Two-Part Examination',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: context.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Commonly performed by practitioners to screen for neurological and muscle abnormalities.',
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).padding.bottom > 0 ? 8 : 24,
      ),
      decoration: BoxDecoration(color: context.scaffoldBackground),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () {
            // Initialize individual test session
            context.read<TestSessionProvider>().startIndividualTest(
              'torchlight',
            );
            // Start the continuous flow: Instructions -> Pupillary -> Extraocular
            Navigator.pushNamed(context, '/torchlight-instructions');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: context.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 4,
            shadowColor: context.primary.withValues(alpha: 0.3),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Begin Full Examination',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final double screenWidth;
  const _TestCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.screenWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24)),
      child: Ink(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.scaffoldBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
