import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';

class SlotSelectionScreen extends StatefulWidget {
  const SlotSelectionScreen({super.key});

  @override
  State<SlotSelectionScreen> createState() => _SlotSelectionScreenState();
}

class _SlotSelectionScreenState extends State<SlotSelectionScreen> {
  final _consultationService = ConsultationService();
  DoctorModel? _doctor;
  DateTime _selectedDate = DateTime.now();
  List<TimeSlotModel> _slots = [];
  bool _isLoading = true;
  String? _selectedSlotId;
  double? _latitude;
  double? _longitude;
  String? _exactAddress;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    _latitude = args?['latitude'];
    _longitude = args?['longitude'];
    _exactAddress = args?['exactAddress'];
    if (_doctor != null) {
      _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    // Fetch ALL slots for the date to show booked vs available
    final slots = await _consultationService.getAllSlotsForDate(
      _doctor!.id,
      _selectedDate,
    );
    setState(() {
      _slots = slots;
      _isLoading = false;
      _selectedSlotId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Doctor missing')));
    }

    final theme = Theme.of(context);
    final color = context.primary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Decorative background circles
          Positioned(
            top: -100,
            right: -50,
            child: _buildDecorativeCircle(color, 300, 0.03),
          ),
          Positioned(
            bottom: 150,
            left: -50,
            child: _buildDecorativeCircle(color, 250, 0.02),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.surface,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Appointment Slot',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Column(
                    children: [
                      _buildDatePicker(),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Divider(height: 1),
                      ),
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _slots.isEmpty
                            ? _buildEmptyState()
                            : _buildSlotGrid(),
                      ),
                    ],
                  ),
                ),

                // Bottom Action
                _buildBottomAction(),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 110,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: 14, // Next 2 weeks
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final color = context.primary;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _selectedDate = date);
                _loadSlots();
              },
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 65,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          colors: [color, color.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : context.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? color.withValues(alpha: 0.1)
                        : context.dividerColor.withValues(alpha: 0.05),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                        color: isSelected
                            ? Colors.white.withValues(alpha: 0.8)
                            : context.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isSelected
                            ? Colors.white
                            : context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSlotGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.0,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _slots.length,
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final isSelected = _selectedSlotId == slot.id;
        final isBooked = slot.status == SlotStatus.booked;
        final isCompleted = slot.status == SlotStatus.completed;
        final isUnavailable = isBooked || isCompleted;
        final color = context.primary;

        return InkWell(
              onTap: isUnavailable
                  ? null
                  : () => setState(() => _selectedSlotId = slot.id),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : isUnavailable
                      ? context.textTertiary.withValues(alpha: 0.05)
                      : context.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? color
                        : isUnavailable
                        ? Colors.transparent
                        : context.dividerColor.withValues(alpha: 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      slot.startTime,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.w900
                            : FontWeight.w600,
                        fontSize: 15,
                        color: isSelected
                            ? color
                            : isUnavailable
                            ? context.textTertiary
                            : context.textSecondary,
                        decoration: isUnavailable
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (isUnavailable)
                      Text(
                        isBooked ? 'Booked' : 'Done',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: context.textTertiary,
                        ),
                      ),
                  ],
                ),
              ),
            )
            .animate(target: isSelected ? 1 : 0)
            .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05));
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: context.primary.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No slots available',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep checking back for new slots.',
            style: TextStyle(fontSize: 14, color: context.textTertiary),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadSlots,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(foregroundColor: context.primary),
          ),
        ],
      ).animate().fadeIn().slideY(begin: 0.1, end: 0),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _selectedSlotId == null
            ? null
            : () {
                final selectedSlot = _slots.firstWhere(
                  (s) => s.id == _selectedSlotId,
                );
                Navigator.pushNamed(
                  context,
                  '/attach-results',
                  arguments: {
                    'doctor': _doctor,
                    'date': _selectedDate,
                    'slot': selectedSlot,
                    'latitude': _latitude,
                    'longitude': _longitude,
                    'exactAddress': _exactAddress,
                  },
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 60),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          elevation: 0,
          disabledBackgroundColor: context.dividerColor.withValues(alpha: 0.1),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
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
}
