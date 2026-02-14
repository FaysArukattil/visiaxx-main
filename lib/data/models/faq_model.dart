import 'package:flutter/material.dart';

class FAQCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final List<FAQItem> items;

  const FAQCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.items,
  });
}

class FAQItem {
  final String question;
  final String answer;

  const FAQItem({required this.question, required this.answer});
}

class FAQData {
  static const List<FAQCategory> categories = [
    FAQCategory(
      id: 'general',
      title: 'General',
      description: 'Basics about Visiaxx App',
      icon: Icons.info_outline_rounded,
      items: [
        FAQItem(
          question: 'What is Visiaxx?',
          answer:
              'Visiaxx is a digital eye clinic app that allows you to perform clinically validated vision screenings from your smartphone.',
        ),
        FAQItem(
          question: 'Is it free to use?',
          answer:
              'The basic vision screenings are free. Some advanced clinical reports or professional consultations may have a fee.',
        ),
        FAQItem(
          question: 'Is it clinically accurate?',
          answer:
              'Yes, our tests are based on standard clinical charts like Snellen and Ishihara, and have been validated by eye care professionals.',
        ),
      ],
    ),
    FAQCategory(
      id: 'tests',
      title: 'Vision Tests',
      description: 'Troubleshooting test issues',
      icon: Icons.visibility_outlined,
      items: [
        FAQItem(
          question: 'Why does distance verification fail?',
          answer:
              'Ensure you are in a well-lit room and holding the phone at eye level. Avoid busy backgrounds which might confuse the camera.',
        ),
        FAQItem(
          question: 'Do I need to remove my glasses?',
          answer:
              'For some tests like Mobile Refractometry, yes. For others like Visual Acuity, you should test both with and without your current prescription.',
        ),
        FAQItem(
          question: 'I can\'t see the letters clearly.',
          answer:
              'If you can\'t see the targets even with your glasses, the test results will reflect that. It might indicate a need for a new prescription.',
        ),
      ],
    ),
    FAQCategory(
      id: 'results',
      title: 'Reports & Results',
      description: 'Accessing and sharing data',
      icon: Icons.assessment_outlined,
      items: [
        FAQItem(
          question: 'Where can I see my results?',
          answer:
              'All your history is saved in the "My Results" section. You can view, download, and share PDF reports from there.',
        ),
        FAQItem(
          question: 'How do I share my PDF?',
          answer:
              'Open any result in the "My Results" screen and click the Share icon to send it via WhatsApp, Email, or other apps.',
        ),
      ],
    ),
    FAQCategory(
      id: 'technical',
      title: 'Technical Support',
      description: 'Account and app issues',
      icon: Icons.settings_phone_outlined,
      items: [
        FAQItem(
          question: 'App is crashing on start.',
          answer:
              'Try clearing the app cache or reinstalling. Ensure your phone running the latest OS version for best stability.',
        ),
        FAQItem(
          question: 'I forgot my password.',
          answer:
              'Use the "Forgot Password" link on the login screen to receive a reset link via your registered email.',
        ),
      ],
    ),
  ];
}
