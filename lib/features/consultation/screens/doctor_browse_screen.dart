import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../core/widgets/eye_loader.dart';

class DoctorBrowseScreen extends StatefulWidget {
  const DoctorBrowseScreen({super.key});

  @override
  State<DoctorBrowseScreen> createState() => _DoctorBrowseScreenState();
}

class _DoctorBrowseScreenState extends State<DoctorBrowseScreen> {
  final _consultationService = ConsultationService();
  final _searchController = TextEditingController();
  List<DoctorModel> _allDoctors = [];
  List<DoctorModel> _filteredDoctors = [];
  bool _isLoading = true;
  String? _consultationType;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  StreamSubscription? _doctorsSubscription;
  bool _argsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsInitialized) {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      _consultationType = args?['type'];
      _latitude = args?['latitude'];
      _longitude = args?['longitude'];
      _exactAddress = args?['exactAddress'];
      _argsInitialized = true;
      _subscribeToDoctors();
    }
  }

  @override
  void dispose() {
    _doctorsSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _subscribeToDoctors() {
    _doctorsSubscription?.cancel();
    _doctorsSubscription = _consultationService.getAllDoctorsStream().listen(
      (doctors) {
        // Filter by availability for the selected type (online/inPerson)
        final filtered = _consultationType == null
            ? doctors
            : doctors
                  .where(
                    (d) => d.availableServices.contains(
                      _consultationType == 'online' ? 'Online' : 'In-Person',
                    ),
                  )
                  .toList();

        if (mounted) {
          setState(() {
            _allDoctors = filtered;
            _filterDoctors(_searchController.text);
            _isLoading = false;
          });
        }
      },
      onError: (_) {
        if (mounted) setState(() => _isLoading = false);
      },
    );
  }

  Future<void> _refreshDoctors() async {
    // Pull-to-refresh: re-subscribe
    _subscribeToDoctors();
  }

  void _filterDoctors(String query) {
    setState(() {
      _filteredDoctors = _allDoctors.where((doctor) {
        final name = doctor.fullName.toLowerCase();
        final specialty = doctor.specialty.toLowerCase();
        final degree = doctor.degree.toLowerCase();
        return name.contains(query.toLowerCase()) ||
            specialty.contains(query.toLowerCase()) ||
            degree.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = _consultationType == 'online';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: EyeLoader.fullScreen())
          : Stack(
              children: [
                // Background decorative circles
                Positioned(
                  top: -100,
                  right: -50,
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.primary.withValues(alpha: 0.03),
                    ),
                  ),
                ),

                SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _refreshDoctors,
                    color: context.primary,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        // Header with Back Button
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                            child:
                                Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          icon: Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: context.surface,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
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
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isOnline
                                                    ? 'Online Doctors'
                                                    : 'Home Visit Doctors',
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  fontWeight: FontWeight.w900,
                                                  height: 1.1,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Find the best specialists in Mumbai',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: context.textSecondary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    )
                                    .animate()
                                    .fadeIn(duration: 500.ms)
                                    .slideY(begin: -0.2, end: 0),
                          ),
                        ),

                        // Search Bar
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                            child:
                                Container(
                                      decoration: BoxDecoration(
                                        color: context.surface,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: context.primary.withValues(
                                            alpha: 0.1,
                                          ),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: context.primary.withValues(
                                              alpha: 0.05,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onChanged: _filterDoctors,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search specialists, clinics...',
                                          hintStyle: TextStyle(
                                            color: context.textTertiary,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          prefixIcon: Icon(
                                            Icons.search_rounded,
                                            color: context.primary,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 20,
                                                vertical: 18,
                                              ),
                                        ),
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(delay: 200.ms, duration: 500.ms)
                                    .slideY(begin: 0.1, end: 0),
                          ),
                        ),

                        // Carousel for "Featured"
                        if (_allDoctors.isNotEmpty &&
                            _searchController.text.isEmpty)
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Featured Experts',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        'See All',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: context.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                CarouselSlider(
                                  options: CarouselOptions(
                                    height: 200,
                                    enlargeCenterPage: true,
                                    enableInfiniteScroll:
                                        _allDoctors.length > 1,
                                    viewportFraction: 0.82,
                                    autoPlay: true,
                                    autoPlayInterval: const Duration(
                                      seconds: 5,
                                    ),
                                  ),
                                  items: _allDoctors.take(5).map((doctor) {
                                    return _FeaturedDoctorCard(
                                      doctor: doctor,
                                      type: _consultationType,
                                      latitude: _latitude,
                                      longitude: _longitude,
                                      exactAddress: _exactAddress,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 32),
                              ],
                            ).animate().fadeIn(delay: 400.ms, duration: 600.ms),
                          ),

                        // List Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _searchController.text.isEmpty
                                  ? 'Available Specialists'
                                  : 'Search Results',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        if (_filteredDoctors.isEmpty)
                          const SliverFillRemaining(
                            child: Center(
                              child: Text(
                                'No doctors found for this criteria.',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(24),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                return _DoctorListTile(
                                      doctor: _filteredDoctors[index],
                                      type: _consultationType,
                                      latitude: _latitude,
                                      longitude: _longitude,
                                      exactAddress: _exactAddress,
                                    )
                                    .animate()
                                    .fadeIn(delay: (100 * (index % 5)).ms)
                                    .slideX(begin: 0.1, end: 0);
                              }, childCount: _filteredDoctors.length),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FeaturedDoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  final String? type;
  final double? latitude;
  final double? longitude;
  final String? exactAddress;

  const _FeaturedDoctorCard({
    required this.doctor,
    this.type,
    this.latitude,
    this.longitude,
    this.exactAddress,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.primary;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Decorative circles (HomeScreen style)
            Positioned(
              right: -20,
              top: -20,
              child: _buildDecorativeCircle(color, 100, 0.1),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: _buildDecorativeCircle(color, 120, 0.08),
            ),

            LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      width: constraints.maxWidth - 40,
                      height: constraints.maxHeight - 40,
                      child: Row(
                        children: [
                          _buildImage(),
                          const SizedBox(width: 20),
                          Expanded(child: _buildInfo(context)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),

            // Tap Area
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pushNamed(
                  context,
                  '/doctor-detail',
                  arguments: {
                    'doctorId': doctor.id,
                    'isFeatured': true,
                    'type': type,
                    'latitude': latitude,
                    'longitude': longitude,
                    'exactAddress': exactAddress,
                  },
                ),
              ),
            ),
          ],
        ),
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

  Widget _buildImage() {
    return Hero(
      tag: 'doctor_img_${doctor.id}_featured', // Unique tag for carousel
      child: Container(
        width: 100,
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          image: doctor.photoUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(doctor.photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
          color: AppColors.white,
        ),
        child: doctor.photoUrl.isEmpty
            ? const Icon(Icons.person_rounded, size: 50, color: AppColors.grey)
            : null,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final color = context.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            doctor.degree.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Dr. ${doctor.fullName}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            height: 1.1,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          doctor.specialty,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStat(Icons.star_rounded, '${doctor.rating}', Colors.amber),
            const SizedBox(width: 16),
            _buildStat(
              Icons.work_rounded,
              '${doctor.experienceYears}y+',
              color,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStat(IconData icon, String label, Color iconColor) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _DoctorListTile extends StatelessWidget {
  final DoctorModel doctor;
  final String? type;
  final double? latitude;
  final double? longitude;
  final String? exactAddress;

  const _DoctorListTile({
    required this.doctor,
    this.type,
    this.latitude,
    this.longitude,
    this.exactAddress,
  });

  @override
  Widget build(BuildContext context) {
    final color = context.primary;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.05), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => Navigator.pushNamed(
            context,
            '/doctor-detail',
            arguments: {
              'doctorId': doctor.id,
              'type': type,
              'latitude': latitude,
              'longitude': longitude,
              'exactAddress': exactAddress,
            },
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'doctor_img_${doctor.id}',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      image: doctor.photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(doctor.photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: doctor.photoUrl.isEmpty
                        ? Icon(
                            Icons.person_outline_rounded,
                            color: color,
                            size: 40,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Dr. ${doctor.fullName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                letterSpacing: -0.5,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: color.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              doctor.degree,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.specialty,
                        style: TextStyle(
                          fontSize: 14,
                          color: context.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildStatBadge(
                              Icons.star_rounded,
                              '${doctor.rating}',
                              Colors.amber,
                            ),
                            const SizedBox(width: 12),
                            _buildStatBadge(
                              Icons.work_history_rounded,
                              '${doctor.experienceYears}y Exp',
                              color,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.primary.withValues(alpha: 0.05),
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
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String label, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
