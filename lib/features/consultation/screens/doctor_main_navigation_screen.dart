import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import 'doctor_home_screen.dart';
import 'doctor_patients_screen.dart';
import 'doctor_slot_management_screen.dart';
import 'doctor_profile_screen.dart';
import '../../../core/services/auth_service.dart';

class DoctorMainNavigationScreen extends StatefulWidget {
  const DoctorMainNavigationScreen({super.key});

  @override
  State<DoctorMainNavigationScreen> createState() =>
      _DoctorMainNavigationScreenState();
}

class _DoctorMainNavigationScreenState
    extends State<DoctorMainNavigationScreen> {
  int _selectedIndex = 0;
  final _authService = AuthService();

  final List<Widget> _screens = [
    const DoctorHomeScreen(),
    const DoctorPatientsScreen(),
    const DoctorSlotManagementScreen(),
    const DoctorProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 800) {
          return _buildWebLayout();
        } else {
          return _buildMobileLayout();
        }
      },
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 30,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 1,
                color: context.dividerColor.withValues(alpha: 0.05),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.dashboard_rounded, 'Home'),
                    _buildNavItem(1, Icons.people_rounded, 'Patients'),
                    _buildNavItem(2, Icons.calendar_month_rounded, 'Slots'),
                    _buildNavItem(3, Icons.person_rounded, 'Profile'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? context.primary : context.textSecondary;

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      behavior: HitTestBehavior.opaque,
      child:
          Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? context.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              )
              .animate(target: isSelected ? 1 : 0)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
    );
  }

  Widget _buildWebLayout() {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: context.surface.withValues(alpha: 0.8),
              border: Border(
                right: BorderSide(
                  color: context.dividerColor.withValues(alpha: 0.05),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 30,
                  offset: const Offset(10, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 48),
                  // Premium Visiaxx Logo - Balanced for clarity
                  Container(
                    width: 170,
                    height: 68,
                    decoration: BoxDecoration(
                      color: context.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: context.primary.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/icons/app_logo.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.remove_red_eye_rounded,
                          color: context.primary,
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'VISIAXX',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      letterSpacing: 4.5,
                      color: context.primary,
                    ),
                  ),
                  Text(
                    'DOCTOR PORTAL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: context.textSecondary.withValues(alpha: 0.5),
                    ),
                  ),
                  const SizedBox(height: 48),
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
                            'My Patients',
                          ),
                          _buildWebNavItem(
                            2,
                            Icons.calendar_month_rounded,
                            'Availability',
                          ),
                          _buildWebNavItem(
                            3,
                            Icons.person_rounded,
                            'Profile Settings',
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildWebLogoutButton(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          Expanded(child: ClipRect(child: _screens[_selectedIndex])),
        ],
      ),
    );
  }

  Widget _buildWebNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    final color = isSelected ? context.primary : context.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => setState(() => _selectedIndex = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 16),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.primary,
                      shape: BoxShape.circle,
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

  Widget _buildWebLogoutButton(BuildContext context) {
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
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 16),
                const Text(
                  'Logout',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
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
