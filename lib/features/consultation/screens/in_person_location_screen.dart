import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/snackbar_utils.dart';

class InPersonLocationScreen extends StatefulWidget {
  final bool pickerMode;
  const InPersonLocationScreen({super.key, this.pickerMode = false});

  @override
  State<InPersonLocationScreen> createState() => _InPersonLocationScreenState();
}

class _InPersonLocationScreenState extends State<InPersonLocationScreen> {
  String? _selectedCity;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;
  bool _isLoading = false;
  bool _isCheckingPermission = false;

  final List<String> _availableCities = ['Mumbai'];

  Future<void> _handleLocationDetection() async {
    setState(() => _isCheckingPermission = true);

    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          SnackbarUtils.showError(context, 'Location services are disabled.');
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            SnackbarUtils.showError(context, 'Location permissions are denied');
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showPermissionDeniedDialog();
        }
        return;
      }

      setState(() {
        _isLoading = true;
        _isCheckingPermission = false;
      });

      // Added timeLimit to prevent hanging indefinitely
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.medium, // Changed to medium for faster results
        timeLimit: const Duration(seconds: 10),
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String city = place.locality ?? place.subAdministrativeArea ?? '';
        String address = [
          place.street,
          place.subLocality,
          place.locality,
          place.postalCode,
        ].where((e) => e != null && e.isNotEmpty).join(", ");

        if (mounted) {
          setState(() {
            _selectedCity = city;
            _latitude = position.latitude;
            _longitude = position.longitude;
            _exactAddress = address;
          });

          if (!_availableCities.contains(city)) {
            _showComingSoonBottomDialog();
          }
        }
      } else {
        throw Exception("Could not find address details for this location.");
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error detecting location: $e';
        if (e.toString().contains('timeLimit')) {
          errorMessage =
              'Location detection timed out. Please try again or select manually.';
        }
        SnackbarUtils.showError(context, errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  void _showPermissionDeniedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Permission'),
        content: const Text(
          'Location access is required to find doctors near you. Please enable it in settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              openAppSettings();
              Navigator.pop(context);
            },
            child: const Text('Settings'),
          ),
        ],
      ),
    );
  }

  void _handleCitySelection(String city) {
    setState(() => _selectedCity = city);
  }

  void _onContinue() {
    if (_selectedCity == null) return;

    if (_availableCities.contains(_selectedCity)) {
      if (widget.pickerMode) {
        Navigator.pop(context, {
          'latitude': _latitude,
          'longitude': _longitude,
          'exactAddress': _exactAddress,
        });
        return;
      }
      Navigator.pushNamed(
        context,
        '/doctor-browse',
        arguments: {
          'type': 'inPerson',
          'city': _selectedCity,
          'latitude': _latitude,
          'longitude': _longitude,
          'exactAddress': _exactAddress,
        },
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
    if (widget.pickerMode) {
      return Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHandle(),
            _buildSheetHeaderPicker(context),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAutoDetectButton(context),
                  const SizedBox(height: 24),
                  _buildDivider(context),
                  const SizedBox(height: 24),
                  SizedBox(height: 180, child: _buildCityGrid(context)),
                  const SizedBox(height: 24),
                  _buildContinueButton(context),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: OrientationBuilder(
        builder: (context, orientation) {
          final isLandscape = orientation == Orientation.landscape;
          return Stack(
            children: [
              // Background Decor
              Positioned(
                top: isLandscape ? -200 : -100,
                right: isLandscape ? -100 : -50,
                child: Container(
                  width: isLandscape ? 500 : 300,
                  height: isLandscape ? 500 : 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.primary.withValues(alpha: 0.03),
                  ),
                ),
              ),

              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        style: IconButton.styleFrom(
                          backgroundColor: context.surface,
                          padding: const EdgeInsets.all(12),
                          elevation: 2,
                          shadowColor: Colors.black12,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: isLandscape
                            ? _buildLandscapeContent(context)
                            : _buildPortraitContent(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSheetHandle() => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: context.dividerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );

  Widget _buildSheetHeaderPicker(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(28, 0, 20, 20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Location',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              Text(
                'Select or detect your visit address',
                style: TextStyle(
                  fontSize: 12,
                  color: context.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
  );

  Widget _buildPortraitContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        const SizedBox(height: 40),
        _buildAutoDetectButton(context),
        const SizedBox(height: 32),
        _buildDivider(context),
        const SizedBox(height: 24),
        Expanded(child: _buildCityGrid(context)),
        _buildContinueButton(context),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildLandscapeContent(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 32),
                _buildAutoDetectButton(context),
                const SizedBox(height: 24),
                _buildContinueButton(context),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        const SizedBox(width: 48),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              _buildDivider(context),
              const SizedBox(height: 24),
              Expanded(child: _buildCityGrid(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          style: TextStyle(color: context.textSecondary, fontSize: 16),
        ).animate().fadeIn(delay: 100.ms),
      ],
    );
  }

  Widget _buildAutoDetectButton(BuildContext context) {
    return InkWell(
      onTap: _isCheckingPermission || _isLoading
          ? null
          : _handleLocationDetection,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.primary.withValues(alpha: 0.08),
              context.primary.withValues(alpha: 0.03),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: context.primary.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.1),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: _isCheckingPermission || _isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.primary,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.my_location_rounded,
                      color: context.primary,
                      size: 28,
                    ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _exactAddress != null
                        ? 'Location Detected'
                        : 'Detect Current Location',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _exactAddress ?? 'Fastest way to find service',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (_exactAddress != null)
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale();
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR SELECT CITY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: context.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }

  Widget _buildCityGrid(BuildContext context) {
    return GridView.builder(
      itemCount: _availableCities.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemBuilder: (context, index) {
        final city = _availableCities[index];
        final isSelected = _selectedCity == city;
        final isAvailable = _availableCities.contains(city);

        return InkWell(
          onTap: () => _handleCitySelection(city),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: 300.ms,
            decoration: BoxDecoration(
              color: isSelected ? context.primary : context.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.primary
                    : context.dividerColor.withValues(alpha: 0.1),
                width: 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: context.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
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
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected ? Colors.white : context.onSurface,
                    ),
                  ),
                  if (isAvailable && !isSelected) ...[
                    const SizedBox(width: 8),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.greenAccent, blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinueButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _selectedCity != null ? _onContinue : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: context.dividerColor.withValues(alpha: 0.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: _selectedCity != null ? 8 : 0,
          shadowColor: context.primary.withValues(alpha: 0.3),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
    ).animate().fadeIn(delay: 400.ms);
  }
}
