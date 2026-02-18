import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../extensions/theme_extension.dart';
import '../../features/home/screens/support_chat_screen.dart';

/// A premium glassmorphic floating button for chat support
class GlassChatButton extends StatefulWidget {
  const GlassChatButton({super.key});

  @override
  State<GlassChatButton> createState() => _GlassChatButtonState();
}

class _GlassChatButtonState extends State<GlassChatButton> {
  bool _isHovered = false;

  void _navigateToSupport() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SupportChatScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: _navigateToSupport,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          transform: Matrix4.diagonal3Values(
            _isHovered ? 1.05 : 1.0,
            _isHovered ? 1.05 : 1.0,
            1.0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.isDarkMode
                      ? Colors.white.withValues(alpha: 0.12)
                      : context.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.primary.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                child: Center(
                  child:
                      Icon(
                            Icons.support_agent_rounded,
                            color: context.primary,
                            size: 22,
                          )
                          .animate(onPlay: (controller) => controller.repeat())
                          .shimmer(
                            duration: 3.seconds,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
