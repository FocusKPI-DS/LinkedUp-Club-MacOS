import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';

class ActionItemsWidget extends StatefulWidget {
  const ActionItemsWidget({super.key});

  @override
  State<ActionItemsWidget> createState() => _ActionItemsWidgetState();
}

class _ActionItemsWidgetState extends State<ActionItemsWidget> {
  final Set<String> _completedTasks = {};
  String _selectedFilter = 'pending'; // 'all', 'pending', 'completed'
  final Set<String> _expandedDetails = {};

  @override
  Widget build(BuildContext context) {
    if (currentUserReference == null) {
      return _buildEmptyState();
    }

    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .where('user_ref', isEqualTo: currentUserReference)
            .orderBy('created_time', descending: true)
            .limit(20),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState();
        }

        final allTodos = snapshot.data!;

        // Filter based on selected filter
        List<ActionItemsRecord> filteredTodos;
        if (_selectedFilter == 'completed') {
          filteredTodos = allTodos
              .where((t) =>
                  t.status == 'completed' ||
                  _completedTasks.contains(t.reference.path))
              .toList();
        } else if (_selectedFilter == 'pending') {
          filteredTodos = allTodos
              .where((t) =>
                  t.status == 'pending' &&
                  !_completedTasks.contains(t.reference.path))
              .toList();
        } else {
          filteredTodos = allTodos
              .where((t) => !_completedTasks.contains(t.reference.path))
              .toList();
        }

        // Calculate statistics
        final pending = allTodos
            .where((t) =>
                t.status == 'pending' &&
                !_completedTasks.contains(t.reference.path))
            .length;
        final completed = allTodos
            .where((t) =>
                t.status == 'completed' ||
                _completedTasks.contains(t.reference.path))
            .length;
        final total = allTodos.length;

        return Scaffold(
          backgroundColor: Colors.white,
          body: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  const Text(
                    'Your Action Items',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tasks identified by SummerAI from your group conversations',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Summary Cards
                  _buildSummaryCards(total, pending, completed),

                  const SizedBox(height: 24),

                  // Task List
                  filteredTodos.isEmpty
                      ? _buildEmptyTasksState()
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filteredTodos.length,
                          itemBuilder: (context, index) {
                            final todo = filteredTodos[index];
                            return _buildTodoCard(todo, index);
                          },
                        ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(int total, int pending, int completed) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedFilter = 'all'),
            child: _buildSummaryCard(
              'Total',
              total.toString(),
              Icons.access_time_outlined,
              const Color(0xFF1E293B),
              isSelected: _selectedFilter == 'all',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedFilter = 'pending'),
            child: _buildSummaryCard(
              'Pending',
              pending.toString(),
              Icons.info_outline,
              const Color(0xFF1E293B),
              isSelected: _selectedFilter == 'pending',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedFilter = 'completed'),
            child: _buildSummaryCard(
              'Completed',
              completed.toString(),
              Icons.check_circle_outline,
              const Color(0xFF10B981),
              isHighlighted: true,
              highlightedBackground: const Color(0xFFECFDF5),
              isSelected: _selectedFilter == 'completed',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
      String title, String value, IconData icon, Color color,
      {bool isHighlighted = false,
      Color? highlightedBackground,
      bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSelected
            ? (highlightedBackground ?? color.withOpacity(0.1))
            : (isHighlighted && highlightedBackground != null
                ? highlightedBackground
                : Colors.white),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? color.withOpacity(0.5)
              : (isHighlighted
                  ? color.withOpacity(0.3)
                  : const Color(0xFFE5E7EB)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isHighlighted
                ? color.withOpacity(0.1)
                : const Color(0xFF1F2937).withOpacity(0.04),
            blurRadius: isHighlighted ? 12 : 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Flexible(
                child: Text(
                  value,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                icon,
                color: isHighlighted ? color : const Color(0xFF6B7280),
                size: 28,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodoCard(ActionItemsRecord todo, int index) {
    return Container(
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
              // Priority, Group, Assigned + Due (top row)
              Row(
                children: [
                  _buildPriorityBadge(todo.priority),
                  const SizedBox(width: 8),
                  Expanded(
                    child: (todo.groupName.isNotEmpty || todo.chatRef == null)
                        ? Text(
                            todo.groupName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
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
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              );
                            },
                          ),
                  ),
                  const SizedBox(width: 6),
                  Transform.translate(
                    offset: const Offset(-10, -10),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          DateFormat('MMM dd').format(todo.createdTime!),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.event_available_outlined,
                            size: 12, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 3),
                        Text(
                          todo.dueDate != null
                              ? DateFormat('MMM dd').format(todo.dueDate!)
                              : 'No due',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Task title
              Text(
                todo.title,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Details (people only)
              if (todo.involvedPeople.isNotEmpty)
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 12, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      todo.involvedPeople.join(', '),
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              // (Due date moved to top row)

              const SizedBox(height: 4),

              // Details toggle button
              Align(
                alignment: Alignment.centerRight,
                child: Transform.translate(
                  offset: const Offset(0, -2),
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        final id = todo.reference.id;
                        if (_expandedDetails.contains(id)) {
                          _expandedDetails.remove(id);
                        } else {
                          _expandedDetails.add(id);
                        }
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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

              // Details dropdown
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: _expandedDetails.contains(todo.reference.id)
                    ? Container(
                        key: ValueKey('details-${todo.reference.id}'),
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 2),
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
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          // Checkbox in top right
          Positioned(
            top: -10,
            right: -10,
            child: Checkbox(
              value: todo.status == 'completed' ||
                  _completedTasks.contains(todo.reference.path),
              onChanged: (value) => _handleTaskComplete(todo),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              checkColor: Colors.white,
              fillColor: WidgetStateProperty.resolveWith<Color>(
                (Set<WidgetState> states) {
                  if (states.contains(WidgetState.selected)) {
                    return const Color(0xFF10B981);
                  }
                  return Colors.white;
                },
              ),
            ),
          ),
        ],
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
        label = 'Moderate';
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

  Future<void> _handleTaskComplete(ActionItemsRecord todo) async {
    // Optimistically update local state first
    final taskId = todo.reference.path;
    setState(() {
      _completedTasks.add(taskId);
    });

    try {
      // Update task in Firebase
      await todo.reference.update({
        'status': 'completed',
        'completed_time': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating task: $e');
      // Rollback on error
      setState(() {
        _completedTasks.remove(taskId);
      });
    }
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'No tasks yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tasks from SummerAI will appear here',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTasksState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF9CA3AF)),
            SizedBox(height: 16),
            Text(
              'No tasks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Tasks from SummerAI will appear here',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
