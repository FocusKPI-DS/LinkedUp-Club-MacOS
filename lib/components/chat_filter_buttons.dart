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
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: _FilterButton(
                  label: 'All',
                  isSelected: selectedFilter == 'All',
                  onTap: () => chatController.updateChatFilter('All'),
                ),
              ),
              Expanded(
                child: _FilterButton(
                  label: 'Unread',
                  isSelected: selectedFilter == 'Unread',
                  onTap: () => chatController.updateChatFilter('Unread'),
                ),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        margin: const EdgeInsets.all(3.0),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6.0),
          border: isSelected
              ? Border.all(color: Color(0xFFE5E7EB), width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Color.fromRGBO(0, 0, 0, 0.05),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.0,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
