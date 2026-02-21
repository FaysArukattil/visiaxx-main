import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../core/widgets/eye_loader.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final _consultationService = ConsultationService();
  DoctorModel? _doctor;
  bool _isLoading = true;
  bool _isFeatured = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final doctorId = args?['doctorId'] as String?;
    _isFeatured = args?['isFeatured'] ?? false;
    if (doctorId != null) {
      _loadDoctorDetail(doctorId);
    }
  }

  Future<void> _loadDoctorDetail(String doctorId) async {
    setState(() => _isLoading = true);
    final doctor = await _consultationService.getDoctorById(doctorId);
    setState(() {
      _doctor = doctor;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: EyeLoader.fullScreen()));
    }
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Doctor not found')));
    }

    final color = context.primary;

    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: Stack(
        children: [
          // Background Decorative Circles (Institutional Primary Tints)
          Positioned(
            top: -120,
            right: -60,
            child: _buildDecorativeCircle(color, 380, 0.04),
          ),
          Positioned(
            bottom: 120,
            left: -100,
            child: _buildDecorativeCircle(color, 320, 0.03),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Integrated Physician Identity & Dashboard Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Separate Top Navigation Row
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          icon: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.surface.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new,
                              size: 18,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 2. Professional Identity Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Hero(
                              tag: _isFeatured
                                  ? 'doctor_img_${_doctor!.id}_featured'
                                  : 'doctor_img_${_doctor!.id}',
                              child: Container(
                                width: 90,
                                height: 110,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                  image: _doctor!.photoUrl.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(
                                            _doctor!.photoUrl,
                                          ),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: _doctor!.photoUrl.isEmpty
                                    ? Icon(
                                        Icons.person_rounded,
                                        size: 50,
                                        color: color.withValues(alpha: 0.2),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      _doctor!.degree.toUpperCase(),
                                      style: TextStyle(
                                        color: color,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Dr. ${_doctor!.fullName}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.8,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _doctor!.specialty,
                                    style: TextStyle(
                                      color: context.textSecondary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Section: Clinical Statistics (Glass Squircle)
                        const _SectionTitle(title: 'Overview'),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _buildClinicalStat(
                              icon: Icons.work_history_rounded,
                              value: '${_doctor!.experienceYears} Years',
                              label: 'Experience',
                              color: color,
                            ),
                            const SizedBox(width: 12),
                            _buildClinicalStat(
                              icon: Icons.calendar_today_rounded,
                              value: '42 Years',
                              label: 'Age',
                              color: Colors.teal,
                            ),
                            const SizedBox(width: 12),
                            _buildClinicalStat(
                              icon: Icons.star_rounded,
                              value: '${_doctor!.rating}',
                              label: 'Rating',
                              color: Colors.amber,
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 28),
                        // Elongated Glass Availability Bar
                        ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: color.withValues(alpha: 0.12),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        color: color,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'MON - FRI',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: color,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        height: 16,
                                        width: 1.2,
                                        color: color.withValues(alpha: 0.15),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: context.textTertiary,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            '10:00 AM - 10:00 PM',
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
                                              color: context.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.1, end: 0),

                        const SizedBox(height: 48),

                        // Section: Biography
                        const _SectionTitle(title: 'Professional Bio'),
                        const SizedBox(height: 16),
                        Text(
                          _doctor!.bio,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textSecondary,
                            height: 1.7,
                            letterSpacing: -0.1,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Institutional Action Footer
          _buildBottomAction(color),
        ],
      ),
    );
  }

  Widget _buildDecorativeCircle(Color color, double size, double alpha) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }

  // Refined High-Precision Squircle Glass Stat
  Widget _buildClinicalStat({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: color.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: context.textTertiary,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(Color color) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        decoration: BoxDecoration(
          color: context.scaffoldBackground,
          border: Border(
            top: BorderSide(
              color: context.dividerColor.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/slot-selection',
                arguments: {
                  'doctor': _doctor,
                  'latitude': args?['latitude'],
                  'longitude': args?['longitude'],
                  'exactAddress': args?['exactAddress'],
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 66),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Book Consultation',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0);
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
      ),
    );
  }
}
