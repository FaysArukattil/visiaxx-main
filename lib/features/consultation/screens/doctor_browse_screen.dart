import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../home/widgets/app_bar_widget.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _consultationType = args?['type'];
    _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    final doctors = await _consultationService.getAllDoctors();

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

    setState(() {
      _allDoctors = filtered;
      _filteredDoctors = filtered;
      _isLoading = false;
    });
  }

  void _filterDoctors(String query) {
    setState(() {
      _filteredDoctors = _allDoctors.where((doctor) {
        final name = doctor.fullName.toLowerCase();
        final specialty = doctor.specialty.toLowerCase();
        return name.contains(query.toLowerCase()) ||
            specialty.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOnline = _consultationType == 'online';

    return Scaffold(
      appBar: AppBarWidget(
        title: isOnline ? 'Online Consultation' : 'In-Person Visit',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDoctors,
              child: CustomScrollView(
                slivers: [
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _filterDoctors,
                        decoration: InputDecoration(
                          hintText: 'Search by specialty or name...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: theme.cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Carousel for "Featured" or all if short list
                  if (_allDoctors.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              'Available Doctors',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: context.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CarouselSlider(
                            options: CarouselOptions(
                              height: 180,
                              enlargeCenterPage: true,
                              enableInfiniteScroll: _allDoctors.length > 1,
                              viewportFraction: 0.85,
                            ),
                            items: _allDoctors.take(5).map((doctor) {
                              return _FeaturedDoctorCard(doctor: doctor);
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),

                  // All Doctors List
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'All Specialists',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  if (_filteredDoctors.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Text('No doctors found for this type.'),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return _DoctorListTile(
                            doctor: _filteredDoctors[index],
                          );
                        }, childCount: _filteredDoctors.length),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _FeaturedDoctorCard extends StatelessWidget {
  final DoctorModel doctor;
  const _FeaturedDoctorCard({required this.doctor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [context.primary, context.primary.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.health_and_safety,
              size: 150,
              color: AppColors.white.withValues(alpha: 0.1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.white.withValues(alpha: 0.2),
                  child: const Icon(
                    Icons.person,
                    size: 40,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.fullName}',
                        style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        doctor.specialty,
                        style: TextStyle(
                          color: AppColors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.rating}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

class _DoctorListTile extends StatelessWidget {
  final DoctorModel doctor;
  const _DoctorListTile({required this.doctor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => Navigator.pushNamed(
          context,
          '/doctor-detail',
          arguments: {'doctorId': doctor.id},
        ),
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.person),
        ),
        title: Text(
          'Dr. ${doctor.fullName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(doctor.specialty),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 12,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  doctor.location,
                  style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                ),
                const Spacer(),
                Text(
                  '${doctor.experienceYears}y exp',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
