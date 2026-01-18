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

class _MainNavigationScreenState extends State<MainNavigationScreen> {
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

  bool get _isDarkBackground => _currentIndex == 1;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: EyeLoader.fullScreen()));
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.background,
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (i) {
          setState(() => _currentIndex = i);
        },
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          height: 70,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: _isDarkBackground
                        ? [
                            AppColors.white.withOpacity(0.18),
                            AppColors.white.withOpacity(0.12),
                          ]
                        : [
                            const Color(0xFF1C1C1E).withOpacity(0.75),
                            const Color(0xFF1C1C1E).withOpacity(0.85),
                          ],
                  ),
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(
                    color: _isDarkBackground
                        ? AppColors.white.withOpacity(0.25)
                        : AppColors.white.withOpacity(0.12),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.2),
                      blurRadius: 30,
                      spreadRadius: -5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    const itemCount = 3;
                    final itemWidth = totalWidth / itemCount;

                    final animatedLeft =
                        (_dragging
                            ? (_dragIndicatorPage.clamp(0, itemCount - 1) *
                                  itemWidth)
                            : (_page.clamp(0, itemCount - 1) * itemWidth)) +
                        12;

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
                          // Selection indicator
                          Positioned(
                            left: animatedLeft,
                            top: 10,
                            width: itemWidth - 24,
                            height: 50,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(25),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.white.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 15,
                                    spreadRadius: -2,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
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
                                  icon: Icons.play_circle_rounded,
                                  index: 1,
                                ),
                              ),
                              SizedBox(
                                width: itemWidth,
                                child: _buildProfileIcon(index: 2),
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
      ),
    );
  }

  Widget _buildNavIcon({required IconData icon, required int index}) {
    final isSelected = (_page.round() == index);

    return InkWell(
      onTap: () => _goTo(index),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            child: Icon(
              icon,
              size: isSelected ? 28 : 25,
              color: isSelected
                  ? AppColors.primary
                  : (_isDarkBackground
                        ? AppColors.white.withOpacity(0.6)
                        : AppColors.white.withOpacity(0.5)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileIcon({required int index}) {
    final isSelected = (_page.round() == index);

    return InkWell(
      onTap: () => _goTo(index),
      borderRadius: BorderRadius.circular(25),
      child: Container(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: _user?.firstName != null
              ? AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  width: isSelected ? 32 : 28,
                  height: isSelected ? 32 : 28,
                  decoration: ShapeDecoration(
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(isSelected ? 22 : 20),
                      side: BorderSide(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.white.withOpacity(0.4),
                        width: isSelected ? 2.5 : 2,
                      ),
                    ),
                    image: DecorationImage(
                      image: NetworkImage(_user!.firstName!),
                      fit: BoxFit.cover,
                    ),
                    shadows: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: isSelected ? 28 : 25,
                  color: isSelected
                      ? AppColors.primary
                      : (_isDarkBackground
                            ? AppColors.white.withOpacity(0.6)
                            : AppColors.white.withOpacity(0.5)),
                ),
        ),
      ),
    );
  }

  void _goTo(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}
