import 'package:flutter/material.dart';

/// Questionnaire screen for comprehensive test
class QuestionnaireScreen extends StatefulWidget {
  const QuestionnaireScreen({super.key});

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  final Map<String, dynamic> _answers = {};
  int _currentPage = 0;
  final int _totalPages = 3;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Health Questionnaire')),
      body: Column(
        children: [
          LinearProgressIndicator(value: (_currentPage + 1) / _totalPages),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildCurrentPage(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _currentPage--;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text('Back'),
                      ),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < _totalPages - 1) {
                        setState(() {
                          _currentPage++;
                        });
                      } else {
                        // Navigate to next test
                        Navigator.pushNamed(
                          context,
                          '/comprehensive-visual-acuity',
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _currentPage < _totalPages - 1 ? 'Next' : 'Continue',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return _buildPage1();
      case 1:
        return _buildPage2();
      case 2:
        return _buildPage3();
      default:
        return Container();
    }
  }

  Widget _buildPage1() {
    return ListView(
      children: [
        Text(
          'Personal Information',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildYesNoQuestion(
          'Do you currently wear glasses or contact lenses?',
          'wears_glasses',
        ),
        _buildYesNoQuestion(
          'Have you had any eye surgery in the past?',
          'had_eye_surgery',
        ),
        _buildYesNoQuestion(
          'Do you have a family history of eye diseases?',
          'family_history',
        ),
      ],
    );
  }

  Widget _buildPage2() {
    return ListView(
      children: [
        Text(
          'Symptoms',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildYesNoQuestion(
          'Do you experience frequent headaches?',
          'headaches',
        ),
        _buildYesNoQuestion(
          'Do you have difficulty reading?',
          'reading_difficulty',
        ),
        _buildYesNoQuestion('Do you see halos around lights?', 'halos'),
        _buildYesNoQuestion('Do you experience eye strain?', 'eye_strain'),
      ],
    );
  }

  Widget _buildPage3() {
    return ListView(
      children: [
        Text(
          'Medical History',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        _buildYesNoQuestion('Do you have diabetes?', 'diabetes'),
        _buildYesNoQuestion(
          'Do you have high blood pressure?',
          'high_blood_pressure',
        ),
        _buildYesNoQuestion('Are you taking any medications?', 'medications'),
      ],
    );
  }

  Widget _buildYesNoQuestion(String question, String key) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            RadioGroup<bool>(
              groupValue: _answers[key],
              onChanged: (value) {
                setState(() {
                  _answers[key] = value;
                });
              },
              child: Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Yes'),
                      value: true,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('No'),
                      value: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
