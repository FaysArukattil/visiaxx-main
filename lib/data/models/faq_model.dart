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
      title: 'General Questions',
      description: 'Basics about Visiaxx Platform',
      icon: Icons.info_outline_rounded,
      items: [
        FAQItem(
          question: 'What is the Visiaxx App?',
          answer:
              'Visiaxx is a digital eye-care platform designed to improve access to vision screening, early detection, and eye health awareness using smart technology and AI-enabled tools.',
        ),
        FAQItem(
          question: 'Who can use the Visiaxx App?',
          answer:
              'Visiaxx is designed for: General public, Patients, Optometrists and ophthalmologists, Vision centers and clinics, Corporate and school screening programs.',
        ),
        FAQItem(
          question: 'What problem does Visiaxx solve?',
          answer:
              'Visiaxx addresses: Late detection of eye diseases, Lack of accessible screening in rural and semi-urban areas, Poor awareness about preventive eye care, and Fragmented eye health data management.',
        ),
      ],
    ),
    FAQCategory(
      id: 'features',
      title: 'Features & Technology',
      description: 'Functionality and AI details',
      icon: Icons.auto_awesome_outlined,
      items: [
        FAQItem(
          question: 'What are the key features of the Visiaxx App?',
          answer:
              'Key features include: Digital vision screening, AI-assisted early risk detection, Refractive error awareness modules, DR, glaucoma, AMD screening awareness, Eye health education through Visiaxx Music, Patient data management dashboard, and Remote screening capability including Van Herick Shadow Test, Contrast Sensitivity Test, and Cover-Uncover Test.',
        ),
        FAQItem(
          question:
              'How is Visiaxx different from other eye-care apps in India?',
          answer:
              'Visiaxx stands out through: Preventive + awareness + screening in one platform, AI-driven early risk alerts, Eye-health educational music engagement, Focus on mass screening and accessibility, and a Vision-access–focused ecosystem approach.',
        ),
        FAQItem(
          question: 'Does Visiaxx use Artificial Intelligence?',
          answer:
              'Yes. Visiaxx integrates AI-assisted analytics to support early risk identification and smart screening workflows (not a replacement for clinical diagnosis).',
        ),
        FAQItem(
          question: 'Can Visiaxx be used for remote eye screening?',
          answer:
              'Yes. The platform supports remote and field-based screening workflows, making it suitable for camps, schools, and rural outreach programs.',
        ),
      ],
    ),
    FAQCategory(
      id: 'medical',
      title: 'Medical & Safety',
      description: 'Health data and professional advice',
      icon: Icons.health_and_safety_outlined,
      items: [
        FAQItem(
          question: 'Is Visiaxx a replacement for a doctor’s eye examination?',
          answer:
              'No. Visiaxx is a screening and awareness tool, not a substitute for a comprehensive eye examination by a qualified eye care professional.',
        ),
        FAQItem(
          question: 'Is the Visiaxx App safe to use?',
          answer:
              'Yes. The app is designed following digital health best practices, with secure data handling and user-friendly clinical workflows.',
        ),
        FAQItem(
          question: 'Does Visiaxx help detect serious eye diseases?',
          answer:
              'Visiaxx helps in early risk identification and awareness for conditions such as: Refractive errors, Diabetic retinopathy risk, Glaucoma risk awareness, and Age-related macular degeneration awareness. Users flagged at risk are advised to visit an eye care professional.',
        ),
      ],
    ),
    FAQCategory(
      id: 'professionals',
      title: 'For Clinics & Professionals',
      description: 'Benefits for healthcare providers',
      icon: Icons.business_center_outlined,
      items: [
        FAQItem(
          question: 'How can clinics benefit from Visiaxx?',
          answer:
              'Clinics can digitize screening workflows, manage patient data efficiently, conduct outreach programs, improve early case detection, and enhance patient engagement.',
        ),
        FAQItem(
          question: 'Is Visiaxx suitable for vision screening camps?',
          answer:
              'Yes. It is specifically designed to support: School screenings, Community camps, Corporate eye check programs, and Rural outreach initiatives.',
        ),
        FAQItem(
          question: 'Can Visiaxx integrate with existing eye clinic systems?',
          answer:
              'The platform is being designed to support interoperability and future integrations with digital health ecosystems.',
        ),
      ],
    ),
    FAQCategory(
      id: 'users',
      title: 'Users & Engagement',
      description: 'Using the app features',
      icon: Icons.people_outline,
      items: [
        FAQItem(
          question: 'What is Visiaxx Music?',
          answer:
              'Visiaxx Music is an innovative engagement feature that uses songs, meditation, and awareness audio to educate users about eye health, improve retention, and promote preventive eye care behavior.',
        ),
        FAQItem(
          question:
              'How often should users perform vision screening on the app?',
          answer:
              'Basic self-screening can be done periodically, but users should follow professional advice for comprehensive eye exams.',
        ),
        FAQItem(
          question:
              'When you get stuck while doing a test (e.g., Visual Acuity Test, Ishihara Color Vision Test)?',
          answer:
              'Read the instructions very carefully and do the test. Each test like Visual Acuity, Ishihara Color Vision, Van Herick Shadow Test, or Torchlight Examination has detailed preparation steps.',
        ),
        FAQItem(
          question: 'Stop the voice recognition?',
          answer:
              'If you have enabled voice recognition, voice will be recorded according to the answer you say. If you turn it off, the test can be done manually for better results.',
        ),
        FAQItem(
          question: 'Theme selection?',
          answer:
              'Theme can be used in dark mode or light mode and color can be changed according to your favourite color theme.',
        ),
        FAQItem(
          question: 'Want to talk to our executive?',
          answer: 'Call our customer care executive no. 7208996265.',
        ),
      ],
    ),
    FAQCategory(
      id: 'privacy',
      title: 'Privacy & Data',
      description: 'Security and data handling',
      icon: Icons.lock_outline,
      items: [
        FAQItem(
          question: 'Is my health data secure in Visiaxx?',
          answer:
              'Yes. Visiaxx follows secure data handling practices and is designed to comply with digital health data protection standards.',
        ),
        FAQItem(
          question: 'Does Visiaxx share user data with third parties?',
          answer:
              'No personal health data is shared without user consent, except where required for clinical or regulatory purposes.',
        ),
      ],
    ),
    FAQCategory(
      id: 'future',
      title: 'Startup & Future Vision',
      description: 'Long-term goals and partnerships',
      icon: Icons.rocket_launch_outlined,
      items: [
        FAQItem(
          question: 'What is the long-term vision of Visiaxx?',
          answer:
              'Visiaxx aims to become a vision-access ecosystem that enables early detection, awareness, and digital eye-care delivery at scale across India and globally.',
        ),
        FAQItem(
          question: 'Is Visiaxx applying for Startup India recognition?',
          answer:
              'Yes. Visiaxx is positioned as an innovative digital health solution addressing a significant public health gap in eye care.',
        ),
        FAQItem(
          question: 'How can organizations partner with Visiaxx?',
          answer:
              'Hospitals, NGOs, schools, and corporate partners can collaborate for screening programs, pilot projects, and digital eye-care initiatives.',
        ),
      ],
    ),
    FAQCategory(
      id: 'test-guide',
      title: 'Clinical Test Guide',
      description: 'Learn how tests work & their significance',
      icon: Icons.menu_book_rounded,
      items: [
        FAQItem(
          question: 'Visual Acuity Test (Snellen/ETDRS)',
          answer:
              '• Purpose: Measures the sharpness/clarity of your central vision.\n• Performance: Stand 1 meter from the device. Read letters as they appear.\n• Output: Recorded as Snellen equivalent (e.g., 6/6) or LogMAR score.',
        ),
        FAQItem(
          question: 'Van Herick Shadow Test',
          answer:
              '• Purpose: Screens for narrow-angle Glaucoma risk by assessing the anterior chamber depth.\n• Performance: Using the phone\'s flash, a slit is projected on the iris. You must align the guide to capture the shadow.\n• Output: Grade 1 (Narrow) to Grade 4 (Open).',
        ),
        FAQItem(
          question: 'Ishihara Color Vision Test',
          answer:
              '• Purpose: Detects Red-Green color vision deficiency.\n• Performance: Identify hidden numbers or paths within mosaic plates.\n• Output: Score based on correct identifications (e.g., 10/11 Correct).',
        ),
        FAQItem(
          question: 'Mobile Refractometry',
          answer:
              '• Purpose: Estimates your refractive error (spectacle power requirement).\n• Performance: Remove glasses. Align your eye with the on-screen target at 30cm.\n• Output: Diopter values for Spherical, Cylinder, and Axis.',
        ),
        FAQItem(
          question: 'Stereopsis 3D Test',
          answer:
              '• Purpose: Evaluates depth perception (how well eyes work together).\n• Performance: Wear Red/Cyan anaglyph glasses. Identify which shape appears closer.\n• Output: Depth sensitivity measured in "Seconds of Arc".',
        ),
        FAQItem(
          question: 'Visual Field Test (Perimetry)',
          answer:
              '• Purpose: Maps your peripheral (side) vision to detect blind spots (scotomas).\n• Performance: Fixate on a center dot. Tap the screen when you see flashes in your side vision.\n• Output: A sensitivity map showing any vision loss areas.',
        ),
        FAQItem(
          question: 'Contrast Sensitivity Test',
          answer:
              '• Purpose: Measures ability to distinguish objects from their background (useful for early Cataract/Glaucoma).\n• Performance: Identify letters or gratings that gradually fade in contrast.\n• Output: Contrast threshold percentage.',
        ),
        FAQItem(
          question: 'Cover-Uncover Test (Strabismus)',
          answer:
              '• Purpose: Detects eye misalignment (tropias/phorias) or squint.\n• Performance: The app observes eye movement while one eye is digitally or manually covered.\n• Output: Identification of Exotropia, Esotropia, or Orthophoria.',
        ),
        FAQItem(
          question: 'Torchlight & Extraocular Muscle Exam',
          answer:
              '• Purpose: Checks pupil reactions and eye muscle coordination.\n• Performance: Follow a moving light source or observe pupil response to light pulses.\n• Output: Assessment of Full range of motion and Pupillary reflex (RAPD).',
        ),
      ],
    ),
  ];
}
