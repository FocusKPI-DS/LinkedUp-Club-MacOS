import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/scheduler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:adaptive_platform_ui/adaptive_platform_ui.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:intl/intl.dart';
import '/custom_code/widgets/action_item_card.dart';
import 'mobile_group_tasks_model.dart';
export 'mobile_group_tasks_model.dart';

class MobileGroupTasksWidget extends StatefulWidget {
  const MobileGroupTasksWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'MobileGroupTasks';
  static String routePath = '/mobileGroupTasks';

  @override
  State<MobileGroupTasksWidget> createState() => _MobileGroupTasksWidgetState();
}

class _MobileGroupTasksWidgetState extends State<MobileGroupTasksWidget> {
  late MobileGroupTasksModel _model;
  final Set<String> _completedTasks = {};
  final Map<String, double?> _completingTasks = {};
  final Set<String> _expandedDetails = {};
  final Map<String, String> _pendingStatusChange = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MobileGroupTasksModel());
    SchedulerBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _handleTaskToggle(
      ActionItemsRecord todo, bool isCompleting) async {
    final taskId = todo.reference.id;

    try {
      if (isCompleting) {
        setState(() {
          _pendingStatusChange[taskId] = 'completed';
          _completingTasks[taskId] = null;
        });

        await todo.reference.update({'status': 'completed'});

        if (mounted) {
          setState(() {
            _completedTasks.add(todo.reference.path);
            _completingTasks.remove(taskId);
            _pendingStatusChange.remove(taskId);
          });
        }
      } else {
        setState(() {
          _pendingStatusChange[taskId] = 'pending';
        });
        await todo.reference.update({'status': 'pending'});

        if (mounted) {
          setState(() {
            _completedTasks.remove(todo.reference.path);
            _pendingStatusChange.remove(taskId);
          });
        }
      }
    } catch (e) {
      print('Error updating task: $e');
      if (mounted && isCompleting) {
        setState(() {
          _completingTasks.remove(taskId);
          _pendingStatusChange.remove(taskId);
        });
      }
    }
  }

  Future<void> _handleDeleteTask(ActionItemsRecord todo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
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

    if (confirmed == true) {
      try {
        final allTasksSnapshot = await ActionItemsRecord.collection
            .where('chat_ref', isEqualTo: todo.chatRef)
            .where('title', isEqualTo: todo.title)
            .get();

        final batch = FirebaseFirestore.instance.batch();
        for (var doc in allTasksSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

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
  }

  void _showEditDialog(ActionItemsRecord todo) {
    // For now, just show a message that editing will be available soon
    // Or navigate to desktop version if needed
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Edit functionality coming soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _showAddNewDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    Set<String> selectedPeople = {};

    // Fetch group members
    final List<UsersRecord> groupMembers = [];
    if (widget.chatDoc?.members != null) {
      for (var memberRef in widget.chatDoc!.members) {
        try {
          final member = await UsersRecord.getDocumentOnce(memberRef);
          groupMembers.add(member);
        } catch (e) {
          print('Error fetching member: $e');
        }
      }
    }

    String selectedPriority = 'low';
    DateTime? selectedDueDate;

    if (currentUserReference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to create action items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final currentUser =
        await UsersRecord.getDocumentOnce(currentUserReference!);
    final workspaceRef =
        widget.chatDoc?.workspaceRef ?? currentUser.currentWorkspaceRef;

    if (!mounted) return;

    return showDialog(
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
                'Create New Task',
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
                      const Text(
                        'Title',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        autofocus: true,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Enter task title',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF3B82F6), width: 2),
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Description (Optional)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Enter task description',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: Color(0xFF3B82F6), width: 2),
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Involved People',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: groupMembers.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No members found',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: groupMembers.length,
                                itemBuilder: (context, index) {
                                  final member = groupMembers[index];
                                  final isSelected = selectedPeople
                                      .contains(member.displayName);

                                  return CheckboxListTile(
                                    dense: true,
                                    title: Text(
                                      member.displayName,
                                      style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        color: Color(0xFF1F2937),
                                      ),
                                    ),
                                    value: isSelected,
                                    checkColor: Colors.white,
                                    fillColor:
                                        WidgetStateProperty.resolveWith<Color>(
                                      (states) {
                                        if (states
                                            .contains(WidgetState.selected)) {
                                          return const Color(0xFF3B82F6);
                                        }
                                        return Colors.transparent;
                                      },
                                    ),
                                    side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFF9CA3AF),
                                      width: 2,
                                    ),
                                    onChanged: (value) {
                                      setDialogState(() {
                                        if (value == true) {
                                          selectedPeople
                                              .add(member.displayName);
                                        } else {
                                          selectedPeople
                                              .remove(member.displayName);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedPriority,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                          ),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            color: Color(0xFF1F2937),
                          ),
                          dropdownColor: Colors.white,
                          icon: const Icon(
                            Icons.arrow_drop_down,
                            color: Color(0xFF6B7280),
                          ),
                          iconSize: 24,
                          menuMaxHeight: 200,
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text(
                                'Low',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'moderate',
                              child: Text(
                                'Moderate',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text(
                                'High',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text(
                                'Urgent',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedPriority = value ?? 'low';
                            });
                          },
                          isExpanded: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Due Date (Optional)',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                selectedDueDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(selectedDueDate!)
                                    : 'No due date',
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate ?? now,
                                firstDate: DateTime(now.year - 5),
                                lastDate: DateTime(now.year + 10),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  selectedDueDate = DateTime(
                                      picked.year, picked.month, picked.day);
                                });
                              }
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: const Text('Pick date'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1F2937),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: selectedDueDate == null
                                ? null
                                : () {
                                    setDialogState(() {
                                      selectedDueDate = null;
                                    });
                                  },
                            icon: const Icon(Icons.clear),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1F2937),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
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
                    if (titleController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a task title'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    if (selectedPeople.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please select at least one person to assign the task to'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    try {
                      final now = DateTime.now();
                      final groupName = widget.chatDoc?.title ?? 'Group';
                      final chatRef = widget.chatDoc?.reference;

                      final batch = FirebaseFirestore.instance.batch();

                      for (String personName in selectedPeople) {
                        UsersRecord? assignedUser;
                        for (var member in groupMembers) {
                          if (member.displayName == personName) {
                            assignedUser = member;
                            break;
                          }
                        }

                        if (assignedUser != null) {
                          final actionItemRef =
                              ActionItemsRecord.collection.doc();

                          final actionItemData = createActionItemsRecordData(
                            title: titleController.text.trim(),
                            groupName: groupName,
                            priority: selectedPriority,
                            status: 'pending',
                            userRef: assignedUser.reference,
                            workspaceRef: workspaceRef,
                            chatRef: chatRef,
                            involvedPeople: selectedPeople.toList(),
                            createdTime: now,
                            lastSummaryAt: now,
                            dueDate: selectedDueDate,
                            description: descriptionController.text.trim(),
                          );

                          batch.set(actionItemRef, actionItemData);
                        }
                      }

                      await batch.commit();

                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Task created successfully!'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating task: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Create',
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
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PlatformInfo.isIOS26OrHigher()
                ? CupertinoIcons.checkmark_circle
                : Icons.check_circle_outline,
            size: 64.0,
            color: PlatformInfo.isIOS26OrHigher()
                ? CupertinoColors.secondaryLabel
                : Colors.grey,
          ),
          const SizedBox(height: 16.0),
          Text(
            'No tasks yet',
            style: PlatformInfo.isIOS26OrHigher()
                ? const TextStyle(
                    fontSize: 17,
                    color: CupertinoColors.secondaryLabel,
                  )
                : const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(height: 8.0),
          Text(
            'Tap + Add to create your first task',
            style: PlatformInfo.isIOS26OrHigher()
                ? const TextStyle(
                    fontSize: 15,
                    color: CupertinoColors.tertiaryLabel,
                  )
                : const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (PlatformInfo.isIOS26OrHigher()) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Custom header with back button matching mobile chat page
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    // Floating back button
                    LiquidStretch(
                      stretch: 0.5,
                      interactionScale: 1.05,
                      child: GlassGlow(
                        glowColor: Colors.white24,
                        glowRadius: 1.0,
                        child: AdaptiveFloatingActionButton(
                          mini: true,
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF007AFF),
                          onPressed: () => context.pop(),
                          child: const Icon(
                            CupertinoIcons.chevron_left,
                            size: 17,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Centered title
                    Expanded(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Tasks',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 56),
                  ],
                ),
              ),
              // Tasks list
              Expanded(
                child: widget.chatDoc == null
                    ? const Center(child: Text('No group selected'))
                    : StreamBuilder<List<ActionItemsRecord>>(
                        stream: queryActionItemsRecord(
                          queryBuilder: (actionItemsRecord) => actionItemsRecord
                              .where('chat_ref',
                                  isEqualTo: widget.chatDoc!.reference)
                              .orderBy('created_time', descending: true)
                              .limit(100),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CupertinoActivityIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          if (!snapshot.hasData || snapshot.data!.isEmpty) {
                            return _buildEmptyState();
                          }

                          final allTodos = snapshot.data!;

                          // Deduplicate tasks by title
                          final Map<String, ActionItemsRecord> uniqueTodos = {};
                          for (var todo in allTodos) {
                            if (!uniqueTodos.containsKey(todo.title)) {
                              uniqueTodos[todo.title] = todo;
                            }
                          }
                          final deduplicatedTodos = uniqueTodos.values.toList();

                          return Column(
                            children: [
                              // Add New Button
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: CupertinoButton(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    color: const Color(0xFF3B82F6),
                                    borderRadius: BorderRadius.circular(8),
                                    onPressed: _showAddNewDialog,
                                    child: const Text(
                                      '+ Add',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Tasks List
                              Expanded(
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16.0),
                                  itemCount: deduplicatedTodos.length,
                                  itemBuilder: (context, index) {
                                    final todo = deduplicatedTodos[index];
                                    final isCompleting = _completingTasks
                                        .containsKey(todo.reference.id);
                                    final progress =
                                        _completingTasks[todo.reference.id];
                                    final isExpanded = _expandedDetails
                                        .contains(todo.reference.id);
                                    final pending =
                                        _pendingStatusChange[todo.reference.id];
                                    final displayCompleted = pending != null
                                        ? (pending == 'completed')
                                        : (_completedTasks.contains(
                                                todo.reference.path) ||
                                            todo.status == 'completed');
                                    final checkboxEnabled =
                                        !isCompleting && pending == null;

                                    return ActionItemCard(
                                      key: ValueKey(todo.reference.id),
                                      todo: todo,
                                      isCompleting: isCompleting,
                                      progress: progress,
                                      isExpanded: isExpanded,
                                      displayCompleted: displayCompleted,
                                      checkboxEnabled: checkboxEnabled,
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
                                      onToggleComplete: (value) =>
                                          _handleTaskToggle(todo, value),
                                      onEdit: () => _showEditDialog(todo),
                                      onDelete: () => _handleDeleteTask(todo),
                                    );
                                  },
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } else {
      // Fallback for older iOS versions
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Tasks',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          elevation: 0,
        ),
        body: widget.chatDoc == null
            ? const Center(child: Text('No group selected'))
            : StreamBuilder<List<ActionItemsRecord>>(
                stream: queryActionItemsRecord(
                  queryBuilder: (actionItemsRecord) => actionItemsRecord
                      .where('chat_ref', isEqualTo: widget.chatDoc!.reference)
                      .orderBy('created_time', descending: true)
                      .limit(100),
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
                  final Map<String, ActionItemsRecord> uniqueTodos = {};
                  for (var todo in allTodos) {
                    if (!uniqueTodos.containsKey(todo.title)) {
                      uniqueTodos[todo.title] = todo;
                    }
                  }
                  final deduplicatedTodos = uniqueTodos.values.toList();

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: _showAddNewDialog,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Add'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: deduplicatedTodos.length,
                          itemBuilder: (context, index) {
                            final todo = deduplicatedTodos[index];
                            final isCompleting =
                                _completingTasks.containsKey(todo.reference.id);
                            final progress =
                                _completingTasks[todo.reference.id];
                            final isExpanded =
                                _expandedDetails.contains(todo.reference.id);
                            final pending =
                                _pendingStatusChange[todo.reference.id];
                            final displayCompleted = pending != null
                                ? (pending == 'completed')
                                : (_completedTasks
                                        .contains(todo.reference.path) ||
                                    todo.status == 'completed');
                            final checkboxEnabled =
                                !isCompleting && pending == null;

                            return ActionItemCard(
                              key: ValueKey(todo.reference.id),
                              todo: todo,
                              isCompleting: isCompleting,
                              progress: progress,
                              isExpanded: isExpanded,
                              displayCompleted: displayCompleted,
                              checkboxEnabled: checkboxEnabled,
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
                              onToggleComplete: (value) =>
                                  _handleTaskToggle(todo, value),
                              onEdit: () => _showEditDialog(todo),
                              onDelete: () => _handleDeleteTask(todo),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
      );
    }
  }
}
