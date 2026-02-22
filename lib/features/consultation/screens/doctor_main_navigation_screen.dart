import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:visiaxx/data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/consultation_service.dart'; // Added
import '../../../core/widgets/eye_loader.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../data/models/doctor_model.dart'; // Added
import 'doctor_home_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_slot_management_screen.dart';
import 'doctor_profile_screen.dart';

class DoctorMainNavigationScreen extends StatefulWidget {
  const DoctorMainNavigationScreen({super.key});

  @override
  State<DoctorMainNavigationScreen> createState() =>
      _DoctorMainNavigationScreenState();
}

class _DoctorMainNavigationScreenState
    extends State<DoctorMainNavigationScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  bool _dragging = false;
  double _dragIndicatorPage = 0;
  double _dragStartPage = 0;
  double _dragAccumX = 0;

  final _authService = AuthService();
  final _consultationService = ConsultationService();
  UserModel? _user;
  DoctorModel? _doctor;
  bool _isLoading = true;
  int _pendingCount = 0;
  StreamSubscription? _pendingSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);

    // Proactively check cache
    final cachedUser = _authService.cachedUser;
    if (cachedUser != null) {
      _user = cachedUser;
      _isLoading = false;
    }
    _loadData(); // Changed to _loadData
  }

  Future<void> _loadData() async {
    // Renamed from _loadUserData to _loadData
    try {
      final user = _user ?? await _authService.getCurrentUserProfile();
      if (user != null) {
        final doctor = await _consultationService.getDoctorById(
          user.id,
        ); // Fetch DoctorModel
        if (mounted) {
          setState(() {
            _user = user;
            _doctor = doctor; // Set _doctor
            _isLoading = false;
          });
          _startPendingSubscription(user.id);
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('[DoctorMainNavigation] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startPendingSubscription(String userId) {
    _pendingSubscription?.cancel();
    _pendingSubscription = _consultationService
        .getPendingBookingsStream(userId)
        .listen((bookings) {
          if (mounted) {
            setState(() {
              _pendingCount = bookings.length;
            });
          }
        });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pendingSubscription?.cancel();
    super.dispose();
  }

  List<Widget> get _screens => [
    const DoctorHomeScreen(),
    const DoctorPatientsScreen(),
    const DoctorSlotManagementScreen(),
    const DoctorProfileScreen(),
  ];

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: EyeLoader.fullScreen()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 900) {
          return _buildWebLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: _buildPremiumBottomNavBar(isWeb: false),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      body: Row(
        children: [
          // Premium Glass Sidebar
          _buildWebSidebar(),

          // Main Content
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (i) => setState(() => _currentIndex = i),
              children: _screens,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.4),
        border: Border(
          right: BorderSide(
            color: context.primary.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: context.primary.withValues(alpha: 0.03),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // Branding
                    _buildSidebarBranding(),
                    const SizedBox(height: 48),

                    // Nav Items
                    Expanded(
                      child: Column(
                        children: [
                          _buildWebNavItem(
                            0,
                            Icons.dashboard_rounded,
                            'Dashboard',
                            badgeCount: _pendingCount,
                          ),
                          _buildWebNavItem(1, Icons.people_rounded, 'Patients'),
                          _buildWebNavItem(
                            2,
                            Icons.calendar_month_rounded,
                            'Schedule',
                          ),
                          _buildWebNavItem(
                            3,
                            Icons.person_rounded,
                            'Profile',
                            isProfile: true,
                          ),
                        ],
                      ),
                    ),

                    // Logout
                    _buildSidebarLogout(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarBranding() {
    return Center(
      child: Container(
        width: 170,
        height: 70,
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            'assets/images/icons/app_logo.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) =>
                Icon(Icons.remove_red_eye, color: context.primary, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildWebNavItem(
    int index,
    IconData icon,
    String label, {
    bool isProfile = false,
    int badgeCount = 0,
  }) {
    final isSelected = _currentIndex == index;
    final primaryColor = context.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goTo(index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.2)
                    : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (isProfile && _user != null)
                  Container(
                    width: 28, // Changed from 70
                    height: 28, // Changed from 70
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isSelected // Kept original logic for color
                          ? primaryColor
                          : primaryColor.withValues(alpha: 0.1),
                      image:
                          _doctor?.photoUrl != null &&
                              _doctor!.photoUrl.isNotEmpty
                          ? DecorationImage(
                              image: NetworkImage(_doctor!.photoUrl),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child:
                        (_doctor?.photoUrl == null || _doctor!.photoUrl.isEmpty)
                        ? Center(
                            child: Text(
                              _user?.firstName.isNotEmpty ==
                                      true // Changed from fullName to firstName
                                  ? _user!.firstName
                                        .substring(0, 1)
                                        .toUpperCase() // Kept original logic for initial
                                  : 'D',
                              style: TextStyle(
                                fontSize: 12, // Changed from 24
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? AppColors.white
                                    : primaryColor, // Kept original logic for color
                              ),
                            ),
                          )
                        : null,
                  )
                else
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: isSelected
                            ? primaryColor
                            : context.onSurface.withValues(alpha: 0.45),
                      ),
                      if (!isProfile && badgeCount > 0)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected
                        ? primaryColor
                        : context.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primaryColor.withValues(alpha: 0.4),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarLogout() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final confirm = await UIUtils.showLogoutConfirmation(context);
          if (confirm == true) {
            final nav = Navigator.of(context);
            await _authService.signOut();
            nav.pushReplacementNamed('/login');
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.15),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 22,
              ),
              const SizedBox(width: 16),
              const Text(
                'SIGN OUT',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumBottomNavBar({required bool isWeb}) {
    final borderRadius = isWeb
        ? BorderRadius.circular(28)
        : const BorderRadius.vertical(top: Radius.circular(24));

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                context.primary.withValues(alpha: 0.12),
                context.primary.withValues(alpha: 0.04),
              ],
            ),
            borderRadius: borderRadius,
            border: Border.all(
              color: context.primary.withValues(alpha: 0.2),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                spreadRadius: 0,
                offset: Offset(0, isWeb ? 8 : -4),
              ),
            ],
          ),
          child: SafeArea(
            bottom: !isWeb,
            top: false,
            child: SizedBox(
              height: 72,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  const itemCount = 4;
                  final itemWidth = totalWidth / itemCount;

                  final currentPage = _dragging
                      ? _dragIndicatorPage
                      : _currentIndex.toDouble();

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onPanStart: (details) {
                      _dragAccumX = 0;
                      setState(() {
                        _dragging = true;
                        _dragStartPage = _currentIndex.toDouble();
                        _dragIndicatorPage = _currentIndex.toDouble();
                      });
                    },
                    onPanUpdate: (details) {
                      _dragAccumX += details.delta.dx;
                      final deltaPages = _dragAccumX / itemWidth;
                      final double newPage = (_dragStartPage + deltaPages)
                          .clamp(0.0, (itemCount - 1).toDouble());
                      setState(() {
                        _dragIndicatorPage = newPage;
                      });
                      if (_pageController.hasClients &&
                          _pageController.position.haveDimensions) {
                        final w = _pageController.position.viewportDimension;
                        _pageController.position.jumpTo(newPage * w);
                      }
                    },
                    onPanEnd: (details) {
                      final target = _dragIndicatorPage.round();
                      setState(() {
                        _dragging = false;
                      });
                      _goTo(target);
                    },
                    child: Stack(
                      children: [
                        // Drag indicator
                        if (_dragging)
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 100),
                            curve: Curves.easeOut,
                            left:
                                (currentPage.clamp(0, itemCount - 1) *
                                itemWidth),
                            top: 8,
                            bottom: 8,
                            width: itemWidth,
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 8),
                              decoration: BoxDecoration(
                                color: context.primary.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: context.primary.withValues(alpha: 0.4),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                        // Icons
                        Row(
                          children: [
                            _buildNavIcon(
                              icon: Icons.dashboard_rounded,
                              index: 0,
                              itemWidth: itemWidth,
                              badgeCount: _pendingCount,
                            ),
                            _buildNavIcon(
                              icon: Icons.people_rounded,
                              index: 1,
                              itemWidth: itemWidth,
                            ),
                            _buildNavIcon(
                              icon: Icons.calendar_month_rounded,
                              index: 2,
                              itemWidth: itemWidth,
                            ),
                            _buildNavIcon(
                              icon: Icons.person_rounded,
                              index: 3,
                              itemWidth: itemWidth,
                              isProfile: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon({
    required IconData icon,
    required int index,
    required double itemWidth,
    bool isProfile = false,
    int badgeCount = 0,
  }) {
    final isSelected = (_currentIndex == index);
    final primaryColor = context.primary;
    final onSurfaceColor = context.onSurface;

    return SizedBox(
      width: itemWidth,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _goTo(index),
          borderRadius: BorderRadius.circular(16),
          splashColor: primaryColor.withValues(alpha: 0.1),
          highlightColor: primaryColor.withValues(alpha: 0.05),
          child: Center(
            child: isProfile && _user?.firstName != null
                ? Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: isSelected
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                primaryColor,
                                primaryColor.withValues(alpha: 0.85),
                              ],
                            )
                          : null,
                      border: isSelected
                          ? null
                          : Border.all(
                              color: onSurfaceColor.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: primaryColor.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _user!.firstName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.white
                            : onSurfaceColor.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                : AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? primaryColor.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          icon,
                          size: 26,
                          color: isSelected
                              ? primaryColor
                              : onSurfaceColor.withValues(alpha: 0.4),
                        ),
                        if (badgeCount > 0)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: context.surface,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
