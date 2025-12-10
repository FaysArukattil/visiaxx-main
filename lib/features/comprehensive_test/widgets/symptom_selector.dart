import 'package:flutter/material.dart';

/// Symptom selector widget
class SymptomSelector extends StatefulWidget {
  final Function(List<String>) onSymptomsChanged;

  const SymptomSelector({
    super.key,
    required this.onSymptomsChanged,
  });

  @override
  State<SymptomSelector> createState() => _SymptomSelectorState();
}

class _SymptomSelectorState extends State<SymptomSelector> {
  final List<String> _allSymptoms = [
    'Blurred vision',
    'Double vision',
    'Headaches',
    'Eye strain',
    'Dry eyes',
    'Watery eyes',
    'Sensitivity to light',
    'Floaters',
    'Flashes of light',
    'Difficulty seeing at night',
  ];

  final Set<String> _selectedSymptoms = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select any symptoms you are experiencing:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allSymptoms.map((symptom) {
            final isSelected = _selectedSymptoms.contains(symptom);
            return FilterChip(
              label: Text(symptom),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedSymptoms.add(symptom);
                  } else {
                    _selectedSymptoms.remove(symptom);
                  }
                  widget.onSymptomsChanged(_selectedSymptoms.toList());
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
