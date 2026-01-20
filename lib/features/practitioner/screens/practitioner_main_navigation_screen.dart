import 'package:flutter/material.dart';
import 'package:visiaxx/core/constants/app_colors.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'package:visiaxx/data/models/user_model.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'package:visiaxx/features/practitioner/screens/practitioner_dashboard_screen.dart';
import 'package:visiaxx/features/practitioner/screens/practitioner_home_screen.dart';
import 'package:visiaxx/features/home/screens/profile_screen.dart';

class PractitionerMainNavigationScreen extends StatefulWidget {
  const PractitionerMainNavigationScreen({super.key});

  @override
  State<PractitionerMainNavigationScreen> createState() =>
      _PractitionerMainNavigationScreenState();
}

class _PractitionerMainNavigationScreenState
    extends State<PractitionerMainNavigationScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  double _page = 0;
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
    _pageController.addListener(() {
      final p = _pageController.page ?? _currentIndex.toDouble();
      if (p != _page) setState(() => _page = p);
    });
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
      debugPrint('[PractitionerMainNavigation] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> get _screens => [
    const PractitionerHomeScreen(),
    const PractitionerDashboardScreen(),
    _user != null
        ? ProfileScreen(user: _user!)
        : const Center(child: EyeLoader.fullScreen()),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) => setState(() => _currentIndex = i),
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary.withOpacity(0.08),
              AppColors.primaryLight.withOpacity(0.05),
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.15),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
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
                  const itemCount = 3;
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
                            top: 0,
                            bottom: 0,
                            width: itemWidth,
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.primary.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),

                        // Profile gradient rectangle
                        if (!_dragging && _currentIndex == 2)
                          Positioned(
                            left: (2 * itemWidth) + (itemWidth / 2) - 24,
                            top: 10,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: 1.0,
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      AppColors.primary,
                                      AppColors.primary.withOpacity(0.85),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(
                                        0.35,
                                      ),
                                      blurRadius: 16,
                                      spreadRadius: 0,
                                      offset: const Offset(0, 4),
                                    ),
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.2),
                                      blurRadius: 8,
                                      spreadRadius: -2,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        // Icons
                        Row(
                          children: [
                            SizedBox(
                              width: itemWidth,
                              child: _buildNavIcon(
                                icon: Icons.home_rounded,
                                index: 0,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildNavIcon(
                                icon: Icons.dashboard_rounded,
                                index: 1,
                              ),
                            ),
                            SizedBox(
                              width: itemWidth,
                              child: _buildNavIcon(
                                icon: Icons.account_circle_rounded,
                                index: 2,
                                isProfile: true,
                              ),
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
    bool isProfile = false,
  }) {
    final isSelected = (_currentIndex == index);

    return InkWell(
      onTap: () => _goTo(index),
      borderRadius: BorderRadius.circular(16),
      splashColor: AppColors.primary.withOpacity(0.1),
      highlightColor: AppColors.primary.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: isProfile && _user?.firstName != null
              ? AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOutCubic,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.white
                        : AppColors.textSecondary.withOpacity(0.5),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  child: Text(_user!.firstName.substring(0, 1).toUpperCase()),
                )
              : Icon(
                  icon,
                  key: ValueKey('icon_${index}_$isSelected'),
                  size: 28,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withOpacity(0.5),
                ),
        ),
      ),
    );
  }
}
