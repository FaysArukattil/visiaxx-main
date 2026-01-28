import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
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
        title: const Text(
          'Help Center',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.white,
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
            _buildSectionTitle('Comprehensive test Guide'),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Visual Acuity Test',
              icon: Icons.visibility_outlined,
              color: AppColors.primary,
              description:
                  'Measures your ability to see fine detail at a 1-meter distance.',
              whatIsIt:
                  'This is the standard test for visual clarity. It uses the "Tumbling E" chart to determine how small an object you can identify from a fixed distance.',
              howPerformed:
                  'You will hold the device at exactly 1 meter. An "E" will appear in different orientations. You must say or select the direction the E is pointing.',
              instructions: [
                'Ensure the room is well-lit but without glare on the screen.',
                'Sit or stand exactly 1 meter away from the device.',
                'The app will use AI to verify your distance.',
                'Cover one eye as instructed by the voice guide.',
                'Read the direction clearly (Up, Down, Left, Right).',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Color Blindness Screening',
              icon: Icons.palette_outlined,
              color: AppColors.success,
              description:
                  'Detects deficiencies in color perception (Red-Green, etc.).',
              whatIsIt:
                  'Uses Ishihara-inspired digital plates composed of dots with varying colors. A number or shape is hidden within the pattern.',
              howPerformed:
                  'Hold the device at a normal reading distance (approx. 40cm). A series of plates will be shown.',
              instructions: [
                'Do not tilt the screen; keep it flat toward your face.',
                'Identify the number in the center of the dots.',
                'Select the matching number from the options provided.',
                'If you see nothing, select "No Number".',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Amsler Grid Assessment',
              icon: Icons.grid_on_outlined,
              color: AppColors.warning,
              description:
                  'Monitors central vision for macula-related distortions.',
              whatIsIt:
                  'A diagnostic tool used to detect vision problems resulting from damage to the macula (the central part of the retina).',
              howPerformed:
                  'You focus on a central dot on a grid. If lines appear wavy or missing, you trace them.',
              instructions: [
                'Hold the device at 40cm (reading distance).',
                'Focus purely on the central black dot.',
                'Check if any lines appear wavy, broken, or blurry.',
                'If you see distortions, trace the area on the screen with your finger.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Contrast Sensitivity',
              icon: Icons.contrast_outlined,
              color: AppColors.info,
              description:
                  'Evaluates your ability to distinguish objects from backgrounds.',
              whatIsIt:
                  'Measures functional vision. Important for tasks like driving at night or reading in low light.',
              howPerformed:
                  'Uses Pelli-Robson triplets of letters that gradually decrease in contrast (get fainter).',
              instructions: [
                'Turn screen brightness to MAXIMUM for this test.',
                'Read the 3 letters inside the blue box aloud.',
                'The test ends when you can no longer distinguish the letters.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Reading & Near Vision',
              icon: Icons.chrome_reader_mode_outlined,
              color: AppColors.secondary,
              description:
                  'Assesses reading comfort and screens for presbyopia.',
              whatIsIt:
                  'Evaluates how well you can see text at a close reading distance.',
              howPerformed:
                  'A sentence is displayed at various sizes. You read it aloud at a 40cm distance.',
              instructions: [
                'Hold the device at a comfortable reading distance.',
                'Read the text clearly from the screen.',
                'Indicate if the text is perfectly clear or blurry.',
              ],
            ),
            const SizedBox(height: 16),
            _buildTestGuide(
              title: 'Mobile Refractometry',
              icon: Icons.psychology_outlined,
              color: AppColors.error,
              description: 'Natural vision assessment at dual distances.',
              whatIsIt:
                  'A comprehensive assessment checking how your eyes focus at both 1 meter and 40 cm.',
              howPerformed:
                  'Requires removing glasses or contacts to measure your natural focusing power.',
              instructions: [
                'Remove all eyewear before starting.',
                'Follow the voice prompts carefully as the distance changes.',
                'If the target becomes blurry, say "Blurry" immediately.',
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

  Widget _buildTestGuide({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required String whatIsIt,
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
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
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
                  const SizedBox(height: 8),
                  ...instructions.map(
                    (step) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '• ',
                            style: TextStyle(
                              color: color,
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
