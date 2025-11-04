import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'group_action_tasks_model.dart';
import '/custom_code/widgets/action_item_card.dart';
import '/auth/firebase_auth/auth_util.dart';
export 'group_action_tasks_model.dart';

/// Group Action Tasks Page
class GroupActionTasksWidget extends StatefulWidget {
  const GroupActionTasksWidget({
    super.key,
    required this.chatDoc,
  });

  final ChatsRecord? chatDoc;

  static String routeName = 'GroupActionTasks';
  static String routePath = '/group-action-tasks';

  @override
  State<GroupActionTasksWidget> createState() => _GroupActionTasksWidgetState();
}

class _GroupActionTasksWidgetState extends State<GroupActionTasksWidget> {
  late GroupActionTasksModel _model;
  final Set<String> _completedTasks = {};
  final Map<String, double?> _completingTasks = {};
  final Set<String> _expandedDetails = {};
  final Map<String, String> _pendingStatusChange =
      {}; // id -> 'completed'|'pending'

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GroupActionTasksModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderRadius: 20.0,
            buttonSize: 40.0,
            icon: Icon(
              Icons.arrow_back,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () async {
              context.safePop();
            },
          ),
          title: Text(
            '${widget.chatDoc?.title ?? 'Group'}\'s Action Tasks',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: const [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: widget.chatDoc == null
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
                      return Center(
                        child: Text('Error: ${snapshot.error}'),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return _buildEmptyState();
                    }

                    final allTodos = snapshot.data!;

                    // Deduplicate tasks by title - show only one task per unique title
                    // This prevents duplicate tasks from showing on the group page
                    final Map<String, ActionItemsRecord> uniqueTodos = {};
                    for (var todo in allTodos) {
                      if (!uniqueTodos.containsKey(todo.title)) {
                        uniqueTodos[todo.title] = todo;
                      }
                    }
                    final deduplicatedTodos = uniqueTodos.values.toList();

                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Add New Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: Material(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(6),
                                child: InkWell(
                                  onTap: () => _showAddNewDialog(),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF3B82F6),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      '+ Add',
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
                            const SizedBox(height: 16),

                            // Todo List
                            ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
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
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  // Deprecated: replaced by reusable ActionItemCard
  Widget _buildTodoCard(ActionItemsRecord todo) {
    final isCompleting = _completingTasks.containsKey(todo.reference.id);
    final progress = _completingTasks[todo.reference.id] ?? 0.0;
    final opacity =
        isCompleting && progress > 0.5 ? 1.0 - ((progress - 0.5) / 0.5) : 1.0;

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
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          // Group name (match home/Todo AI styles)
                          Expanded(
                            child: (todo.groupName.isNotEmpty ||
                                    todo.chatRef == null)
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
                                    stream:
                                        ChatsRecord.getDocument(todo.chatRef!),
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
                          const SizedBox(width: 4),
                          // Dates styled like home with bullet separator
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
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Details toggle button (match home/Todo AI)
                Align(
                  alignment: Alignment.topRight,
                  child: Transform.translate(
                    offset: const Offset(-2, -8),
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
                            horizontal: 8, vertical: 2),
                        minimumSize: const Size(0, 0),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF2563EB),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
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
                  duration: const Duration(milliseconds: 150),
                  child: _expandedDetails.contains(todo.reference.id)
                      ? Container(
                          key: ValueKey('details-${todo.reference.id}'),
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.all(12),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF334155),
                              height: 1.35,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                // Match home page: no explicit Edit button below details
                const SizedBox(height: 6),
                const SizedBox(height: 6),
                Text(
                  todo.title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0F172A),
                    decoration: (todo.status == 'completed' ||
                            _completedTasks.contains(todo.reference.path))
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
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
              ],
            ),
            // Progress bar
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
                    value: progress,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 3,
                  ),
                ),
              ),
            // Checkbox
            Positioned(
              top: -10,
              right: -10,
              child: Checkbox(
                value: (todo.status == 'completed' ||
                        _completedTasks.contains(todo.reference.path)) &&
                    !isCompleting,
                onChanged: (value) => _handleTaskToggle(todo, value ?? false),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                checkColor: Colors.white,
                fillColor: WidgetStateProperty.resolveWith<Color>(
                  (states) {
                    if (states.contains(WidgetState.selected)) {
                      return const Color(0xFF10B981);
                    }
                    return Colors.white;
                  },
                ),
              ),
            ),
            // Edit button moved; top-right button removed
          ],
        ),
      ),
    );
  }

  // Deprecated: not used in new card layout
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

  Future<void> _handleTaskToggle(
      ActionItemsRecord todo, bool isCompleting) async {
    final taskId = todo.reference.id;

    try {
      if (isCompleting) {
        // Complete the task with animation
        setState(() {
          _pendingStatusChange[taskId] = 'completed';
          _completingTasks[taskId] = null; // use indeterminate bar
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
        // Uncheck - change status back to pending
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
    // Show confirmation dialog
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
        // Delete ALL task documents with the same chat_ref and title
        // This ensures the task is removed for all involved users
        final allTasksSnapshot = await ActionItemsRecord.collection
            .where('chat_ref', isEqualTo: todo.chatRef)
            .where('title', isEqualTo: todo.title)
            .get();

        // Batch delete all related task documents
        final batch = FirebaseFirestore.instance.batch();
        for (var doc in allTasksSnapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();

        // Show success message
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

  Future<void> _showEditDialog(ActionItemsRecord todo) async {
    final TextEditingController titleController =
        TextEditingController(text: todo.title);

    // Get current involved people
    Set<String> selectedPeople = Set.from(todo.involvedPeople);

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

    // Initialize priority outside builder so it persists
    final String priorityStr = todo.priority;
    final String priorityValue =
        priorityStr.isNotEmpty ? priorityStr.toLowerCase() : 'low';
    final List<String> validPriorities = ['low', 'medium', 'high', 'urgent'];
    final String initialPriority =
        validPriorities.contains(priorityValue) ? priorityValue : 'low';

    // Use a mutable variable to track selected priority
    String selectedPriority = initialPriority;

    // Track selected due date (nullable). Start with current task due date
    DateTime? selectedDueDate = todo.dueDate;

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
                              value: 'medium',
                              child: Text(
                                'Medium',
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
                        'Due Date',
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
                    if (titleController.text.trim().isNotEmpty &&
                        selectedPeople.isNotEmpty) {
                      try {
                        // Update ALL task documents with the same chat_ref and original title
                        // This ensures changes sync across all users' home pages
                        final allTasksSnapshot = await ActionItemsRecord
                            .collection
                            .where('chat_ref', isEqualTo: todo.chatRef)
                            .where('title', isEqualTo: todo.title)
                            .get();

                        // Batch update all related task documents
                        final batch = FirebaseFirestore.instance.batch();
                        for (var doc in allTasksSnapshot.docs) {
                          final taskRef = doc.reference;
                          batch.update(taskRef, {
                            'title': titleController.text.trim(),
                            'involved_people': selectedPeople.toList(),
                            'priority': selectedPriority,
                            'due_date': selectedDueDate,
                          });
                        }
                        await batch.commit();

                        // Find newly added people and create task documents for them
                        final originalPeople = Set.from(todo.involvedPeople);
                        final newlyAddedPeople =
                            selectedPeople.difference(originalPeople);

                        if (newlyAddedPeople.isNotEmpty) {
                          for (String personName in newlyAddedPeople) {
                            // Find the user reference for this person
                            for (var member in groupMembers) {
                              if (member.displayName == personName) {
                                final userRef = member.reference;

                                // Check if this is the original task owner
                                // If the task's user_ref is the same as the person we're adding,
                                // don't create a duplicate
                                if (todo.userRef != userRef) {
                                  // Check if a task already exists for this user with the same chat_ref and title
                                  final existingTasks = await ActionItemsRecord
                                      .collection
                                      .where('user_ref', isEqualTo: userRef)
                                      .where('chat_ref',
                                          isEqualTo: todo.chatRef)
                                      .where('title',
                                          isEqualTo:
                                              titleController.text.trim())
                                      .get()
                                      .then((snapshot) => snapshot.docs);

                                  // Only create a new task if one doesn't already exist
                                  if (existingTasks.isEmpty) {
                                    await ActionItemsRecord.collection.add(
                                      createActionItemsRecordData(
                                        title: titleController.text.trim(),
                                        groupName: todo.groupName,
                                        priority: selectedPriority,
                                        status: todo.status,
                                        userRef: userRef,
                                        workspaceRef: todo.workspaceRef,
                                        chatRef: todo.chatRef,
                                        involvedPeople: selectedPeople.toList(),
                                        createdTime: todo.createdTime,
                                        lastSummaryAt: todo.lastSummaryAt,
                                        dueDate: selectedDueDate,
                                        description: todo.description,
                                      ),
                                    );
                                  }
                                }
                                break;
                              }
                            }
                          }
                        }

                        if (mounted) {
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error updating task: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } else if (selectedPeople.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Please select at least one involved person'),
                          backgroundColor: Colors.orange,
                        ),
                      );
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
  }

  Future<void> _showAddNewDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    // Initialize with empty selected people
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

    // Initialize priority
    String selectedPriority = 'low';

    // Track selected due date (nullable)
    DateTime? selectedDueDate;

    // Get current user and workspace
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
                'Create New Action Item',
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
                          fontSize: 14,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Assign To (Select at least one)',
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

                      // Create action item for each assigned person
                      final batch = FirebaseFirestore.instance.batch();

                      for (String personName in selectedPeople) {
                        // Find the user reference for this person
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
                            content: Text('Action item created successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error creating action item: $e'),
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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.assignment_outlined,
                size: 64, color: Color(0xFF9CA3AF)),
            const SizedBox(height: 16),
            const Text(
              'No tasks yet',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tasks from this group will appear here',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                onTap: () => _showAddNewDialog(),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '+ Add',
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
          ],
        ),
      ),
    );
  }
}
