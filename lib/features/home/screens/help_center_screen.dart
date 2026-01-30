import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/theme_extension.dart';
import '../../../core/utils/snackbar_utils.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  static const String whatsappNumber = '7208996265';

  Future<void> _launchWhatsApp(BuildContext context) async {
    final Uri whatsappUri = Uri.parse('https://wa.me/91$whatsappNumber');
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      Clipboard.setData(const ClipboardData(text: whatsappNumber));
      if (context.mounted) {
        SnackbarUtils.showSuccess(
          context,
          'WhatsApp number copied to clipboard',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.bold, color: context.primary),
        ),
        backgroundColor: context.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWhatsAppCard(context),
            const SizedBox(height: 32),

            _buildSectionTitle('App Navigation Guide'),
            const SizedBox(height: 16),
            _buildNavigationGuide(
              title: 'Quick Test',
              icon: Icons.timer_outlined,
              description: 'Fast, preliminary vision screening.',
              purpose:
                  'Designed for a rapid checkup of your visual clarity and color health in under 3 minutes.',
              usage:
                  'Ideal for frequent monitoring or when you have limited time and want a quick status update.',
            ),
            const SizedBox(height: 12),
            _buildNavigationGuide(
              title: 'Full Eye Exam',
              icon: Icons.health_and_safety_outlined,
              description: 'Deep clinical examination.',
              purpose:
                  'A comprehensive battery of tests (including Refractometry and Contrast) for a detailed vision profile.',
              usage:
                  'Use this for your monthly checkup or if you are experiencing new symptoms like blurriness or eye strain.',
            ),
            const SizedBox(height: 12),
            _buildNavigationGuide(
              title: 'Visiaxx TV / Eye Exercises',
              icon: Icons.video_library_outlined,
              description: 'Eye improvement & relaxation tips.',
              purpose:
                  'A library of video reels and tutorials providing information on how to reduce digital eye strain and improve vision naturally.',
              usage:
                  'Perfect for learning effective eye care techniques and finding tips to relax your eyes after long screen sessions.',
            ),
            const SizedBox(height: 12),
            _buildNavigationGuide(
              title: 'Eye Care Tips',
              icon: Icons.tips_and_updates_outlined,
              description: 'Daily health & lifestyle advice.',
              purpose:
                  'Curated professional tips on lighting, screen distance, nutrition, and habits for long-term eye health.',
              usage:
                  'Read these to improve your workspace ergonomics and learn how to protect your eyes daily.',
            ),
            const SizedBox(height: 12),
            _buildNavigationGuide(
              title: 'My Results',
              icon: Icons.assessment_outlined,
              description: 'Your vision records history.',
              purpose:
                  'Securely stores every test result. You can view progress charts and download clinical PDF reports.',
              usage:
                  'Visit here to show your vision history to your local eye doctor during a physical appointment.',
            ),
            const SizedBox(height: 12),
            _buildNavigationGuide(
              title: 'Consultation',
              icon: Icons.video_call_outlined,
              description: 'Expert professional support.',
              purpose:
                  'Connects you with vision specialists if your screening results indicate a need for further clinical investigation.',
              usage:
                  'Use this if you have concerns about your test scores or need advice on the next steps for your vision care.',
            ),

            const SizedBox(height: 32),
            _buildSectionTitle('Comprehensive test Guide'),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Visual Acuity Test',
              icon: Icons.visibility_outlined,
              description: 'Sharpness and clarity of vision at a distance.',
              whatIsIt:
                  'This is the standard measurement of how well your eyes see fine detail from a fixed distance using the clinically validated "Tumbling E" chart.',
              whatItDiagnoses:
                  'Primarily identifies refractive errors like Myopia (nearsightedness), Hyperopia (farsightedness), and Astigmatism. It can also hint at organic eye conditions if acuity remains low with correction.',
              howUseful:
                  'Critical for daily safety and performance. It determines your ability to drive, read signs, recognize faces, and perform tasks that require distance focus.',
              howPerformed:
                  'You will hold the device at exactly 1 meter. An "E" symbol will appear in different orientations. You must identify the direction (Up, Down, Left, Right).',
              instructions: [
                'Ensure the room is well-lit but without glare on the screen.',
                'Sit or stand exactly 1 meter away from the device.',
                'The app will use AI to verify your distance in real-time.',
                'Cover one eye as instructed by the voice guide.',
                'Read the direction clearly aloud.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Color Blindness Screening',
              icon: Icons.palette_outlined,
              description: 'Ability to distinguish between different colors.',
              whatIsIt:
                  'Uses digital "Ishihara" plates—patterns of dots with hidden numbers or shapes—to test if your eyes can differentiate specific color wavelengths.',
              whatItDiagnoses:
                  'Detects Red-Green color blindness (Protanopia and Deuteranopia) and less common Blue-Yellow (Tritanopia) perception issues.',
              howUseful:
                  'Essential for career safety (aviation, electrical engineering, high-tech manufacturing) and daily tasks like interpreting traffic signals or reading color-coded data charts.',
              howPerformed:
                  'Hold the device at a normal reading distance (40cm). Identify the hidden number within the colored dots on a series of plates.',
              instructions: [
                'Keep the screen flat and avoid tilting it.',
                'Do not spend more than 5-10 seconds on a single plate.',
                'Select the matching number from the options.',
                'If no number is visible, select the "No Number" option.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Amsler Grid Assessment',
              icon: Icons.grid_on_outlined,
              description:
                  'Monitors the health of your central retina (macula).',
              whatIsIt:
                  'A diagnostic pattern used to detect visual distortions caused by changes in the retina, particularly the macula.',
              whatItDiagnoses:
                  'Highly effective at identifying early signs of Macular Degeneration (AMD), Diabetic Maculopathy, and Macular Oedema.',
              howUseful:
                  'Allows for home-based monitoring of retinal stability. Early detection of warped or missing lines (Metamorphopsia) can prevent permanent vision loss through timely medical treatment.',
              howPerformed:
                  'You focus on a central dot on a grid. You must report if any lines appear wavy, broken, or if any sections of the grid are "missing".',
              instructions: [
                'Hold the device at 40cm (arm\'s length).',
                'Focus strictly on the central black dot; do not let your eye wander.',
                'Check if lines appear wavy or if there is any "graying" or blurring.',
                'If distortions are seen, trace them accurately on the screen.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Contrast Sensitivity',
              icon: Icons.contrast_outlined,
              description:
                  'Measures ability to see objects against their backgrounds.',
              whatIsIt:
                  'Tests your eye\'s ability to distinguish subtle shades of gray. It uses "Pelli-Robson" triplets that gradually fade away.',
              whatItDiagnoses:
                  'Can identify early-stage Glaucoma, Cataracts, or Optic Neuritis, even when standard visual acuity still seems "normal".',
              howUseful:
                  'Explains functional vision issues, such as difficulty driving at night, reading in dim light, or navigating stairs, where "black and white" contrast is low.',
              howPerformed:
                  'Triple-letter groups are shown. The contrast decreases with each group. You read them aloud until they are no longer visible.',
              instructions: [
                'Set your screen brightness to MAXIMUM.',
                'Sit in a room with stable, non-flickering light.',
                'Read the 3 letters inside the blue box from left to right.',
                'The test ends automatically when you reach your threshold.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Reading & Near Vision',
              icon: Icons.chrome_reader_mode_outlined,
              description:
                  'Evaluates focusing power at close reading distances.',
              whatIsIt:
                  'Assesses the quality of vision at a typical smartphone or book distance (40cm).',
              whatItDiagnoses:
                  'Detects Presbyopia (age-related inability to focus on close objects) and digital eye strain (Computer Vision Syndrome).',
              howUseful:
                  'Assists in determining the need for reading glasses and helps optometrists recommend the correct "Add" power for bifocal or multifocal lenses.',
              howPerformed:
                  'A sequence of sentences at varying font sizes is displayed. You read the text aloud while maintaining a steady near distance.',
              instructions: [
                'Hold the device at your preferred reading distance.',
                'Read the text clearly and naturally.',
                'Select if the text is perfectly sharp or if it has any "halo" or blur.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Mobile Refractometry',
              icon: Icons.psychology_outlined,
              description: 'Digital assessment of the eye\'s refractive state.',
              whatIsIt:
                  'A sophisticated screening tool that approximates your eye\'s power by analyzing blur patterns at two distinct distances (1m and 40cm).',
              whatItDiagnoses:
                  'Provides an estimated refractive error (sphere and cylinder), suggesting if you might need a prescription for Myopia, Hyperopia, or Astigmatism.',
              howUseful:
                  'Provides a fast, preliminary digital baseline. It is perfect for remote screening to determine if an urgent comprehensive eye clinic visit is necessary.',
              howPerformed:
                  'This test is performed WITHOUT glasses. Follow the voice prompts to move the device and respond when the target becomes blurry.',
              instructions: [
                'Remove all glasses or contact lenses before starting.',
                'Turn up your volume as voice guidance is extensive here.',
                'Immediately say "Blurry" or select "Can\'t See" when the letter fades.',
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsAppCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF25D366), const Color(0xFF128C7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF25D366).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need Help?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Chat with us on WhatsApp',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _launchWhatsApp(context),
              icon: const Icon(Icons.chat),
              label: const Text('Message Support'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF128C7E),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildNavigationGuide({
    required String title,
    required IconData icon,
    // Unified to Primary Color
    required String description,
    required String purpose,
    required String usage,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: context.primary, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildSubSection('What is this?', purpose),
                  const SizedBox(height: 16),
                  _buildSubSection('When to use it?', usage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestGuide({
    required String title,
    required IconData icon,
    // Unified to Primary Color
    required String description,
    required String whatIsIt,
    required String whatItDiagnoses,
    required String howUseful,
    required String howPerformed,
    required List<String> instructions,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.5)),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildSubSection('What is it?', whatIsIt),
                  const SizedBox(height: 16),
                  _buildSubSection('What does it diagnose?', whatItDiagnoses),
                  const SizedBox(height: 16),
                  _buildSubSection('Why is it useful?', howUseful),
                  const SizedBox(height: 16),
                  _buildSubSection('How is it performed?', howPerformed),
                  const SizedBox(height: 16),
                  const Text(
                    'Instructions to follow:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...instructions.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(
                              color: Colors
                                  .blue, // Replaced AppColors.primary with a generic blue or context.primary if preferred, but usually bullets should follow theme
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildSubSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          content,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
