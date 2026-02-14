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
        FAQItem(
          question: 'Who should use this app?',
          answer:
              'Anyone looking for a quick, accessible eye screening. However, it does not replace a comprehensive eye exam by an optometrist.',
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
          question: 'What is the 1-meter rule?',
          answer:
              'Most acuity tests require you to be exactly 1 meter (3.3 feet) from the screen for calibrated results.',
        ),
        FAQItem(
          question: 'Why is my screen brightness important?',
          answer:
              'Tests like Color Vision (Ishihara) require high brightness (80%+) to accurately display colors.',
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
        FAQItem(
          question: 'Can I delete old reports?',
          answer:
              'Yes, you can swipe left on any report in History or use the "Delete" option in report details.',
        ),
      ],
    ),
    FAQCategory(
      id: 'account',
      title: 'Account & Security',
      description: 'Login, Profile, and Privacy',
      icon: Icons.account_circle_outlined,
      items: [
        FAQItem(
          question: 'How do I reset my password?',
          answer:
              'Log out of the app and use the "Forgot Password" link on the login screen to receive a reset email.',
        ),
        FAQItem(
          question: 'Is my data secure?',
          answer:
              'Yes, we use industry-standard encryption and Firebase security protocols to protect your health data.',
        ),
        FAQItem(
          question: 'How do I update my profile?',
          answer:
              'Go to the Profile screen and tap on your name or "Edit Profile" to change your details.',
        ),
      ],
    ),
    FAQCategory(
      id: 'technical',
      title: 'Technical Support',
      description: 'App issues and compatibility',
      icon: Icons.settings_phone_outlined,
      items: [
        FAQItem(
          question: 'App is crashing on start.',
          answer:
              'Try clearing the app cache or reinstalling. Ensure your phone running the latest OS version for best stability.',
        ),
        FAQItem(
          question: 'The camera isn\'t opening.',
          answer:
              'Check your phone settings to ensure Visiaxx has permission to access the Camera.',
        ),
        FAQItem(
          question: 'Does it work offline?',
          answer:
              'Most tests work offline, but you need an internet connection to sync results and generate PDF reports.',
        ),
      ],
    ),
  ];
}
