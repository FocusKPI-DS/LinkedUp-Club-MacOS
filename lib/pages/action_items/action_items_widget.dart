import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import '/custom_code/widgets/action_item_card.dart';

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

    return _buildActionItemsStream(
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
                            final isExpanded =
                                _expandedDetails.contains(todo.reference.id);
                            final displayCompleted =
                                todo.status == 'completed' ||
                                    _completedTasks.contains(todo.reference.path);

                            return ActionItemCard(
                              key: ValueKey(todo.reference.id),
                              todo: todo,
                              isCompleting: false,
                              progress: null,
                              isExpanded: isExpanded,
                              displayCompleted: displayCompleted,
                              checkboxEnabled: true,
                              onToggleExpanded: () {
                                setState(() {
                                  final id = todo.reference.id;
                                  if (_expandedDetails.contains(id)) {
                                    _expandedDetails.remove(id);
                                  } else {
                                    _expandedDetails.add(id);
                                  }
                                });
                              },
                              onToggleComplete: (value) {
                                if (value) _handleTaskComplete(todo);
                              },
                              onEdit: () => _showEditDialog(todo),
                              onDelete: () => _handleDeleteTask(todo),
                            );
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

  Widget _buildActionItemsStream({
    required Widget Function(
      BuildContext context,
      AsyncSnapshot<List<ActionItemsRecord>> snapshot,
    ) builder,
  }) {
    if (useWindowsFirestoreRest) {
      return RestPollBuilder<List<ActionItemsRecord>>(
        interval: const Duration(seconds: 20),
        fetch: () => fsQueryActionItemsByUser(
          currentUserReference!,
          limit: 20,
        ),
        builder: builder,
      );
    }
    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .where('user_ref', isEqualTo: currentUserReference)
            .orderBy('created_time', descending: true)
            .limit(20),
      ),
      builder: builder,
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

  Future<void> _handleTaskComplete(ActionItemsRecord todo) async {
    // Optimistically update local state first
    final taskId = todo.reference.path;
    setState(() {
      _completedTasks.add(taskId);
    });

    try {
      await fsMarkActionItemDone(todo.reference);
    } catch (e) {
      print('Error updating task: $e');
      // Rollback on error
      setState(() {
        _completedTasks.remove(taskId);
      });
    }
  }

  Future<void> _handleDeleteTask(ActionItemsRecord todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Task',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${todo.title}"? This action cannot be undone.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Inter',
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Delete',
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await fsDeleteMatchingActionItems(todo);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(ActionItemsRecord todo) async {
    final titleController = TextEditingController(text: todo.title);
    final validPriorities = ['low', 'medium', 'high', 'urgent'];
    final priorityValue = todo.priority.isNotEmpty
        ? todo.priority.toLowerCase()
        : 'low';
    String selectedPriority =
        validPriorities.contains(priorityValue) ? priorityValue : 'low';
    DateTime? selectedDueDate = todo.dueDate;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Edit Task',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter task title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                              color: Color(0xFF3B82F6),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedPriority,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: validPriorities
                            .map(
                              (p) => DropdownMenuItem(
                                value: p,
                                child: Text(
                                  p[0].toUpperCase() + p.substring(1),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedPriority = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      selectedDueDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2100),
                                );
                                if (picked != null) {
                                  setDialogState(() => selectedDueDate = picked);
                                }
                              },
                              icon: const Icon(Icons.calendar_today_outlined),
                              label: Text(
                                selectedDueDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(selectedDueDate!)
                                    : 'Set due date',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: selectedDueDate == null
                                ? null
                                : () => setDialogState(
                                      () => selectedDueDate = null,
                                    ),
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;

                    try {
                      await fsPatchDocument(todo.reference, {
                        'title': title,
                        'priority': selectedPriority,
                        'due_date': selectedDueDate,
                      });
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error updating task: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    'Save',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
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
