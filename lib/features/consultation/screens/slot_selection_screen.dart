import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/services/consultation_service.dart';
import '../../../data/models/doctor_model.dart';
import '../../../data/models/time_slot_model.dart';
import '../../home/widgets/app_bar_widget.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _doctor = args?['doctor'];
    if (_doctor != null) {
      _loadSlots();
    }
  }

  Future<void> _loadSlots() async {
    setState(() => _isLoading = true);
    final slots = await _consultationService.getAvailableSlots(
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
    if (_doctor == null)
      return const Scaffold(body: Center(child: Text('Doctor missing')));

    return Scaffold(
      appBar: const AppBarWidget(title: 'Select Slot'),
      body: Column(
        children: [
          _buildDatePicker(),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _slots.isEmpty
                ? _buildEmptyState()
                : _buildSlotGrid(),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomAction(),
    );
  }

  Widget _buildDatePicker() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 14, // Next 2 weeks
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = DateUtils.isSameDay(date, _selectedDate);

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () {
                setState(() => _selectedDate = date);
                _loadSlots();
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: 60,
                decoration: BoxDecoration(
                  color: isSelected ? context.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? context.primary
                        : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d').format(date),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? AppColors.white
                            : AppColors.textSecondary,
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
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _slots.length,
      itemBuilder: (context, index) {
        final slot = _slots[index];
        final isSelected = _selectedSlotId == slot.id;

        return InkWell(
          onTap: () => setState(() => _selectedSlotId = slot.id),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? context.primary.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? context.primary
                    : Theme.of(context).dividerColor.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              slot.startTime,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? context.primary : AppColors.textSecondary,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 64,
            color: AppColors.textTertiary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text('No slots available for this date.'),
          TextButton(onPressed: _loadSlots, child: const Text('Try Again')),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 10,
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
                  },
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Continue',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}
