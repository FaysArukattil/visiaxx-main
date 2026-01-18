import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:visiaxx/core/constants/app_colors.dart';
import 'package:visiaxx/core/services/auth_service.dart';
import 'package:visiaxx/data/models/user_model.dart';
import 'package:visiaxx/core/widgets/eye_loader.dart';
import 'package:visiaxx/features/home/screens/home_screen.dart';
import 'package:visiaxx/features/eye_exercises/screens/eye_exercise_reels_screen.dart';
import 'package:visiaxx/features/home/screens/profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
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
      debugPrint('[MainNavigation] ❌ Error loading user data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<Widget> get _screens => [
    const HomeScreen(),
    const EyeExerciseReelsScreen(),
    _user != null
        ? ProfileScreen(user: _user!)
        : const Center(child: EyeLoader.fullScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: EyeLoader.fullScreen()));
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // PageView with screens
          PageView(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) {
              setState(() => _currentIndex = i);
            },
            children: _screens,
          ),

          // Glassmorphic bottom navigation bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.black.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final totalWidth = constraints.maxWidth;
                          const itemCount = 3;
                          final itemWidth = totalWidth / itemCount;
                          final indicatorWidth = itemWidth - 12;

                          final animatedLeft =
                              (_dragging
                                  ? (_dragIndicatorPage.clamp(
                                          0,
                                          itemCount - 1,
                                        ) *
                                        itemWidth)
                                  : (_page.clamp(0, itemCount - 1) *
                                        itemWidth)) +
                              6;

                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onPanStart: (details) {
                              _dragAccumX = 0;
                              setState(() {
                                _dragging = true;
                                _dragStartPage = _page;
                                _dragIndicatorPage = _page;
                              });
                            },
                            onPanUpdate: (details) {
                              _dragAccumX += details.delta.dx;
                              final deltaPages = _dragAccumX / itemWidth;
                              final double newPage =
                                  (_dragStartPage + deltaPages).clamp(
                                    0.0,
                                    (itemCount - 1).toDouble(),
                                  );
                              setState(() {
                                _dragIndicatorPage = newPage;
                              });
                              if (_pageController.hasClients &&
                                  _pageController.position.haveDimensions) {
                                final w =
                                    _pageController.position.viewportDimension;
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
                            child: SizedBox(
                              height: 56,
                              child: Stack(
                                children: [
                                  // Animated pill indicator behind icons
                                  Positioned(
                                    left: animatedLeft,
                                    top: 4,
                                    width: indicatorWidth,
                                    height: 48,
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(16),
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.primary.withValues(
                                              alpha: 0.35,
                                            ),
                                            AppColors.primaryLight.withValues(
                                              alpha: 0.28,
                                            ),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          color: AppColors.white.withValues(
                                            alpha: 0.3,
                                          ),
                                          width: 1,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary.withValues(
                                              alpha: 0.2,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Icons row (equal width slots, strictly centered)
                                  Row(
                                    children: [
                                      SizedBox(
                                        width: itemWidth,
                                        child: Center(
                                          child: _NavIcon(
                                            icon: Icons.home_rounded,
                                            outline: Icons.home_outlined,

                                            selected: (_page.round() == 0),
                                            onTap: () => _goTo(0),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: Center(
                                          child: _NavIcon(
                                            icon: Icons.play_circle_rounded,
                                            outline: Icons
                                                .play_circle_outline_rounded,
                                            selected: (_page.round() == 1),
                                            onTap: () => _goTo(1),
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: itemWidth,
                                        child: Center(
                                          child: _NavIcon(
                                            icon: Icons.person_rounded,
                                            outline:
                                                Icons.person_outline_rounded,
                                            selected: (_page.round() == 2),
                                            onTap: () => _goTo(2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final IconData outline;
  final bool selected;
  final VoidCallback onTap;

  const _NavIcon({
    required this.icon,
    required this.outline,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? icon : outline,
                key: ValueKey<bool>(selected),
                size: selected ? 26 : 23,
                color: selected
                    ? AppColors.white
                    : AppColors.white.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 2),
          ],
        ),
      ),
    );
  }
}
