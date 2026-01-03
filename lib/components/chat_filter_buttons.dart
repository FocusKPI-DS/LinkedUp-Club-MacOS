import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:get/get.dart';
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                // Liquid Glass effect with semi-transparent background
                color: isSelected
                    ? CupertinoColors.systemBlue.withOpacity(0.96)
                    : CupertinoColors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isSelected
                      ? CupertinoColors.systemBlue.withOpacity(0.96)
                      : CupertinoColors.white.withOpacity(0.8),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    spreadRadius: 0,
                  ),
                ],
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
