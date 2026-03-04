import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/backend.dart';

class ActionItemCard extends StatelessWidget {
  const ActionItemCard({
    super.key,
    required this.todo,
    required this.isCompleting,
    required this.progress,
    required this.isExpanded,
    required this.displayCompleted,
    required this.checkboxEnabled,
    required this.onToggleExpanded,
    required this.onToggleComplete,
    required this.onEdit,
    this.onDelete,
  });

  final ActionItemsRecord todo;
  final bool isCompleting;
  final double? progress;
  final bool isExpanded;
  final bool displayCompleted;
  final bool checkboxEnabled;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onToggleComplete;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    double opacity = 1.0;
    if (isCompleting && progress != null && progress! > 0.5) {
      opacity = 1.0 - (((progress! - 0.5) / 0.5));
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 50),
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F2937).withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: priority + group name + dates (Todo AI style)
                Row(
                  children: [
                    _buildPriorityBadge(todo.priority),
                    const SizedBox(width: 8),
                    Flexible(
                      child: (todo.groupName.isNotEmpty || todo.chatRef == null)
                          ? Text(
                              todo.groupName,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : StreamBuilder<ChatsRecord>(
                              stream: ChatsRecord.getDocument(todo.chatRef!),
                              builder: (context, chatSnap) {
                                final name = chatSnap.data?.title ?? '';
                                return Text(
                                  name,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF334155),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM dd').format(todo.createdTime!),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          '•',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.event_available_outlined,
                          size: 14,
                          color: Color(0xFF475569),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          todo.dueDate != null
                              ? DateFormat('MMM dd').format(todo.dueDate!)
                              : 'No due',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 6),

                // Title
                Text(
                  todo.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    decoration: todo.status == 'completed'
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 2),

                if (todo.involvedPeople.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.people_outline,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          todo.involvedPeople.join(', '),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 4),

                // Details toggle
                Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: const Offset(-2, -8),
                    child: TextButton(
                      onPressed: onToggleExpanded,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Details',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Details dropdown (no flicker; maintain state)
                Visibility(
                  visible: isExpanded,
                  maintainState: true,
                  maintainAnimation: true,
                  maintainSize: false,
                  child: Container(
                    key: ValueKey('details-${todo.reference.id}'),
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 0),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      (todo.description).isNotEmpty
                          ? todo.description
                          : 'No details available',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF334155),
                        height: 1.35,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Edit button (requested to keep on this page)
                Align(
                  alignment: Alignment.centerRight,
                  child: Material(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Edit',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Progress bar overlay when completing
            if (isCompleting)
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: LinearProgressIndicator(
                    value: progress, // null => indeterminate
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 3,
                  ),
                ),
              ),

            // Checkbox and Delete button
            Positioned(
              top: -10,
              right: -10,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Delete button
                  if (onDelete != null)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onDelete,
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline,
                            size: 16,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null) const SizedBox(width: 6),
                  // Checkbox
                  Checkbox(
                    value: displayCompleted && !isCompleting,
                    onChanged: checkboxEnabled
                        ? (v) => onToggleComplete(v ?? false)
                        : null,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    checkColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFF9CA3AF),
                      width: 2,
                    ),
                    fillColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return const Color(0xFF10B981);
                      }
                      return Colors.white;
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bgColor;
    Color textColor;
    String label;

    switch (priority.toLowerCase()) {
      case 'urgent':
        bgColor = const Color(0xFFFEF2F2);
        textColor = const Color(0xFFDC2626);
        label = 'Urgent';
        break;
      case 'high':
        bgColor = const Color(0xFFFFF7ED);
        textColor = const Color(0xFFF97316);
        label = 'High';
        break;
      case 'medium':
        bgColor = const Color(0xFFFEFCE8);
        textColor = const Color(0xFFEAB308);
        label = 'Medium';
        break;
      case 'moderate':
        bgColor = const Color(0xFFFEFCE8);
        textColor = const Color(0xFFEAB308);
        label = 'Moderate';
        break;
      case 'low':
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF3B82F6);
        label = 'Low';
        break;
      default:
        bgColor = const Color(0xFFEFF6FF);
        textColor = const Color(0xFF3B82F6);
        label = 'Low';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
