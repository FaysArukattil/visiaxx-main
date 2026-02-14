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
      if (text == 'Edit Profile' || text == 'Update Profile') {
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

      // --- Quick reply routing from general test menu ---
      if (text == 'Visual Acuity Test') {
        _handleUserResponse('acuity');
        return;
      }
      if (text == 'Van Herick Shadow Test') {
        _handleUserResponse('shadow');
        return;
      }
      if (text == 'Ishihara Color Vision') {
        _handleUserResponse('ishihara');
        return;
      }
      if (text == 'Mobile Refractometry') {
        _handleUserResponse('refractometry');
        return;
      }
      if (text == 'Stereopsis 3D Test') {
        _handleUserResponse('stereo');
        return;
      }
      if (text == 'Visual Field Test') {
        _handleUserResponse('field');
        return;
      }
      if (text == 'Contrast Sensitivity Test') {
        _handleUserResponse('contrast');
        return;
      }
      if (text == 'Eye Hydration Test') {
        _handleUserResponse('hydration');
        return;
      }
      if (text == 'Amsler Grid Test') {
        _handleUserResponse('amsler');
        return;
      }
      if (text == 'Reading Test') {
        _handleUserResponse('reading test');
        return;
      }
      if (text == 'Torchlight Exam') {
        _handleUserResponse('torchlight');
        return;
      }
      if (text == 'Cover Test') {
        _handleUserResponse('cover');
        return;
      }

      // ══════════════════════════════════════════════════════
      // VISUAL ACUITY
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('acuity')) {
        _addBotMessage(
          "🔬 Visual Acuity Deep Dive:\n\n"
          "Purpose: Measures the sharpness and clarity of your central vision.\n\n"
          "How to take this test:\n"
          "1. Lighting Check - Ensure the room is well-lit so the screen is clearly visible.\n"
          "2. Stand exactly 1 meter (arm + ruler length) from the device.\n"
          "3. How to Respond - Speak the direction of the letter 'E' or tap the matching arrow. You have 10 seconds per letter.\n"
          "4. If you normally wear glasses for distance, keep them on.\n\n"
          "Output: Snellen fraction (e.g., 6/6) or LogMAR score.\n"
          "Why it matters: Vital for detecting myopia, hyperopia, or astigmatism early.",
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
          "📜 Visual Acuity - How to Respond:\n\n"
          "1. 🎤 Voice: Say the direction of the E clearly (e.g. 'Left', 'Right', 'Up', 'Down').\n"
          "2. 🖐️ Touch: Tap the matching direction arrow on screen.\n"
          "3. ⏱️ Timing: You have 10 seconds per letter. If time runs out, the next letter appears automatically.\n"
          "4. 👓 Correction: Keep your glasses on if you wear them for distance.\n\n"
          "Tip: A well-lit room improves accuracy. Avoid shadows on the screen.",
          quickReplies: [
            'Voice Help',
            'Distance Help',
            'Report a Bug',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'Voice Help') {
        _addBotMessage(
          "For voice recognition:\n"
          "- Grant microphone permissions when prompted.\n"
          "- Speak the direction (Left, Right, Up, Down) loudly and clearly.\n"
          "- Avoid noisy environments. Background noise can interfere with detection.",
        );
        return;
      }
      if (text == 'Distance Help') {
        _addBotMessage(
          "To verify the 1 meter distance:\n"
          "- Use the mirror calibration tool in the app.\n"
          "- Arm's length + a ruler is approximately 1 meter.\n"
          "- If the distance check fails, ensure there are no busy backgrounds behind you.",
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // SHADOW TEST / GLAUCOMA
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('shadow') ||
          lowercaseText.contains('van herick') ||
          lowercaseText.contains('glaucoma')) {
        _addBotMessage(
          "👁️ Van Herick Shadow Test Deep Dive:\n\n"
          "Purpose: Screens for narrow-angle Glaucoma risk by assessing the anterior chamber depth.\n\n"
          "How to take this test:\n"
          "1. Remove Specs - Take off glasses or eyewear for measurement accuracy.\n"
          "2. Dim Environment - Find a dimly lit room so the slit light is clearly visible.\n"
          "3. Side Illumination - The phone flash shines from the side of the eye at an angle.\n"
          "4. Look Straight - Keep your gaze fixed straight ahead while the AI captures the shadow.\n\n"
          "Output: Grade 1 (Dangerously Narrow) to Grade 4 (Wide Open).\n"
          "Why it matters: Identifies risk of sudden-onset Glaucoma which can cause permanent vision loss.",
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
          "📸 Shadow Test - How to Respond:\n\n"
          "1. 👓 Remove all eyewear for accurate measurement.\n"
          "2. 🌙 Go to a dimly lit room so the flash slit is clearly visible.\n"
          "3. 🔦 The flash activates automatically from the side of your eye.\n"
          "4. 👁️ Look straight ahead and hold still while the AI captures the shadow pattern.\n\n"
          "Tip: Clean your camera lens for a sharper capture. Hold the phone steady for 2 seconds.",
          quickReplies: ['Common Fails', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Common Fails') {
        _addBotMessage(
          "Common failures in Shadow Test:\n"
          "- Pupil not detected: Room may be too bright. Dim the lights.\n"
          "- Image too blurry: Clean your front camera lens.\n"
          "- Eye not centered: Look directly into the red circle guide.",
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // COLOR VISION / ISHIHARA
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('color') ||
          lowercaseText.contains('ishihara')) {
        _addBotMessage(
          "🎨 Ishihara Color Vision Deep Dive:\n\n"
          "Purpose: Detects Red-Green color vision deficiency using Ishihara plates.\n\n"
          "How to take this test:\n"
          "1. Ishihara Plates - Circular plates with colored dots of different sizes appear on screen.\n"
          "2. Identify the Number - Each plate contains a hidden number. Select the option that matches what you see.\n"
          "3. Hold the device at a comfortable reading distance (about 40cm).\n"
          "4. If you wear distance correction glasses, keep them on.\n\n"
          "Output: Score based on correct identifications (e.g., 10/11).\n"
          "Why it matters: Important for careers requiring color discrimination and understanding daily color perception.",
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
          "🔢 Color Vision - How to Respond:\n\n"
          "1. 👁️ Observe: Look at the circular mosaic plate on screen.\n"
          "2. 🔢 Select: Tap the number option that matches what you see in the plate.\n"
          "3. ❌ Can't See: If you cannot identify any number, select the 'I see nothing' option.\n"
          "4. 👓 Keep your glasses on if you normally wear them.\n\n"
          "Tip: Set screen brightness to maximum. Blue light filters distort Ishihara plate colors.",
          quickReplies: ['Brightness Info', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Brightness Info') {
        _addBotMessage(
          "Low brightness or blue light filters distort the colors of the Ishihara plates, leading to inaccurate results. Always test at full brightness with Night Mode disabled.",
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // MOBILE REFRACTOMETRY
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('refract')) {
        _addBotMessage(
          "👓 Mobile Refractometry Deep Dive:\n\n"
          "Purpose: Estimates your refractive error (spectacle power) for both distance and near vision.\n\n"
          "How to take this test:\n"
          "1. No Eyewear - Remove glasses and contact lenses. This test measures your natural vision.\n"
          "2. Well-lit Room - Ensure the room is well-lit and quiet for accurate results.\n"
          "3. Multi-Distance - You will be tested at 100cm (distance) and 40cm (near).\n"
          "4. Blur Awareness - The 'E' letter may become smaller and blurry. If you can barely see it, say 'Blurry' or tap 'Can't See'.\n"
          "5. Voice Response - Say the direction of the E clearly, or say 'Blurry' if out of focus.\n\n"
          "Output: Diopter values for SPH, CYL, and Axis.\n"
          "Why it matters: Quick prescription estimate from home.",
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
          "🛠️ Refractometry - How to Respond:\n\n"
          "1. 👓 Remove all glasses and contact lenses first.\n"
          "2. 📏 Hold device at 100cm for distance phase, then 40cm for near phase.\n"
          "3. 🎤 Say the direction of the 'E' clearly (Left, Right, Up, Down).\n"
          "4. 🌫️ If the letter is too blurry to read, say 'Blurry' or tap 'Can't See'.\n\n"
          "Tip: The E gets progressively smaller. It's OK if you can't read the smallest ones!",
          quickReplies: ['Capture Help', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'Capture Help') {
        _addBotMessage(
          "If you're having trouble:\n"
          "- Check that the room is well-lit.\n"
          "- Ensure you removed your glasses/contacts.\n"
          "- Hold the device steady at the specified distance.\n"
          "- Speak the direction clearly, or tap the matching arrow.",
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // STEREOPSIS 3D TEST
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('stereo') ||
          lowercaseText.contains('3d test') ||
          lowercaseText.contains('depth perception')) {
        _addBotMessage(
          "🕶️ Stereopsis 3D Test Deep Dive:\n\n"
          "Purpose: Evaluates depth perception (binocular vision) by measuring how well your eyes work together.\n\n"
          "How to take this test:\n"
          "1. 3D Glasses - Put on the red-blue anaglyph glasses. Red lens goes over your LEFT eye, blue over your RIGHT eye.\n"
          "2. 40cm Distance - Position yourself about 40cm (arm's length) from the screen for optimal 3D effect.\n"
          "3. 3D or Flat? - You will see 5 different images. For each, tap '3D' if you perceive depth, or 'FLAT' if it looks like a normal 2D image.\n\n"
          "Output: Depth sensitivity measured in Seconds of Arc.\n"
          "Why it matters: Essential for sports, driving, and overall binocular vision health.",
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
          "📦 Stereopsis - How to Respond:\n\n"
          "1. 🕶️ Wear the red-blue glasses (Red = LEFT eye, Blue = RIGHT eye).\n"
          "2. 📏 Hold device at 40cm (arm's length).\n"
          "3. 👁️ Look at each image. If it appears to 'pop out' in 3D, tap '3D'.\n"
          "4. 📸 If the image looks flat/normal, tap 'FLAT'.\n"
          "5. You'll see 5 images total with varying depth levels.\n\n"
          "Tip: Give each image 3-5 seconds for the 3D effect to settle in.",
          quickReplies: ['No Glasses?', 'Report a Bug', 'Main Menu'],
        );
        return;
      }
      if (text == 'No Glasses?') {
        _addBotMessage(
          "Without red-blue anaglyph glasses, you cannot perceive the 3D depth in this test. You can still answer 'FLAT' for each image, but it won't accurately measure your stereopsis.",
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // VISUAL FIELD
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('field') ||
          lowercaseText.contains('peripheral')) {
        _addBotMessage(
          "📡 Visual Field Deep Dive:\n\n"
          "Purpose: Maps your peripheral (side) vision to detect blind spots (scotomas).\n\n"
          "How to take this test:\n"
          "1. Fixed Gaze - Keep your eyes fixed on the center white plus icon throughout the test. Do not look at the dots directly.\n"
          "2. Detect Dots - Faint dots will appear in your peripheral vision. Tap the bottom area immediately when you see one.\n"
          "3. Each eye is tested separately (left eye first, then right).\n\n"
          "Output: A sensitivity map showing any areas of vision loss.\n"
          "Why it matters: Critical for spotting early signs of Glaucoma or neurological issues.",
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
          "📡 Visual Field - How to Respond:\n\n"
          "1. 🎯 Fixate: Keep your eyes strictly on the center white plus icon. Don't look away.\n"
          "2. 👁️ Detect: Faint dots appear randomly in your side vision.\n"
          "3. 👆 Tap: Tap the bottom area of the screen the instant you see a dot.\n"
          "4. 🔄 Both Eyes: Cover your left eye first (to test right eye), then switch.\n\n"
          "Tip: Don't move your eyes to look at the dots directly - use your peripheral vision!",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // AMSLER GRID
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('amsler') ||
          lowercaseText.contains('macular') ||
          lowercaseText.contains('distortion')) {
        _addBotMessage(
          "📐 Amsler Grid Deep Dive:\n\n"
          "Purpose: Checks for distortions, wavy lines, or blank spots in your central vision (macular health).\n\n"
          "How to take this test:\n"
          "1. The Amsler Grid - A grid of lines appears on screen. This tests for visual distortions.\n"
          "2. Keep Eye on Center - Focus purely on the central black dot. Do not look away during the test.\n"
          "3. Trace Distortions - If any lines look wavy, broken, or missing, trace them on the screen with your finger.\n"
          "4. If you wear distance correction glasses, keep them on.\n\n"
          "Output: Areas of visual distortion indicating potential macular issues.\n"
          "Why it matters: Early detection of Age-related Macular Degeneration (AMD) and other retinal conditions.",
          quickReplies: [
            'How to Respond (Amsler)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Amsler)') {
        _addBotMessage(
          "📐 Amsler Grid - How to Respond:\n\n"
          "1. 🎯 Focus: Look only at the central black dot. Do not scan the rest of the grid.\n"
          "2. 👁️ Observe: Notice if any lines appear wavy, broken, distorted, or missing.\n"
          "3. ✏️ Draw: Use your finger to trace over any distorted areas on the touchscreen.\n"
          "4. 👓 Keep your glasses on if you normally wear them.\n\n"
          "Tip: Test each eye separately for the most accurate results.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // EYE HYDRATION / BLINK
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('hydration') ||
          lowercaseText.contains('blink') ||
          lowercaseText.contains('dry eye')) {
        _addBotMessage(
          "💧 Eye Hydration Deep Dive:\n\n"
          "Purpose: Screens for Dry Eye syndrome by monitoring your natural blink frequency.\n\n"
          "How to take this test:\n"
          "1. Position Face - Hold your device about 40cm from your eyes. Ensure your entire face is visible on screen.\n"
          "2. Ensure Good Lighting - Well-lit environment helps the camera detect your blinks accurately.\n"
          "3. Read Naturally - Simply blink as you normally would. Don't force blinks. The camera tracks them automatically.\n\n"
          "Output: Blink rate and eye surface hydration score.\n"
          "Why it matters: Digital eye strain leads to low blink rates and dry eye discomfort.",
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
          "💧 Eye Hydration - How to Respond:\n\n"
          "1. 🤳 Hold device at 40cm. Ensure your face is fully visible in the camera preview.\n"
          "2. 💡 Good lighting helps the camera detect blinks.\n"
          "3. 😌 Just blink naturally while the timer counts down. Don't force blinks.\n"
          "4. The camera detects each blink automatically.\n\n"
          "Tip: Look at the screen naturally, as if reading a book.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // CONTRAST SENSITIVITY (PELLI-ROBSON)
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('contrast') ||
          lowercaseText.contains('pelli')) {
        _addBotMessage(
          "👁️ Contrast Sensitivity (Pelli-Robson) Deep Dive:\n\n"
          "Purpose: Measures your ability to distinguish objects from their background.\n\n"
          "How to take this test:\n"
          "1. Maximum Brightness - Turn screen brightness to 100% for accurate measurements.\n"
          "2. Test Distance - Hold device at 40cm (short test) or sit 1 meter away (long test).\n"
          "3. Reading Triplets - Groups of 3 letters appear. Read whichever letters are inside the blue highlight box.\n"
          "4. Declining Contrast - Letters become fainter after each set. Read as many as you can until they're invisible.\n"
          "5. No Longer Visible - Tap 'Not Visible' when you can no longer see the letters.\n"
          "6. If you wear distance correction glasses, keep them on.\n\n"
          "Output: Contrast threshold percentage.\n"
          "Why it matters: Crucial for night driving, reading in low light, and early Cataract/Glaucoma detection.",
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
          "👁️ Contrast - How to Respond:\n\n"
          "1. 🔆 Set brightness to maximum first.\n"
          "2. 📖 Read the 3 letters inside the blue highlighted box from left to right.\n"
          "3. 📉 Each set gets fainter. Keep reading as long as you can see them.\n"
          "4. 👁️ When you can no longer distinguish the letters, tap 'Not Visible'.\n"
          "5. 👓 Keep your glasses on if you normally wear them.\n\n"
          "Tip: Don't squint or lean forward. Maintain the required distance throughout.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // READING TEST
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('reading')) {
        _addBotMessage(
          "📖 Reading Test Deep Dive:\n\n"
          "Purpose: Assesses your near vision acuity by testing how well you can read text at close distance.\n\n"
          "How to take this test:\n"
          "1. Optimal Position - Hold the device at about 40cm (arm's length) from your eyes. Keep both eyes open.\n"
          "2. Read Aloud - A sentence will appear on screen. Read it aloud clearly for the clinician or yourself.\n"
          "3. Identify Result - Tap 'CAN READ' if the text is clear, or 'CANNOT READ' if it's too blurry or small.\n\n"
          "Output: Near vision acuity score.\n"
          "Why it matters: Detects presbyopia and near-vision problems common after age 40.",
          quickReplies: [
            'How to Respond (Reading)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Reading)') {
        _addBotMessage(
          "📖 Reading Test - How to Respond:\n\n"
          "1. 📏 Hold device at 40cm (arm's length). Keep both eyes open.\n"
          "2. 🗣️ Read the displayed sentence aloud clearly and completely.\n"
          "3. ✅ Tap 'CAN READ' if you could read it comfortably.\n"
          "4. ❌ Tap 'CANNOT READ' if the text was too blurry or too small.\n"
          "5. Text size decreases with each round.\n\n"
          "Tip: Use your normal reading glasses if you have them.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // COVER TEST
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('cover') &&
          !lowercaseText.contains('discover')) {
        _addBotMessage(
          "🙈 Cover Test Deep Dive:\n\n"
          "Purpose: Detects eye misalignment (Strabismus/Squint) by observing eye movement when one eye is covered.\n\n"
          "How to take this test:\n"
          "1. Overview & Setup - Hold the device at eye level. Ensure the patient's face is well-lit and centered in the camera.\n"
          "2. Clinical Procedure - Cover one eye at a time and observe whether the uncovered eye moves to re-fixate.\n"
          "3. The app's AI tracks eye position during covering and uncovering.\n\n"
          "Output: Detection of tropia (manifest squint) or phoria (latent squint).\n"
          "Why it matters: Identifies functional eye alignment issues that can affect depth perception and cause eye strain.",
          quickReplies: [
            'How to Respond (Cover)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Cover)') {
        _addBotMessage(
          "🙈 Cover Test - How to Respond:\n\n"
          "1. 📱 Hold device at eye level with the patient's face centered.\n"
          "2. 💡 Ensure good lighting on the patient's face.\n"
          "3. 🙈 Follow on-screen animations showing when to cover/uncover each eye.\n"
          "4. 👁️ Watch for the uncovered eye moving to fixate - this indicates misalignment.\n\n"
          "Tip: This is an observation-based test. The camera does the tracking automatically.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // TORCHLIGHT EXAMINATION
      // ══════════════════════════════════════════════════════
      if (lowercaseText.contains('torch') ||
          lowercaseText.contains('pupil') ||
          lowercaseText.contains('rapd')) {
        _addBotMessage(
          "🔦 Torchlight Examination Deep Dive:\n\n"
          "Purpose: Checks pupil reactions (RAPD/Marcus Gunn) and eye muscle range of motion.\n\n"
          "How to take this test:\n"
          "1. Dim Environment - Find a dimly lit room. Ensure your phone's flashlight is functional. Maintain ~40cm distance.\n"
          "2. Scanning Reflexes - The examiner performs the swinging light test to observe pupil size and reactions.\n"
          "3. Follow Practitioner - Look directly at the camera/practitioner. Keep your head still while the examiner moves a light to test eye movements.\n\n"
          "Output: Pupil reaction assessment and extraocular muscle evaluation.\n"
          "Why it matters: Detects nerve damage, optic neuritis, and eye muscle weakness.",
          quickReplies: [
            'How to Respond (Torch)',
            'Report a Bug',
            'WhatsApp Support',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Torch)') {
        _addBotMessage(
          "🔦 Torchlight - How to Respond:\n\n"
          "1. 🌙 Find a dimly lit room so pupils are naturally dilated.\n"
          "2. 📏 Maintain about 40cm distance from the device.\n"
          "3. 👁️ Look directly at the practitioner or camera.\n"
          "4. 🤫 Keep your head completely still during the examination.\n"
          "5. The examiner moves the light - you just follow instructions.\n\n"
          "Tip: This test is practitioner-led. Simply follow the on-screen guidance.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // ══════════════════════════════════════════════════════
      // SCREENING EXAMS (Combined Cover + Torchlight shortcut)
      // ══════════════════════════════════════════════════════
      if (text == 'Other Tests' || text == 'Screening Exams') {
        _addBotMessage(
          "🩺 More Tests Available:\n\n"
          "We have several additional tests. Which one interests you?",
          quickReplies: [
            'Cover Test',
            'Torchlight Exam',
            'Amsler Grid Test',
            'Reading Test',
            'Eye Hydration Test',
            'Main Menu',
          ],
        );
        return;
      }
      if (text == 'How to Respond (Screening)') {
        _addBotMessage(
          "🩺 Screening Exams - How to Respond:\n\n"
          "1. 🔦 Torchlight: Look straight ahead as a light source passes over your eyes. Keep head still.\n"
          "2. 🙈 Cover Test: Look at the device camera while one eye is covered/uncovered.\n"
          "3. These are observation-based tests guided by on-screen animations.\n\n"
          "Tip: Good lighting and a steady position give the most reliable results.",
          quickReplies: ['Report a Bug', 'Main Menu'],
        );
        return;
      }

      // 4. General Vision Tests Troubleshooting (Catch-all)
      if (lowercaseText.contains('test') ||
          lowercaseText.contains('vision') ||
          lowercaseText.contains('help')) {
        _addBotMessage(
          "Our clinical suite includes 15+ specialized tests. Which one would you like to learn about?\n\n"
          "Selecting a test will show you exact steps, distances, and tips to ensure accuracy.",
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

      // 5. Results & Reports
      if (lowercaseText.contains('result') ||
          lowercaseText.contains('report') ||
          lowercaseText.contains('pdf') ||
          lowercaseText.contains('share')) {
        _addBotMessage(
          "📋 Results & Clinical Reports:\n\n"
          "- Visit 'My Results' to see your full test history.\n"
          "- Open any report to generate a Clinical PDF.\n"
          "- Use the share icon in the report view to send it via WhatsApp or Email.",
          quickReplies: ['Missing Report?', 'How to Share', 'Main Menu'],
        );
        return;
      }
      if (text == 'Missing Report?') {
        _addBotMessage(
          "If a report is missing:\n"
          "- Ensure you completed the entire test.\n"
          "- Check if you were logged in during the test.\n"
          "- Try refreshing the 'My Results' screen.",
        );
        return;
      }
      if (text == 'How to Share') {
        _addBotMessage(
          "To share a report:\n"
          "1. Open your test result.\n"
          "2. Tap the 'Share' or 'PDF' icon at the top.\n"
          "3. Choose your preferred app (WhatsApp, Email, etc.).",
        );
        return;
      }

      // 6. Conversational & Escalation
      if (lowercaseText.contains('hi') ||
          lowercaseText.contains('hello') ||
          lowercaseText.contains('hey')) {
        _addBotMessage(
          "Hello! I'm here to help with your vision tests. What would you like to know?",
          quickReplies: [
            'Vision Test Help',
            'Understanding Results',
            'Account Help',
            'Talk to Human',
          ],
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
