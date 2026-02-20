import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/extensions/theme_extension.dart';

class InPersonLocationScreen extends StatefulWidget {
  const InPersonLocationScreen({super.key});

  @override
  State<InPersonLocationScreen> createState() => _InPersonLocationScreenState();
}

class _InPersonLocationScreenState extends State<InPersonLocationScreen> {
  String? _selectedCity;
  bool _isLoading = false;
  bool _isCheckingPermission = false;

  final List<String> _availableCities = ['Mumbai'];
  final List<String> _allCities = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Ahmedabad',
    'Chennai',
    'Kolkata',
    'Pune',
  ];

  Future<void> _handleLocationDetection() async {
    setState(() => _isCheckingPermission = true);

    final status = await Permission.location.request();

    if (status.isGranted) {
      setState(() => _isLoading = true);
      // Simulate location detection
      await Future.delayed(const Duration(milliseconds: 1500));
      setState(() {
        _selectedCity = 'Mumbai'; // Defaulting to Mumbai for demo purposes
        _isLoading = false;
        _isCheckingPermission = false;
      });
    } else {
      setState(() => _isCheckingPermission = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Location permission is required to detect your city.',
            ),
          ),
        );
      }
    }
  }

  void _handleCitySelection(String city) {
    setState(() => _selectedCity = city);
  }

  void _onContinue() {
    if (_selectedCity == null) return;

    if (_availableCities.contains(_selectedCity)) {
      Navigator.pushNamed(
        context,
        '/doctor-browse',
        arguments: {'type': 'inPerson', 'city': _selectedCity},
      );
    } else {
      _showComingSoonBottomDialog();
    }
  }

  void _showComingSoonBottomDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_rounded,
                color: context.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Coming Soon to $_selectedCity',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'In-person consultations are currently only available in Mumbai. We are expanding rapidly!',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'I Understand',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Decor
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: context.surface,
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Where are you\nlocated?',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: -1,
                    ),
                  ).animate().fadeIn().slideX(begin: -0.2),
                  const SizedBox(height: 12),
                  Text(
                    'We need your location to find available doctors for home visits.',
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 16,
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 40),

                  // Auto Detect Button
                  InkWell(
                    onTap: _isCheckingPermission
                        ? null
                        : _handleLocationDetection,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: context.primary.withValues(alpha: 0.1),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.surface,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: _isCheckingPermission || _isLoading
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        context.primary,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.my_location_rounded,
                                    color: context.primary,
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Detect Current Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Fastest way to find service',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: context.onSurface.withValues(
                                      alpha: 0.7,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(),

                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR SELECT CITY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // City Grid
                  Expanded(
                    child: GridView.builder(
                      itemCount: _allCities.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemBuilder: (context, index) {
                        final city = _allCities[index];
                        final isSelected = _selectedCity == city;
                        final isAvailable = _availableCities.contains(city);

                        return InkWell(
                          onTap: () => _handleCitySelection(city),
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? context.primary
                                  : context.surface,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: isSelected
                                    ? context.primary
                                    : context.dividerColor.withValues(
                                        alpha: 0.1,
                                      ),
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: context.primary.withValues(
                                          alpha: 0.2,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    city,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.white
                                          : context.onSurface,
                                    ),
                                  ),
                                  if (isAvailable && !isSelected) ...[
                                    const SizedBox(width: 4),
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _selectedCity != null ? _onContinue : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: context.dividerColor
                            .withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: _selectedCity != null ? 4 : 0,
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 400.ms),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
