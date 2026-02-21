import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../core/constants/app_colors.dart';
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
          // Background Parallels with Browse Screen Decorative Circles
          Positioned(
            top: -100,
            right: -50,
            child: _buildDecorativeCircle(color, 300, 0.03),
          ),
          Positioned(
            bottom: 150,
            left: -80,
            child: _buildDecorativeCircle(color, 250, 0.02),
          ),

          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Premium Header Region
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: context.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 20,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.surface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.more_vert_rounded,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Unified Dashboard Layout
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(28, 16, 28, 140),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stylized Doctor Headshot & Basic Info
                        Row(
                          children: [
                            Hero(
                              tag: _isFeatured
                                  ? 'doctor_img_${_doctor!.id}_featured'
                                  : 'doctor_img_${_doctor!.id}',
                              child: Container(
                                width: 120,
                                height: 140,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(32),
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: color.withValues(alpha: 0.1),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
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
                                        size: 60,
                                        color: color.withValues(alpha: 0.2),
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child:
                                  Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: color.withValues(
                                                alpha: 0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              _doctor!.degree.toUpperCase(),
                                              style: TextStyle(
                                                color: color,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Dr. ${_doctor!.fullName}',
                                            style: const TextStyle(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              height: 1.1,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _doctor!.specialty,
                                            style: TextStyle(
                                              color: context.textSecondary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      )
                                      .animate()
                                      .fadeIn(duration: 600.ms)
                                      .slideX(begin: 0.1, end: 0),
                            ),
                          ],
                        ),

                        const SizedBox(height: 40),

                        // Section: Clinical Overview
                        const _SectionTitle(title: 'Overview'),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildOverviewStat(
                              Icons.history_rounded,
                              '${_doctor!.experienceYears} Years',
                              'Experience',
                              color,
                            ),
                            _buildOverviewStat(
                              Icons.calendar_today_rounded,
                              '42 Years',
                              'Patient Age',
                              Colors.teal,
                            ),
                            _buildOverviewStat(
                              Icons.rate_review_rounded,
                              '${_doctor!.rating}',
                              'User Rating',
                              Colors.amber,
                            ),
                          ],
                        ).animate().fadeIn(delay: 200.ms),

                        const SizedBox(height: 12),
                        // Professional Availability Row
                        Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withValues(alpha: 0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time_filled_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Available for 10-10 Mon-Fri',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .animate()
                            .fadeIn(delay: 300.ms)
                            .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 40),

                        // Section: Biography
                        const _SectionTitle(title: 'Biography'),
                        const SizedBox(height: 16),
                        Text(
                          _doctor!.bio,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textSecondary,
                            height: 1.6,
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Pinned Action Button (Professional floating style)
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

  Widget _buildOverviewStat(
    IconData icon,
    String value,
    String label,
    Color iconColor,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: context.textTertiary,
              letterSpacing: 0.2,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(Color color) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 36),
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
              minimumSize: const Size(double.infinity, 64),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: color.withValues(alpha: 0.3),
            ),
            child: const Text(
              'Book Appointment',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3, end: 0);
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
        letterSpacing: -0.5,
      ),
    );
  }
}
