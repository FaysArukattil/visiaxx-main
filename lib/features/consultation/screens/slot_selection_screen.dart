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
    // Guard against redundant initialization on orientation changes
    if (_doctor != null) return;

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

    final bookedSlots = await _consultationService.getAllSlotsForDate(
      _doctor!.id,
      _selectedDate,
    );

    final generatedSlots = _generateDailySlots(_selectedDate);

    final finalSlots = generatedSlots.map((gen) {
      final booked = bookedSlots
          .where((b) => b.startTime == gen.startTime)
          .firstOrNull;
      if (booked != null) {
        return booked;
      }
      return gen;
    }).toList();

    setState(() {
      _slots = finalSlots;
      _isLoading = false;
      // selection is now managed explicitly by interactions
    });
  }

  List<TimeSlotModel> _generateDailySlots(DateTime date) {
    final List<TimeSlotModel> slots = [];
    final startTime = DateTime(date.year, date.month, date.day, 10);
    final endTime = DateTime(date.year, date.month, date.day, 22);

    DateTime current = startTime;
    int index = 0;
    while (current.isBefore(endTime)) {
      final next = current.add(const Duration(minutes: 20));
      final startTimeStr = DateFormat('h:mm a').format(current);
      final endTimeStr = DateFormat('h:mm a').format(next);

      slots.add(
        TimeSlotModel(
          id: 'gen_${date.millisecondsSinceEpoch}_$index',
          doctorId: _doctor!.id,
          date: date,
          startTime: startTimeStr,
          endTime: endTimeStr,
          status: SlotStatus.available,
        ),
      );

      current = next;
      index++;
    }
    return slots;
  }

  @override
  Widget build(BuildContext context) {
    if (_doctor == null) {
      return const Scaffold(body: Center(child: Text('Doctor missing')));
    }

    final theme = Theme.of(context);
    final color = context.primary;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background Decorative Circles
          Positioned(
            top: -120,
            right: -60,
            child: _buildDecorativeCircle(color, 400, 0.04),
          ),
          Positioned(
            bottom: 100,
            left: -80,
            child: _buildDecorativeCircle(color, 320, 0.03),
          ),

          SafeArea(
            child: Column(
              children: [
                if (isLandscape)
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Header & Date Selection
                        Expanded(
                          flex: 2,
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(24, 12, 0, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeaderRow(context),
                                const SizedBox(height: 32),
                                Text(
                                  'Select Date',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: context.textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildDateList(isVertical: true),
                              ],
                            ),
                          ),
                        ),
                        // Right Column: Slots
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              Expanded(
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _slots.isEmpty
                                    ? _buildEmptyState()
                                    : _buildSlotGrid(crossAxisCount: 4),
                              ),
                              _buildBottomAction(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Expanded(
                    child: Column(
                      children: [
                        _buildHeaderRow(context),
                        _buildDatePicker(),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : _slots.isEmpty
                              ? _buildEmptyState()
                              : _buildSlotGrid(crossAxisCount: 3),
                        ),
                        _buildBottomAction(),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  Widget _buildHeaderRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            constraints: const BoxConstraints(),
            padding: EdgeInsets.zero,
            icon: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.surface.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                size: 18,
                color: context.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointment with',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Dr. ${_doctor!.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.6,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 125,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: _buildDateList(),
    );
  }

  Widget _buildDateList({bool isVertical = false}) {
    if (isVertical) {
      return ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 14,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);
          final color = context.primary;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedDate = date;
                  _selectedSlotId = null; // Clear selection on date change
                });
                _loadSlots();
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : color.withValues(alpha: 0.08),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      DateFormat('EEE').format(date).toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : color,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('d MMM').format(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isSelected ? Colors.white : context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: 14,
      itemBuilder: (context, index) {
        final date = DateTime.now().add(Duration(days: index));
        final isSelected = DateUtils.isSameDay(date, _selectedDate);
        final color = context.primary;

        return Padding(
          padding: const EdgeInsets.only(right: 14),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedDate = date;
                _selectedSlotId = null; // Clear selection on date change
              });
              _loadSlots();
            },
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 70,
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.08),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.8)
                          : color,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? Colors.white : context.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSlotGrid({int crossAxisCount = 3}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Available Time Slots',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '10:00 AM - 10:00 PM',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: context.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            physics: const BouncingScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 2.4,
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
                    : () {
                        setState(() {
                          if (_selectedSlotId == slot.id) {
                            _selectedSlotId = null;
                          } else {
                            _selectedSlotId = slot.id;
                          }
                        });
                      },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color
                        : isUnavailable
                        ? context.dividerColor.withValues(alpha: 0.05)
                        : color.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? color
                          : isUnavailable
                          ? Colors.transparent
                          : color.withValues(alpha: 0.1),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    slot.startTime,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.w900
                          : FontWeight.w700,
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : isUnavailable
                          ? context.textTertiary
                          : context.textPrimary,
                      decoration: isUnavailable
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
