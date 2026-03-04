import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '/pages/desktop_chat/chat_controller.dart';

class ChatFilterButtons extends StatelessWidget {
  const ChatFilterButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final chatController = Get.find<ChatController>();

    return Obx(() {
      final selectedFilter = chatController.chatFilter.value;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _FilterButton(
                label: 'All',
                isSelected: selectedFilter == 'All',
                onTap: () => chatController.updateChatFilter('All'),
              ),
              const SizedBox(width: 8.0),
              _FilterButton(
                label: 'Unread',
                isSelected: selectedFilter == 'Unread',
                onTap: () => chatController.updateChatFilter('Unread'),
              ),
              const SizedBox(width: 8.0),
              _FilterButton(
                label: 'DM',
                isSelected: selectedFilter == 'DM',
                onTap: () => chatController.updateChatFilter('DM'),
              ),
              const SizedBox(width: 8.0),
              _FilterButton(
                label: 'Groups',
                isSelected: selectedFilter == 'Groups',
                onTap: () => chatController.updateChatFilter('Groups'),
              ),
              const SizedBox(width: 8.0),
              _FilterButton(
                label: 'Service',
                isSelected: selectedFilter == 'Service',
                onTap: () => chatController.updateChatFilter('Service'),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return LiquidStretch(
      stretch: 0.5,
      interactionScale: 1.05,
      child: GlassGlow(
        glowColor: isSelected
            ? CupertinoColors.systemBlue.withOpacity(0.3)
            : Colors.white24,
        glowRadius: 1.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(20.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                // Fully opaque white background with liquid glass tap effects
                color: isSelected
                    ? CupertinoColors.systemBlue
                    : Colors.white, // Fully opaque white
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? CupertinoColors.white
                      : CupertinoColors.systemBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
