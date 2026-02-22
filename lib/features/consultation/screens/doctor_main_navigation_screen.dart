import 'package:flutter/material.dart';
import 'package:visiaxx/data/models/user_model.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/eye_loader.dart';
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
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (_authService.currentUserId != null) {
        final user = await _authService.getUserData(
          _authService.currentUserId!,
        );
        if (mounted && user != null) {
          setState(() {
            _user = user;
            _isLoading = false;
          });
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('[DoctorMainNavigation] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
      bottomNavigationBar: _buildPremiumBottomNavBar(),
    );
  }

  Widget _buildPremiumBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            context.primary.withValues(alpha: 0.08),
            context.primary.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: context.primary.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: context.primary.withValues(alpha: 0.05),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: SafeArea(
          child: SizedBox(
            height: 68,
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
                    final double newPage = (_dragStartPage + deltaPages).clamp(
                      0.0,
                      (itemCount - 1).toDouble(),
                    );
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
                              (currentPage.clamp(0, itemCount - 1) * itemWidth),
                          top: 0,
                          bottom: 0,
                          width: itemWidth,
                          child: Container(
                            decoration: BoxDecoration(
                              color: context.primary.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: context.primary.withValues(alpha: 0.3),
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
    );
  }

  Widget _buildNavIcon({
    required IconData icon,
    required int index,
    required double itemWidth,
    bool isProfile = false,
  }) {
    final isSelected = (_currentIndex == index);
    final primaryColor = context.primary;
    final onSurfaceColor = context.onSurface;

    return SizedBox(
      width: itemWidth,
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
                    borderRadius: BorderRadius.circular(12),
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
                          ? AppColors.textOnPrimary
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
                        ? primaryColor.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    size: 26,
                    color: isSelected
                        ? primaryColor
                        : onSurfaceColor.withValues(alpha: 0.45),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Premium Web Sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: context.surface.withValues(alpha: 0.9),
              border: Border(
                right: BorderSide(
                  color: context.dividerColor.withValues(alpha: 0.05),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 40,
                  offset: const Offset(10, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Branding Section
                  _buildWebBranding(),
                  const SizedBox(height: 48),
                  // Navigation Menu
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          _buildWebNavItem(
                            0,
                            Icons.dashboard_rounded,
                            'Dashboard',
                          ),
                          _buildWebNavItem(
                            1,
                            Icons.people_rounded,
                            'Patient Records',
                          ),
                          _buildWebNavItem(
                            2,
                            Icons.calendar_month_rounded,
                            'Slot Management',
                          ),
                          _buildWebNavItem(
                            3,
                            Icons.person_rounded,
                            'My Profile',
                            isProfile: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom Section
                  _buildWebLogoutButton(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          // Main Content
          Expanded(
            child: Container(
              color: context.scaffoldBackground,
              child: ClipRect(child: _screens[_currentIndex]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebBranding() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [context.primary, context.primary.withValues(alpha: 0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: context.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Image.asset(
              'assets/images/icons/app_icon.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'VisiAxx',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 24,
            letterSpacing: -0.5,
            color: context.primary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: context.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'DOCTOR PORTAL',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 9,
              letterSpacing: 2,
              color: context.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWebNavItem(
    int index,
    IconData icon,
    String label, {
    bool isProfile = false,
  }) {
    final isSelected = _currentIndex == index;
    final primaryColor = context.primary;
    final color = isSelected ? primaryColor : context.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _currentIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryColor.withValues(alpha: 0.12),
                        primaryColor.withValues(alpha: 0.04),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(20),
              border: isSelected
                  ? Border.all(
                      color: primaryColor.withValues(alpha: 0.15),
                      width: 1.5,
                    )
                  : Border.all(color: Colors.transparent, width: 1.5),
            ),
            child: Row(
              children: [
                if (isProfile && _user != null)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? primaryColor
                          : context.textSecondary.withValues(alpha: 0.1),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _user!.firstName.substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: isSelected
                            ? AppColors.white
                            : context.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  )
                else
                  Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    letterSpacing: 0.3,
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
                          blurRadius: 8,
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

  Widget _buildWebLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            final nav = Navigator.of(context);
            await _authService.signOut();
            nav.pushReplacementNamed('/login');
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
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
                  'Sign Out',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
