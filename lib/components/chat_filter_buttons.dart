import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
          ],
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? CupertinoColors.systemBlue
              : Color(0xFFF2F2F7),
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
    );
  }
}
