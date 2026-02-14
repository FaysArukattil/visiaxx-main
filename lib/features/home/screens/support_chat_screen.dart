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

      // 3. Vision Tests Troubleshooting
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

      // Specific Test Knowledge (Detailed)
      if (lowercaseText.contains('acuity')) {
        _addBotMessage(
          "🔭 Visual Acuity Test Pro-Tips:\n\n1. Use a well-lit room (natural light is best).\n2. Stand exactly 1 meter (3.3 feet) from the phone.\n3. Keep the phone at eye level.\n4. If using voice, speak clearly when you see the letter.",
          quickReplies: ['Voice Help', 'Distance Help', 'Main Menu'],
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

      if (lowercaseText.contains('shadow') ||
          lowercaseText.contains('glaucoma')) {
        _addBotMessage(
          "👁️ Van Herick Shadow Test Calibration:\n\nThis test measures the shadow on your iris to screen for Glaucoma risk.\n\n- Hold your phone steady with both hands.\n- Avoid strong overhead lighting that creates 'star' glares on the iris.\n- Ensure the circular guide covers your pupil perfectly.",
          quickReplies: ['Common Fails', 'Main Menu'],
        );
        return;
      }
      if (text == 'Common Fails') {
        _addBotMessage(
          "Common failures in Shadow Test:\n- Pupil not detected: Improve room lighting.\n- Image too blurry: Clean your front camera lens.\n- Eye not centered: Look directly into the red circle.",
        );
        return;
      }

      if (lowercaseText.contains('color') ||
          lowercaseText.contains('ishihara')) {
        _addBotMessage(
          "🎨 Ishihara Color Vision Rules:\n\n- Set screen brightness to 100%.\n- Turn off Blue Light Filter or Night Shift.\n- Do not wear tinted glasses or sunglasses during this test.",
          quickReplies: ['Brightness Info', 'Main Menu'],
        );
        return;
      }
      if (text == 'Brightness Info') {
        _addBotMessage(
          "Low brightness or blue light filters distort the colors of the Ishihara plates, leading to inaccurate results. Always test at full brightness.",
        );
        return;
      }

      if (lowercaseText.contains('refractometry')) {
        _addBotMessage(
          "👓 Mobile Refractometry Guide:\n\n- This test calculates your power (Sph/Cyl).\n- REMOVE your glasses/lenses before starting.\n- Keep the phone perfectly vertical.\n- Ensure your eyes are wide open during the capture pulse.",
          quickReplies: ['Capture Help', 'Main Menu'],
        );
        return;
      }
      if (text == 'Capture Help') {
        _addBotMessage(
          "If the capture fails:\n- Ensure the red line is centered on your pupil.\n- Hold the phone at 30cm distance.\n- Use a mirror if you have trouble aligning yourself.",
        );
        return;
      }

      if (lowercaseText.contains('stereo')) {
        _addBotMessage(
          "🕶️ Stereopsis 3D Test Help:\n\nThis test requires Red/Cyan Anaglyph glasses. If you don't have them, the shapes will remain flat. Ensure you follow the distance calibration carefully.",
          quickReplies: ['No Glasses?', 'Main Menu'],
        );
        return;
      }
      if (text == 'No Glasses?') {
        _addBotMessage(
          "Without Red/Cyan glasses, you cannot perceive the 3D depth of this test. You can still select 'I see flat', but it won't accurately measure stereopsis.",
        );
        return;
      }

      if (lowercaseText.contains('field') ||
          lowercaseText.contains('amsler') ||
          lowercaseText.contains('peripheral')) {
        _addBotMessage(
          "📡 Visual Field & Amsler Grid Test:\n\n- Fix your gaze strictly on the center dot.\n- Do not move your eyes to look for the flashing lights.\n- Tap the screen as soon as you perceive a flash in your side-vision.",
          quickReplies: ['Main Menu'],
        );
        return;
      }

      if (lowercaseText.contains('hydration') ||
          lowercaseText.contains('blink')) {
        _addBotMessage(
          "💧 Eye Hydration Test (Dry Eye):\n\nThe AI detects your blink frequency. Ensure your face is centered and the lighting is sufficient to see your eyes clearly. Avoid heavy makeup for better detection accuracy.",
        );
        return;
      }

      if (lowercaseText.contains('contrast')) {
        _addBotMessage(
          "👁️ Contrast Sensitivity Test:\n\nThis test measures how well you can distinguish between an object and the background behind it. Ensure your screen is clean and you are in a room with stable, non-glaring light.",
          quickReplies: ['Main Menu'],
        );
        return;
      }

      if (text == 'Other Tests') {
        _addBotMessage(
          "We also offer Cover-Uncover Test, Torchlight Examination, and Reading Test. Please follow the on-screen instructions for those specific procedures.",
          quickReplies: ['Main Menu'],
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
