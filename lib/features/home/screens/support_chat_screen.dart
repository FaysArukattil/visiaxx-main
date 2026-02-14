import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visiaxx/core/extensions/theme_extension.dart';

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
  final String _supportNumber = '7208996265';

  @override
  void initState() {
    super.initState();
    _addBotMessage(
      "Hi! 👋 I'm VisiBot, your digital eye care assistant. How can I help you today?",
      quickReplies: [
        'Test Issues',
        'Results & Reports',
        'Account Help',
        'Talk to Human',
      ],
    );
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
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
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
    // Simulated decision tree logic
    Future.delayed(const Duration(seconds: 1), () {
      if (text == 'Test Issues') {
        _addBotMessage(
          "I can help with that. Which test are you having trouble with?",
          quickReplies: [
            'Distance Verification',
            'Visual Acuity',
            'Refractometry',
            'Main Menu',
          ],
        );
      } else if (text == 'Distance Verification') {
        _addBotMessage(
          "Pro Tip: Make sure you are in a well-lit room and stand exactly 1 meter away. The camera needs to see your face clearly.",
          quickReplies: ['Still failing', 'Got it!', 'Main Menu'],
        );
      } else if (text == 'Results & Reports') {
        _addBotMessage(
          "You can find all your scores in the 'My Results' section. Would you like to know how to share them?",
          quickReplies: ['Yes, how to share?', 'How to download?', 'Main Menu'],
        );
      } else if (text == 'Talk to Human' || text == 'Still failing') {
        _addBotMessage(
          "I'll connect you with our support team. You can reach us via WhatsApp or a direct call.",
          quickReplies: ['WhatsApp Support', 'Call Support', 'Main Menu'],
        );
      } else if (text == 'WhatsApp Support') {
        _launchWhatsApp();
      } else if (text == 'Call Support') {
        _launchCall();
      } else {
        _addBotMessage(
          "Is there anything else I can assist you with?",
          quickReplies: [
            'Test Issues',
            'Results & Reports',
            'Account Help',
            'Main Menu',
          ],
        );
      }
    });
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
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Support Chat',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'VisiBot is Online',
                  style: TextStyle(fontSize: 11, color: Colors.green),
                ),
              ],
            ),
          ],
        ),
        backgroundColor: context.surface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          _buildQuickReplies(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width > 600
              ? 450
              : MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isUser ? context.primary : context.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 0),
            bottomRight: Radius.circular(isUser ? 0 : 20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: isUser ? Colors.white : context.textPrimary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    final lastMessage = _messages.isNotEmpty ? _messages.last : null;
    if (lastMessage == null ||
        lastMessage.isUser ||
        lastMessage.quickReplies == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: lastMessage.quickReplies!.map((reply) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ActionChip(
                label: Text(reply),
                onPressed: () => _addUserMessage(reply),
                backgroundColor: context.primary.withValues(alpha: 0.1),
                labelStyle: TextStyle(
                  color: context.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
