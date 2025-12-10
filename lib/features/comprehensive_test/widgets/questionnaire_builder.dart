import 'package:flutter/material.dart';

/// Questionnaire builder widget for creating custom questionnaires
class QuestionnaireBuilder extends StatelessWidget {
  final List<Map<String, dynamic>> questions;
  final Function(String, dynamic) onAnswerChanged;

  const QuestionnaireBuilder({
    super.key,
    required this.questions,
    required this.onAnswerChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: questions.length,
      itemBuilder: (context, index) {
        final question = questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  question['question'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                _buildAnswerWidget(question),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnswerWidget(Map<String, dynamic> question) {
    final type = question['type'] as String;
    final key = question['key'] as String;

    switch (type) {
      case 'yes_no':
        return _buildYesNoWidget(key);
      case 'multiple_choice':
        return _buildMultipleChoiceWidget(key, question['options'] as List<String>);
      case 'text':
        return _buildTextFieldWidget(key);
      default:
        return Container();
    }
  }

  Widget _buildYesNoWidget(String key) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () => onAnswerChanged(key, true),
            child: const Text('Yes'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            onPressed: () => onAnswerChanged(key, false),
            child: const Text('No'),
          ),
        ),
      ],
    );
  }

  Widget _buildMultipleChoiceWidget(String key, List<String> options) {
    return Column(
      children: options.map((option) {
        return RadioListTile<String>(
          title: Text(option),
          value: option,
          groupValue: null, // TODO: Add state management
          onChanged: (value) => onAnswerChanged(key, value),
        );
      }).toList(),
    );
  }

  Widget _buildTextFieldWidget(String key) {
    return TextField(
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        hintText: 'Enter your answer',
      ),
      onChanged: (value) => onAnswerChanged(key, value),
    );
  }
}
