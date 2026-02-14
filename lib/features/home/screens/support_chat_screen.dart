import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visiaxx/core/extensions/theme_extension.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/bug_report_dialog.dart';

class SupportChatScreen extends StatefulWidget {
  const SupportChatScreen({super.key});

  @override
  State<SupportChatScreen> createState() => _SupportChatScreenState();
}

class ChatMessage {
  final String text;
  final bool isUser;
  final List<String>? quickReplies;

  ChatMessage({required this.text, required this.isUser, this.quickReplies});
}

class _SupportChatScreenState extends State<SupportChatScreen> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final String _supportNumber = '7208996265';

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      "Hi there! 👋 I'm VisiBot, your personalized eye-care assistant.\n\nI can help you with test troubleshooting, understanding results, and technical support. How can I assist you today?",
      quickReplies: [
        'Vision Test Help',
        'Understanding Results',
        'Account Help',
        'Report a Bug',
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {List<String>? quickReplies}) {
    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: false, quickReplies: quickReplies),
      );
    });
    _scrollToBottom();
  }

  void _addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageController.clear();
    });
    _scrollToBottom();
    _handleUserResponse(text);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleUserResponse(String text) {
    Future.delayed(const Duration(seconds: 1), () {
      final lowercaseText = text.toLowerCase();

      // 1. Technical Bug Redirection
      if (lowercaseText.contains('bug') ||
          lowercaseText.contains('crash') ||
          lowercaseText.contains('error') ||
          lowercaseText.contains('broken') ||
          lowercaseText.contains('fail')) {
        _addBotMessage(
          "I've detected you might be experiencing a technical failure. 🛠️\n\nWould you like to open our Bug Reporting Tool? This will notify our developers directly with your system logs and device details.",
          quickReplies: [
            'Submit Bug Report',
            'Vision Test Help',
            'Talk to Human',
          ],
        );
        return;
      }
      if (text == 'Submit Bug Report' || text == 'Report a Bug') {
        _showBugReportDialog();
        return;
      }

      // 2. Account & Security Hub
      if (lowercaseText.contains('account') ||
          lowercaseText.contains('profile') ||
          lowercaseText.contains('password') ||
          lowercaseText.contains('login') ||
          lowercaseText.contains('logout')) {
        _addBotMessage(
          "🔐 Account & Security Hub:\n\nI can help you manage your profile, reset credentials, or secure your health data.",
          quickReplies: [
            'Reset Password',
            'Update Profile',
            'Logout Help',
            'Delete Account',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'Reset Password') {
        _addBotMessage(
          "To reset your password:\n1. Log out of the app.\n2. Tap 'Forgot Password' on the login screen.\n3. Check your email for the secure reset link.",
        );
        return;
      }
      if (text == 'Edit Profile') {
        _addBotMessage(
          "You can update your name, age, and gender by going to the Profile tab and tapping on your current name card.",
        );
        return;
      }
      if (text == 'Logout Help') {
        _addBotMessage(
          "To logout, go to the Profile screen and scroll to the very bottom to find the Sign Out button.",
        );
        return;
      }

      // 3. Clinical Deep Dives (Specific Test Knowledge)
      // PRIORITY: Check specific tests BEFORE general "test" or "help" keywords to avoid looping.

      // Visual Acuity
      if (lowercaseText.contains('acuity')) {
        _addBotMessage(
          "🔬 Visual Acuity Deep Dive:\n\n• Purpose: Measures the sharpness/clarity of your central vision.\n• Performance: Stand 1 meter (3.3ft) from the device. Read letters as they appear. Use voice or tap to respond.\n• Output: Recorded as Snellen equivalent (e.g., 6/6) or LogMAR score.\n• Why it matters: Vital for detecting myopia, hyperopia, or astigmatism early on.",
          quickReplies: [
            'How to Respond (Acuity)',
            'Voice Help',
            'Distance Help',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Acuity)') {
        _addBotMessage(
          "📜 Visual Acuity - How to Respond:\n\n1. 🎤 Voice: Speak the letter clearly (e.g., 'E', 'Left', 'Up').\n2. 🖐️ Touch: Tap the corresponding direction button on the screen.\n3. ⏱️ Timing: You have 10 seconds for each letter. If you miss it, the next letter appears automatically.\n\n✨ [ANIMATION]: Imagine the letter rotating and the mic icon pulsing as you speak! ⚡",
          quickReplies: ['Voice Help', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Voice Help') {
        _addBotMessage(
          "For voice recognition:\n- Grant microphone permissions.\n- Speak the letter (E, C, or direction) loudly and clearly.\n- Avoid noisy background environments.",
        );
        return;
      }
      if (text == 'Distance Help') {
        _addBotMessage(
          "To verify distance:\n- Use the mirror calibration tool in the app.\n- Ensure you are exactly 1 meter away.\n- If the distance check fails, check for busy backgrounds.",
        );
        return;
      }

      // Shadow Test / Glaucoma
      if (lowercaseText.contains('shadow') ||
          lowercaseText.contains('glaucoma')) {
        _addBotMessage(
          "👁️ Van Herick Shadow Test Deep Dive:\n\n• Purpose: Screens for narrow-angle Glaucoma risk by assessing the anterior chamber depth.\n• Performance: Using the phone's flash, a slit is projected on the iris. Align the guide to capture the shadow.\n• Output: Grade 1 (Narrow) to Grade 4 (Open).\n• Why it matters: Helps identify risks of sudden-onset Glaucoma which can cause permanent vision loss.",
          quickReplies: [
            'How to Respond (Shadow)',
            'Common Fails',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Shadow)') {
        _addBotMessage(
          "📸 Shadow Test - How to Respond:\n\n1. 🔦 Flash: The app will turn on your flash automatically.\n2. 🎯 Alignment: Move the phone so the red circular guide covers your iris.\n3. ⏳ Stability: Hold perfectly still for 2 seconds while the AI analyzes the shadow.\n\n✨ [ANIMATION]: Watch the red circle turn GREEN when alignment is locked! 🟢",
          quickReplies: ['Common Fails', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Common Fails') {
        _addBotMessage(
          "Common failures in Shadow Test:\n- Pupil not detected: Improve room lighting.\n- Image too blurry: Clean your front camera lens.\n- Eye not centered: Look directly into the red circle.",
        );
        return;
      }

      // Color Vision / Ishihara
      if (lowercaseText.contains('color') ||
          lowercaseText.contains('ishihara')) {
        _addBotMessage(
          "🎨 Ishihara Color Vision Deep Dive:\n\n• Purpose: Detects Red-Green color vision deficiency.\n• Performance: Identify hidden numbers or paths within mosaic plates. Set brightness to 100%.\n• Output: Score based on correct identifications (e.g., 10/11 Correct).\n• Why it matters: Important for certain professions and understanding daily color perceptions.",
          quickReplies: [
            'How to Respond (Color)',
            'Brightness Info',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Color)') {
        _addBotMessage(
          "🔢 Color Vision - How to Respond:\n\n1. 👁️ Observe: Look at the mosaic plate for 3 seconds.\n2. ⌨️ Input: Type the number you see or select 'I see nothing'.\n3. 📏 Path: For path plates, follow the line with your eyes before selecting the result.\n\n✨ [ANIMATION]: The plates will flip like cards as you progress through the test! 🃏",
          quickReplies: ['Brightness Info', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Brightness Info') {
        _addBotMessage(
          "Low brightness or blue light filters distort the colors of the Ishihara plates, leading to inaccurate results. Always test at full brightness.",
        );
        return;
      }

      // Refractometry
      if (lowercaseText.contains('refractometry')) {
        _addBotMessage(
          "👓 Mobile Refractometry Deep Dive:\n\n• Purpose: Estimates your refractive error (spectacle power requirement).\n• Performance: Remove glasses. Align your eye with the target at 30cm. Face should be well-lit.\n• Output: Diopter values for Spherical (SPH), Cylinder (CYL), and Axis.\n• Why it matters: Provides a quick estimate of your prescription from your home.",
          quickReplies: [
            'How to Respond (Refract)',
            'Capture Help',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Refract)') {
        _addBotMessage(
          "🛠️ Refractometry - How to Respond:\n\n1. 👓 Prep: Remove all eyewear.\n2. 📏 Distance: Hold the phone exactly 30cm (1 foot) away.\n3. 🎯 Center: Align the red target ring with your pupil until it pulses.\n\n✨ [ANIMATION]: A bright blue scanning pulse will run across the screen during capture! ☄️",
          quickReplies: ['Capture Help', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Capture Help') {
        _addBotMessage(
          "If the capture fails:\n- Ensure the red line is centered on your pupil.\n- Hold the phone at 30cm distance.\n- Use a mirror if you have trouble aligning yourself.",
        );
        return;
      }

      // Stereopsis
      if (lowercaseText.contains('stereo')) {
        _addBotMessage(
          "🕶️ Stereopsis 3D Test Deep Dive:\n\n• Purpose: Evaluates depth perception (how well eyes work together).\n• Performance: Wear Red/Cyan anaglyph glasses. Identify which shape appears closer.\n• Output: Depth sensitivity measured in 'Seconds of Arc'.\n• Why it matters: Essential for sports, driving, and 3D vision health.",
          quickReplies: [
            'How to Respond (Stereo)',
            'No Glasses?',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Stereo)') {
        _addBotMessage(
          "📦 Stereopsis - How to Respond:\n\n1. 🕶️ Glasses: Put on your Red/Cyan anaglyph glasses now.\n2. 🕵️ Identify: Look at the 4 shapes. One will 'pop' out towards you.\n3. 👆 Select: Tap the shape that looks closest to you.\n\n✨ [ANIMATION]: Shapes will slowly emerge in 3D as your eyes focus through the filters! 💎",
          quickReplies: ['No Glasses?', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'No Glasses?') {
        _addBotMessage(
          "Without Red/Cyan glasses, you cannot perceive the 3D depth of this test. You can still select 'I see flat', but it won't accurately measure stereopsis.",
        );
        return;
      }

      // Visual Field
      if (lowercaseText.contains('field') ||
          lowercaseText.contains('amsler') ||
          lowercaseText.contains('peripheral')) {
        _addBotMessage(
          "📡 Visual Field Deep Dive:\n\n• Purpose: Maps your peripheral (side) vision to detect blind spots (scotomas).\n• Performance: Fixate on the center dot. Tap when you see flashes in your side vision.\n• Output: A sensitivity map showing any vision loss areas.\n• Why it matters: Critical for spotting early signs of Glaucoma or Neurological issues.",
          quickReplies: [
            'How to Respond (Field)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Field)') {
        _addBotMessage(
          "📡 Visual Field - How to Respond:\n\n1. 🎯 Fixate: Keep your eyes strictly on the center yellow dot.\n2. 🔦 Detect: Faint light pulses will appear randomly in your peripheral vision.\n3. ⌨️ Action: Tap the screen anywhere the instant you perceive a pulse.\n\n✨ [ANIMATION]: Subtle light stars will twinkle across the screen like fireflies! 🎇",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // Eye Hydration / Blink
      if (lowercaseText.contains('hydration') ||
          lowercaseText.contains('blink')) {
        _addBotMessage(
          "💧 Eye Hydration Deep Dive:\n\n• Purpose: Checks for Dry Eye syndrome by monitoring blink frequency.\n• Performance: Face the camera directly. Blink naturally for the duration of the test.\n• Output: Average blink rate and eye surface hydration score.\n• Why it matters: Digital eye strain often leads to low blink rates and dry eye discomfort.",
          quickReplies: [
            'How to Respond (Blink)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Blink)') {
        _addBotMessage(
          "💧 Eye Hydration - How to Respond:\n\n1. 🤳 Selfie: Hold the phone at a comfortable reading distance (40cm).\n2. 👁️ Eyes: Ensure your eyes are clearly visible in the preview.\n3. 😌 Relax: Simply blink as you normally would while the timer counts down.\n\n✨ [ANIMATION]: A water droplet icon will fill up as each blink is successfully detected! 💧",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // Contrast Sensitivity
      if (lowercaseText.contains('contrast')) {
        _addBotMessage(
          "👁️ Contrast Sensitivity Deep Dive:\n\n• Purpose: Measures ability to distinguish objects from backgrounds (useful for early Cataract/Glaucoma).\n• Performance: Identify letters or gratings that gradually fade in contrast.\n• Output: Contrast threshold percentage.\n• Why it matters: High sensitivity is needed for night driving and reading in low light.",
          quickReplies: [
            'How to Respond (Contrast)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Contrast)') {
        _addBotMessage(
          "👁️ Contrast - How to Respond:\n\n1. 📖 Read: Look at the letters on the screen.\n2. 📉 Fade: Each set will be harder to see than the last.\n3. ⌨️ Input: Tap the letter you see until it becomes invisible.\n\n✨ [ANIMATION]: Watch the letters slowly 'ghost' away as they merge with the background! 🌫️",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // Screening Exams
      if (text == 'Other Tests' ||
          lowercaseText.contains('cover') ||
          lowercaseText.contains('torch')) {
        _addBotMessage(
          "🩺 Screening Exams (Cover & Torchlight):\n\n• Cover-Uncover: Detects eye misalignment/squint (Strabismus). Observe eyes as they are covered/uncovered.\n• Torchlight Exam: Checks pupil reactions (RAPD) and eye muscle range of motion.\n• Why it matters: These tests help identify functional eye issues that specialized tests might miss.",
          quickReplies: [
            'How to Respond (Screening)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Screening)') {
        _addBotMessage(
          "🩺 Screening Exams - How to Respond:\n\n1. 🔦 Torchlight: Look straight ahead as a light source passes over your eyes to check for pupil reflex.\n2. 🙈 Cover Test: Keep both eyes open, but look at the distant object as one eye is covered.\n3. 🎬 Observation: These are observation-based tests; simply follow the on-screen animation guidance.\n\n✨ [ANIMATION]: A virtual covering hand will appear over the patient's eye on screen! ✋",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // 4. General Vision Tests Troubleshooting (Catch-all)
      if (lowercaseText.contains('test') ||
          lowercaseText.contains('vision') ||
          lowercaseText.contains('help')) {
        _addBotMessage(
          "Our clinical suite includes 15+ specialized tests. Which one are you performing?\n\nSelecting a test will provide specific troubleshooting tips and distance rules to ensure accuracy.",
          quickReplies: [
            'Visual Acuity Test',
            'Van Herick Shadow Test',
            'Ishihara Color Vision',
            'Mobile Refractometry',
            'Stereopsis 3D Test',
            'Visual Field Test',
            'Contrast Sensitivity Test',
            'Other Tests',
          ],
        );
        return;
      }

      // 4. Results & Reports
      if (lowercaseText.contains('result') ||
          lowercaseText.contains('report') ||
          lowercaseText.contains('pdf') ||
          lowercaseText.contains('share')) {
        _addBotMessage(
          "📋 Results & Clinical Reports:\n\n- Visit 'My Results' to see your full history.\n- Open any report to generate a Clinical PDF.\n- Use the share icon in the report view to send it via WhatsApp or Email.",
          quickReplies: ['Missing Report?', 'How to Share', 'Main Menu'],
        );
        return;
      }
      if (text == 'Missing Report?') {
        _addBotMessage(
          "If a report is missing:\n- Ensure you completed the entire test.\n- Check if you were logged in during the test.\n- Try refreshing the 'My Results' screen.",
        );
        return;
      }
      if (text == 'How to Share') {
        _addBotMessage(
          "To share a report:\n1. Open your test result.\n2. Tap the 'Share' or 'PDF' icon at the top.\n3. Choose your preferred app (WhatsApp, Email, etc.).",
        );
        return;
      }

      // 5. Conversational & Escalation
      if (lowercaseText.contains('hi') ||
          lowercaseText.contains('hello') ||
          lowercaseText.contains('hey')) {
        _addBotMessage(
          "Hello! I'm here to help. What aspect of Visiaxx or your vision tests can I assist with today?",
        );
        return;
      }

      if (lowercaseText.contains('thank') || lowercaseText.contains('thanks')) {
        _addBotMessage(
          "You're very welcome! I'm always here if you need more help with your eye health tests. Stay vision-active! 👁️✨",
        );
        return;
      }

      if (lowercaseText.contains('human') ||
          lowercaseText.contains('talk') ||
          lowercaseText.contains('agent') ||
          lowercaseText.contains('contact') ||
          text == 'Talk to Human') {
        _addBotMessage(
          "I'll connect you with our professional support team for personalized assistance. 📞",
          quickReplies: ['WhatsApp Support', 'Call Support', 'Main Menu'],
        );
        return;
      }

      if (text == 'Main Menu' || lowercaseText.contains('menu')) {
        _addBotMessage(
          "Back to main menu. How else can I help?",
          quickReplies: [
            'Vision Test Help',
            'Understanding Results',
            'Account Help',
            'Talk to Human',
          ],
        );
        return;
      }

      if (text == 'WhatsApp Support') {
        _launchWhatsApp();
        return;
      }
      if (text == 'Call Support') {
        _launchCall();
        return;
      }

      // Dynamic Response for unknown queries
      _addBotMessage(
        "I'm not quite sure I understand that query yet. 🧠\n\nWould you like to try one of these common topics or talk to a human?",
        quickReplies: [
          'Vision Test Help',
          'Technical Failures',
          'Talk to Human',
        ],
      );
    });
  }

  void _showBugReportDialog() {
    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const BugReportDialog(),
      );
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri uri = Uri.parse('https://wa.me/91$_supportNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchCall() async {
    final Uri uri = Uri(scheme: 'tel', path: _supportNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.scaffoldBackground,
      appBar: _buildPremiumAppBar(context),
      body: Stack(
        children: [
          // Background Design Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.primary.withValues(alpha: 0.03),
              ),
            ),
          ),

          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isLast = index == _messages.length - 1;
                    return Column(
                          crossAxisAlignment: message.isUser
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            _buildMessageBubble(message),
                            if (isLast &&
                                !message.isUser &&
                                message.quickReplies != null)
                              _buildChatSuggestions(message.quickReplies!),
                          ],
                        )
                        .animate()
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, curve: Curves.easeOutQuad);
                  },
                ),
              ),
            ],
          ),

          // Floating Input Area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingInputArea(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildPremiumAppBar(BuildContext context) {
    return AppBar(
      toolbarHeight: 80,
      backgroundColor: context.surface,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: context.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 20,
          ),
        ),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.primary.withValues(alpha: 0.1),
                  context.primary.withValues(alpha: 0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: context.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'VisiBot Assistant',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: context.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.shade400.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Ready to help',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: IconButton(
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(
                  ChatMessage(
                    text:
                        "Hi there! 👋 I'm VisiBot, your personalized eye-care assistant.\n\nI can help you with test troubleshooting, understanding results, and technical support. How can I assist you today?",
                    isUser: false,
                    quickReplies: [
                      'Vision Test Help',
                      'Understanding Results',
                      'Account Help',
                      'Report a Bug',
                    ],
                  ),
                );
              });
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.scaffoldBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.refresh_rounded,
                color: context.textSecondary,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              margin: const EdgeInsets.only(right: 8, bottom: 4),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: context.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_rounded,
                color: context.primary,
                size: 16,
              ),
            ),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? LinearGradient(
                        colors: [
                          context.primary,
                          context.primary.withValues(alpha: 0.85),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : context.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(22),
                  topRight: const Radius.circular(22),
                  bottomLeft: Radius.circular(isUser ? 22 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isUser ? context.primary : Colors.black).withValues(
                      alpha: 0.04,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isUser ? Colors.white : context.textPrimary,
                  fontSize: 15,
                  height: 1.5,
                  fontWeight: isUser ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatSuggestions(List<String> suggestions) {
    return Padding(
      padding: const EdgeInsets.only(left: 40, bottom: 24, top: 4),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: suggestions.map((suggestion) {
          return InkWell(
            onTap: () => _addUserMessage(suggestion),
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: context.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: context.primary.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: context.primary.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
              child: Text(
                suggestion,
                style: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ).animate().scale(duration: 200.ms, curve: Curves.easeOut),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFloatingInputArea() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                controller: _messageController,
                onSubmitted: _addUserMessage,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  hintStyle: TextStyle(
                    color: context.textTertiary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _addUserMessage(_messageController.text),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      context.primary,
                      context.primary.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
