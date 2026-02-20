import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';

class DoctorDetailScreen extends StatefulWidget {
  const DoctorDetailScreen({super.key});

  @override
  State<DoctorDetailScreen> createState() => _DoctorDetailScreenState();
}

class _DoctorDetailScreenState extends State<DoctorDetailScreen> {
  final _consultationService = ConsultationService();
  DoctorModel? _doctor;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  bool _isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final doctorId = args?['doctorId'];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];
    if (doctorId != null) {
      _loadDoctor(doctorId);
    }
  }

  Future<void> _loadDoctor(String doctorId) async {
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
      return Scaffold(
        backgroundColor: context.surface,
        body: Center(child: CircularProgressIndicator(color: context.primary)),
      );
    }

    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Doctor not found')));
    }

    final theme = Theme.of(context);
    final color = context.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Header with overlap and Hero
          SliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: color,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.8)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100,
                    left: 0,
                    right: 0,
                    child: Center(
                      child:
                          Hero(
                                tag: 'doctor_img_${_doctor!.id}',
                                child: Container(
                                  width: 180,
                                  height: 220,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(40),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 30,
                                        offset: const Offset(0, 15),
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
                                    color: AppColors.white.withValues(
                                      alpha: 0.3,
                                    ),
                                  ),
                                  child: _doctor!.photoUrl.isEmpty
                                      ? const Icon(
                                          Icons.person,
                                          size: 100,
                                          color: AppColors.white,
                                        )
                                      : null,
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(begin: const Offset(0.8, 0.8)),
                    ),
                  ),
                  Positioned(
                    bottom: -1,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: theme.scaffoldBackgroundColor,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(48),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _doctor!.degree.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Dr. ${_doctor!.fullName}',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _doctor!.specialty,
                          style: TextStyle(
                            fontSize: 16,
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 32),
                        _buildStatsGrid(),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 40),

                  const Text(
                    'About Doctor',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _doctor!.bio.isEmpty
                        ? 'Experienced eye specialist committed to providing the best vision care for all patients. Specializing in advanced diagnostic techniques and personalized treatment plans.'
                        : _doctor!.bio,
                    style: TextStyle(
                      fontSize: 15,
                      color: context.textSecondary,
                      height: 1.6,
                      letterSpacing: 0.1,
                    ),
                  ),

                  const SizedBox(height: 120), // Spacer for bottom button
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction()
          .animate()
          .fadeIn(delay: 400.ms)
          .slideY(begin: 0.5, end: 0),
    );
  }

  Widget _buildStatsGrid() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(
            'Experience',
            '${_doctor!.experienceYears}y+',
            Icons.work_history_rounded,
            Colors.blue,
          ),
          _statDivider(),
          _statItem(
            'Rating',
            '${_doctor!.rating}',
            Icons.star_rounded,
            Colors.amber,
          ),
          _statDivider(),
          _statItem(
            'Reviews',
            '${_doctor!.reviewCount}',
            Icons.chat_bubble_rounded,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _statDivider() {
    return Container(
      height: 40,
      width: 1,
      color: context.dividerColor.withValues(alpha: 0.1),
    );
  }

  Widget _statItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: context.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(
          context,
          '/slot-selection',
          arguments: {
            'doctor': _doctor,
            'latitude': _latitude,
            'longitude': _longitude,
            'exactAddress': _exactAddress,
          },
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: AppColors.white,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Select Doctor',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
