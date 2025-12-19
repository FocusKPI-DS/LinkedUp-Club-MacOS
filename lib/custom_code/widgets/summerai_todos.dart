import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'dart:async';

class SummerAITodos extends StatefulWidget {
  const SummerAITodos({super.key});

  @override
  State<SummerAITodos> createState() => _SummerAITodosState();
}

class _SummerAITodosState extends State<SummerAITodos> {
  final Set<String> _completedTasks = {};
  String _selectedFilter = 'pending'; // 'all', 'pending', or 'completed'
  List<ActionItemsRecord>? _cachedTodos; // Cache to prevent flickering

  // Track tasks being completed with animation progress
  final Map<String, double> _completingTasks =
      {}; // taskId -> progress (0.0 to 1.0)

  // Cache of user's group chat IDs for filtering
  Set<String>? _userGroupChatIds;
  StreamSubscription? _chatsSubscription;

  // Filter state
  String? _selectedPriority; // null, 'high', 'moderate', 'low'
  String?
      _selectedDueDateFilter; // null, 'has_due', 'no_due', 'overdue', 'today', 'this_week'
  String? _selectedGroupName; // null or specific group name

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  void _loadUserGroups() {
    if (currentUserReference == null) return;

    // Load user's group chats to verify membership
    _chatsSubscription = queryChatsRecord(
      queryBuilder: (chatsRecord) => chatsRecord
          .where('members', arrayContains: currentUserReference)
          .where('is_group', isEqualTo: true),
    ).listen((chats) {
      setState(() {
        _userGroupChatIds = chats.map((c) => c.reference.id).toSet();
        print('🔍 Loaded ${chats.length} groups for user. Group IDs: ${_userGroupChatIds?.toList()}');
      });
    }, onError: (error) {
      print('❌ Error loading user groups: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserReference == null) {
      return _buildEmptyState(context, filter: _selectedFilter);
    }

    // Get current user's display name for filtering
    final currentUserDisplayName =
        currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

    // Query ALL tasks (we'll filter client-side to ensure user is involved)
    // This is necessary because involved_people might have name variations
    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .orderBy('created_time', descending: true)
            .limit(200), // Get more tasks to filter from
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedTodos == null) {
          return _buildLoadingState(context);
        }

        // Handle errors gracefully - return empty state to not block the app
        if (snapshot.hasError) {
          print('Error loading action items: ${snapshot.error}');
          return _buildEmptyState(context, filter: _selectedFilter);
        }

        // Use cached data if available during loading, otherwise use fresh data
        List<ActionItemsRecord> allTodos;
        try {
          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            _cachedTodos = snapshot.data!;
            allTodos = snapshot.data!;
          } else if (_cachedTodos != null && _cachedTodos!.isNotEmpty) {
            allTodos = _cachedTodos!;
          } else {
            return _buildEmptyState(context, filter: _selectedFilter);
          }
        } catch (e) {
          print('Error processing action items: $e');
          return _buildEmptyState(context, filter: _selectedFilter);
        }

        // Filter tasks: ONLY show tasks where user is in involved_people
        // This ensures users only see tasks they're actually involved in
        if (currentUserReference == null) {
          return _buildEmptyState(context, filter: _selectedFilter);
        }

        final filteredTodos = allTodos.where((task) {
          // REQUIREMENT: User must be in the group AND in involved_people
          
          // Step 1: Check if task is from a group the user is a member of
          if (task.chatRef == null) {
            // Task has no chat_ref - skip it (tasks must be from a group)
            return false;
          }

          final chatId = task.chatRef!.id;
          bool isFromUserGroup = false;
          if (_userGroupChatIds != null) {
            isFromUserGroup = _userGroupChatIds!.contains(chatId);
          } else {
            // Groups haven't loaded yet - for now, allow through if user is involved
            // This prevents showing 0 tasks while groups are loading
            // We'll still check involvement below
          }

          // If groups are loaded and task is not from a group the user is in, hide it
          if (_userGroupChatIds != null && !isFromUserGroup) {
            return false; // User is not a member of this group - HIDE THIS TASK
          }

          // Step 2: Check if user is in involved_people
          // User MUST be in involved_people to see the task
          if (task.involvedPeople.isEmpty) {
            return false; // No involved_people - HIDE THIS TASK
          }

          if (currentUserDisplayName.isEmpty) {
            return false; // Can't match without a display name
          }

          final displayNameLower =
              currentUserDisplayName.toLowerCase().trim();

          bool isInvolved = task.involvedPeople.any((name) {
            final nameLower = name.toLowerCase().trim();

            // Exact match (most reliable)
            if (nameLower == displayNameLower) {
              return true;
            }

            // Handle comma-separated names: "Mitansh, Mitansh Patel" or "Mitansh Patel, Dan Zhang"
            final nameParts =
                nameLower.split(',').map((s) => s.trim()).toList();
            for (final part in nameParts) {
              // Exact match with a part (must be exact, not just contains)
              if (part == displayNameLower) {
                return true;
              }
            }

            // Handle cases where one name is a subset of the other
            // e.g., "Mitansh" should match "Mitansh Patel" and vice versa
            final userWords = displayNameLower.split(' ').where((w) => w.length > 1).toList();
            final involvedWords = nameLower.split(' ').where((w) => w.length > 1).toList();
            
            // Check if both names have the same words (bidirectional exact match)
            final userWordsSet = userWords.toSet();
            final involvedWordsSet = involvedWords.toSet();
            if (userWordsSet.length > 0 && involvedWordsSet.length > 0) {
              // All user words must be in involved words AND all involved words must be in user words
              // This ensures "Mitansh Patel" matches "Mitansh Patel" but "Mitansh" doesn't match "Dan Zhang"
              bool userWordsAllMatch = userWordsSet.every((word) => involvedWordsSet.contains(word));
              bool involvedWordsAllMatch = involvedWordsSet.every((word) => userWordsSet.contains(word));
              if (userWordsAllMatch && involvedWordsAllMatch) {
                return true;
              }
              
              // Also allow if user name is a subset (all user words match)
              // e.g., "Mitansh" should match "Mitansh Patel"
              if (userWordsSet.length < involvedWordsSet.length) {
                if (userWordsSet.every((word) => involvedWordsSet.contains(word))) {
                  return true;
                }
              }
            }

            return false;
          });

          // User must be in involved_people to see the task
          if (!isInvolved) {
            return false; // User not in involved_people - HIDE THIS TASK
          }

          // If groups are loaded, verify user is in the group
          // If groups aren't loaded yet, we've already checked involvement, so allow through
          if (_userGroupChatIds != null && !isFromUserGroup) {
            return false; // Double-check: user not in group
          }

          // Both conditions met: user is in the group (or groups still loading) AND in involved_people
          return true;
        }).toList();

        // Apply status filter
        final statusFilteredTodos = filteredTodos.where((t) {
          if (_selectedFilter == 'all') {
            return true;
          }

          final isLocallyCompleted = _completedTasks.contains(t.reference.path);
          final isFirestoreCompleted = t.status == 'completed';
          final isCompleted = isLocallyCompleted || isFirestoreCompleted;

          if (_selectedFilter == 'pending') {
            return !isCompleted;
          } else {
            return isCompleted;
          }
        }).toList();

        // Apply custom filters (priority, due date, group name)
        final customFilteredTodos = statusFilteredTodos.where((t) {
          // Priority filter
          if (_selectedPriority != null) {
            final taskPriority = t.priority.toLowerCase();
            if (_selectedPriority == 'high' &&
                taskPriority != 'high' &&
                taskPriority != 'urgent') {
              return false;
            }
            if (_selectedPriority == 'moderate' && taskPriority != 'moderate') {
              return false;
            }
            if (_selectedPriority == 'low' && taskPriority != 'low') {
              return false;
            }
          }

          // Due date filter
          if (_selectedDueDateFilter != null) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final weekFromNow = today.add(const Duration(days: 7));

            if (_selectedDueDateFilter == 'has_due' && t.dueDate == null) {
              return false;
            }
            if (_selectedDueDateFilter == 'no_due' && t.dueDate != null) {
              return false;
            }
            if (_selectedDueDateFilter == 'overdue' &&
                (t.dueDate == null || t.dueDate!.isAfter(today))) {
              return false;
            }
            if (_selectedDueDateFilter == 'today' &&
                (t.dueDate == null ||
                    t.dueDate!.year != today.year ||
                    t.dueDate!.month != today.month ||
                    t.dueDate!.day != today.day)) {
              return false;
            }
            if (_selectedDueDateFilter == 'this_week' &&
                (t.dueDate == null ||
                    t.dueDate!.isBefore(today) ||
                    t.dueDate!.isAfter(weekFromNow))) {
              return false;
            }
          }

          // Group name filter
          if (_selectedGroupName != null && _selectedGroupName!.isNotEmpty) {
            final selectedGroupLower = _selectedGroupName!.toLowerCase().trim();
            final taskGroupName = t.groupName.toLowerCase().trim();

            // Check if groupName matches
            if (taskGroupName == selectedGroupLower) {
              // Match found, continue
            } else if (t.groupName.isEmpty && t.chatRef != null) {
              // If groupName is empty, we need to check chatRef title
              // Since we can't do async here, we'll skip this task if groupName doesn't match
              // and groupName is empty (chatRef titles will be handled separately if needed)
              return false;
            } else {
              // groupName doesn't match
              return false;
            }
          }

          return true;
        }).toList();

        // Deduplicate tasks by normalized title
        final Map<String, ActionItemsRecord> uniqueTodos = {};
        for (var todo in customFilteredTodos) {
          final titleKey = todo.title.toLowerCase().trim();
          if (!uniqueTodos.containsKey(titleKey)) {
            uniqueTodos[titleKey] = todo;
          }
        }
        final todos = uniqueTodos.values.toList();

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white, // Keep main container white
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E293B).withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title, subtitle, and action buttons
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Action Items',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Focus on what matters most today.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Filter button with dropdown
                      _buildFilterDropdown(),
                      const SizedBox(width: 8),
                      // Add Task button - VIBRANT BLUE
                      ElevatedButton(
                        onPressed: () {
                          _showAddNewDialog();
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                          shadowColor: const Color(0xFF2563EB).withOpacity(0.3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Container(
                              width: 13,
                              height: 13,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.add,
                                  size: 10,
                                  color: Color(0xFF2563EB),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Add Task',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Todo List - AnimatedSwitcher for smooth transitions
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: todos.isEmpty
                    ? _buildEmptyState(context, filter: _selectedFilter)
                    : _buildTodoList(todos),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showAddNewDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    // Get current user
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

    // Fetch user's groups for optional group assignment
    List<ChatsRecord> userGroups = [];
    try {
      userGroups = await queryChatsRecordOnce(
        queryBuilder: (chatsRecord) => chatsRecord
            .where('members', arrayContains: currentUserReference)
            .where('is_group', isEqualTo: true),
      );
    } catch (e) {
      print('Error fetching groups: $e');
    }

    // Initialize priority
    String selectedPriority = 'low';

    // Track selected due date (nullable)
    DateTime? selectedDueDate;

    // Track selected group (nullable)
    ChatsRecord? selectedGroup;

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
                        'Assign Group (Optional)',
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
                        child: DropdownButtonFormField<ChatsRecord>(
                          value: selectedGroup,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 8),
                            hintText: 'No group',
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
                          items: [
                            const DropdownMenuItem<ChatsRecord>(
                              value: null,
                              child: Text(
                                'No group',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            ...userGroups.map((group) {
                              return DropdownMenuItem<ChatsRecord>(
                                value: group,
                                child: Text(
                                  group.title,
                                  style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedGroup = value;
                            });
                          },
                          isExpanded: true,
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

                    try {
                      final now = DateTime.now();
                      final groupName = selectedGroup?.title ?? '';
                      final chatRef = selectedGroup?.reference;

                      // Automatically assign to current user
                      final actionItemRef =
                          ActionItemsRecord.collection.doc();

                      final actionItemData = createActionItemsRecordData(
                        title: titleController.text.trim(),
                        groupName: groupName,
                        priority: selectedPriority,
                        status: 'pending',
                        userRef: currentUser.reference,
                        chatRef: chatRef,
                        involvedPeople: [currentUser.displayName],
                        createdTime: now,
                        lastSummaryAt: now,
                        dueDate: selectedDueDate,
                        description: descriptionController.text.trim(),
                      );

                      await actionItemRef.set(actionItemData);

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

  Widget _buildTodoList(List<ActionItemsRecord> todos) {
    // Always show 4 items with fixed height, scroll for more
    const double itemHeight = 140.0;
    const double fixedHeight =
        itemHeight * 4; // Fixed height for exactly 4 items

    return SizedBox(
      height: fixedHeight,
      child: ListView.builder(
        key: ValueKey('todos-list-${_selectedFilter}'),
        shrinkWrap: false,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return _buildTodoRow(context, todo, index);
        },
      ),
    );
  }

  Future<void> _handleTaskToggle(
      ActionItemsRecord todo, bool isCompleting) async {
    final taskId = todo.reference.id;

    try {
      if (isCompleting) {
        // Start the animation
        if (mounted) {
          setState(() {
            _completingTasks[taskId] = 0.0;
          });
        }

        // Animate the progress bar over 0.8 seconds
        const duration = Duration(milliseconds: 800);
        const steps = 20;
        final stepDuration = duration ~/ steps;

        for (int i = 0; i <= steps; i++) {
          await Future.delayed(stepDuration);
          if (mounted) {
            setState(() {
              _completingTasks[taskId] = i / steps;
            });
          }
        }

        // Update task in Firebase
        await todo.reference.update({'status': 'completed'});

        // Wait a bit before hiding the task
        await Future.delayed(const Duration(milliseconds: 200));

        // Add to local set to hide it and clear animation
        if (mounted) {
          setState(() {
            _completedTasks.add(todo.reference.path);
            _completingTasks.remove(taskId);
          });
        }
      } else {
        // Uncheck - change status back to pending
        await todo.reference.update({'status': 'pending'});

        if (mounted) {
          setState(() {
            _completedTasks.remove(todo.reference.path);
          });
        }
      }
    } catch (e) {
      print('Error updating task: $e');
      if (mounted && isCompleting) {
        setState(() {
          _completingTasks.remove(taskId);
        });
      }
    }
  }

  Widget _buildTodoRow(
      BuildContext context, ActionItemsRecord todo, int index) {
    final isCompleting = _completingTasks.containsKey(todo.reference.id);
    final progress = _completingTasks[todo.reference.id] ?? 0.0;

    // Fade out during completion (fade after 50% progress)
    final opacity =
        isCompleting && progress > 0.5 ? 1.0 - ((progress - 0.5) / 0.5) : 1.0;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 50),
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              const Color(0xFFF8F9FA), // Exact same as Today's Schedule cards
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Checkbox on the left
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child: Checkbox(
                    value: (todo.status == 'completed' ||
                            _completedTasks.contains(todo.reference.path)) &&
                        !_completingTasks.containsKey(todo.reference.id),
                    onChanged: (value) {
                      final isCompleting = value ?? false;
                      _handleTaskToggle(todo, isCompleting);
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    checkColor: Colors.white,
                    fillColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF10B981);
                        }
                        return Colors.transparent;
                      },
                    ),
                    side: BorderSide(
                      color: (todo.status == 'completed' ||
                              _completedTasks.contains(todo.reference.path))
                          ? const Color(0xFF10B981)
                          : const Color(0xFF9CA3AF),
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task title
                      Text(
                        todo.title,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF333333),
                          decoration: todo.status == 'completed'
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Priority, Project, Due Date row
                      Row(
                        children: [
                          _buildPriorityBadge(todo.priority),
                          const SizedBox(width: 8),
                          Flexible(
                            fit: FlexFit.loose,
                            child: (todo.groupName.isNotEmpty ||
                                    todo.chatRef == null)
                                ? Text(
                                    todo.groupName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
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
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 12,
                            color: Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            todo.dueDate != null
                                ? DateFormat('MMM dd').format(todo.dueDate!)
                                : 'No due',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Spacer(),
                          // Overlapping people avatars - stick to right end
                          _buildPeopleAvatars(todo),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Progress bar overlay when completing
            if (_completingTasks.containsKey(todo.reference.id))
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
                    value: _completingTasks[todo.reference.id],
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 3,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color dotColor;
    Color bgColor;
    String label;

    switch (priority.toLowerCase()) {
      case 'urgent':
        dotColor = const Color(0xFFEF4444); // BRIGHTER RED
        bgColor = const Color(0xFFFEE2E2); // LIGHTER RED BG
        label = 'High';
        break;
      case 'high':
        dotColor = const Color(0xFFEF4444); // BRIGHTER RED
        bgColor = const Color(0xFFFEE2E2); // LIGHTER RED BG
        label = 'High';
        break;
      case 'moderate':
        dotColor = const Color(0xFFF59E0B); // BRIGHTER YELLOW/ORANGE
        bgColor = const Color(0xFFFEF3C7); // LIGHTER YELLOW BG
        label = 'Moderate';
        break;
      case 'low':
        dotColor = const Color(0xFF3B82F6); // BRIGHT BLUE
        bgColor = const Color(0xFFDBEAFE); // LIGHTER BLUE BG
        label = 'Low';
        break;
      default:
        dotColor = const Color(0xFFF59E0B); // BRIGHTER YELLOW/ORANGE
        bgColor = const Color(0xFFFEF3C7); // LIGHTER YELLOW BG
        label = 'Moderate';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: dotColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeopleAvatars(ActionItemsRecord todo) {
    // Get involved people count, show up to 3 avatars
    final peopleCount = todo.involvedPeople.length;
    final displayCount = peopleCount > 3 ? 3 : peopleCount;

    if (displayCount == 0) {
      return const SizedBox.shrink();
    }

    // Calculate width: avatar size 24, spacing 14px between each
    const double avatarSize = 24.0;
    const double spacing = 14.0;
    final double totalWidth = avatarSize + (displayCount - 1) * spacing;

    return SizedBox(
      width: totalWidth,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(displayCount, (index) {
          final personName = index < todo.involvedPeople.length
              ? todo.involvedPeople[index]
              : '';

          return Positioned(
            left: index * spacing,
            child: _AvatarWithTooltip(
              personName: personName,
              index: index,
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {String filter = 'pending'}) {
    IconData icon;
    String title;
    String subtitle;

    if (filter == 'all') {
      icon = Icons.assignment_outlined;
      title = 'No tasks yet';
      subtitle = 'Tasks from SummerAI will appear here';
    } else if (filter == 'pending') {
      icon = Icons.assignment_outlined;
      title = 'No pending tasks';
      subtitle = 'All tasks have been completed';
    } else {
      icon = Icons.check_circle_outline;
      title = 'No completed tasks';
      subtitle = 'Complete some tasks to see them here';
    }

    return Container(
      key: ValueKey('empty-state-$filter'),
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
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

  bool _hasActiveFilters() {
    return _selectedPriority != null ||
        _selectedDueDateFilter != null ||
        (_selectedGroupName != null && _selectedGroupName!.isNotEmpty);
  }

  Widget _buildFilterDropdown() {
    return _FilterDropdownButton(
      hasActiveFilters: _hasActiveFilters(),
      selectedPriority: _selectedPriority,
      selectedDueDateFilter: _selectedDueDateFilter,
      selectedGroupName: _selectedGroupName,
      cachedTodos: _cachedTodos,
      onPriorityChanged: (value) {
        setState(() {
          _selectedPriority = value;
        });
      },
      onDueDateChanged: (value) {
        setState(() {
          _selectedDueDateFilter = value;
        });
      },
      onGroupNameChanged: (value) {
        setState(() {
          _selectedGroupName = value;
        });
      },
      onClearAll: () {
        setState(() {
          _selectedPriority = null;
          _selectedDueDateFilter = null;
          _selectedGroupName = null;
        });
      },
    );
  }

  Widget _buildGroupNameDropdownInMenu() {
    // Get unique group names from cached todos
    final groupNames = <String>{};
    if (_cachedTodos != null) {
      for (var todo in _cachedTodos!) {
        if (todo.groupName.isNotEmpty) {
          groupNames.add(todo.groupName);
        }
      }
    }

    final sortedGroupNames = groupNames.toList()..sort();

    if (sortedGroupNames.isEmpty) {
      return const Text(
        'No groups available',
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          color: Color(0xFF64748B),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedGroupName,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox(),
        hint: const Text(
          'All Groups',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xFF9CA3AF),
          ),
        ),
        items: [
          const DropdownMenuItem<String>(
            value: null,
            child: Text(
              'All Groups',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF4B5563),
              ),
            ),
          ),
          ...sortedGroupNames.map((groupName) {
            return DropdownMenuItem<String>(
              value: groupName,
              child: Text(
                groupName,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF4B5563),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
        ],
        onChanged: (value) {
          setState(() {
            _selectedGroupName = value;
          });
        },
        icon: const Icon(Icons.arrow_drop_down,
            size: 18, color: Color(0xFF6B7280)),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF2563EB) : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color:
                isSelected ? const Color(0xFF2563EB) : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }
}

// Avatar with tooltip widget
class _AvatarWithTooltip extends StatefulWidget {
  final String personName;
  final int index;

  const _AvatarWithTooltip({
    required this.personName,
    required this.index,
  });

  @override
  State<_AvatarWithTooltip> createState() => _AvatarWithTooltipState();
}

class _AvatarWithTooltipState extends State<_AvatarWithTooltip> {
  OverlayEntry? _overlayEntry;
  final GlobalKey _avatarKey = GlobalKey();

  void _showTooltip() {
    if (_overlayEntry != null || widget.personName.isEmpty) return;

    final overlay = Overlay.of(context);
    final renderBox =
        _avatarKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        final text = widget.personName;
        // Estimate tooltip width for centering
        final estimatedWidth = text.length * 6.0 + 18.0;

        return Positioned(
          left: position.dx +
              (size.width / 2) -
              (estimatedWidth / 2), // Center tooltip below avatar
          top: position.dy + size.height + 4,
          child: Material(
            elevation: 12,
            borderRadius: BorderRadius.circular(6),
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 2),
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _hideTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  void dispose() {
    _hideTooltip();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showTooltip(),
      onExit: (_) => _hideTooltip(),
      child: Container(
        key: _avatarKey,
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: const Color(0xFFD1D5DB),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.15),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: widget.personName.isNotEmpty
            ? Center(
                child: Text(
                  widget.personName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              )
            : const SizedBox(),
      ),
    );
  }
}

// Custom Filter Dropdown Widget
class _FilterDropdownButton extends StatefulWidget {
  final bool hasActiveFilters;
  final String? selectedPriority;
  final String? selectedDueDateFilter;
  final String? selectedGroupName;
  final List<ActionItemsRecord>? cachedTodos;
  final Function(String?) onPriorityChanged;
  final Function(String?) onDueDateChanged;
  final Function(String?) onGroupNameChanged;
  final VoidCallback onClearAll;

  const _FilterDropdownButton({
    required this.hasActiveFilters,
    required this.selectedPriority,
    required this.selectedDueDateFilter,
    required this.selectedGroupName,
    required this.cachedTodos,
    required this.onPriorityChanged,
    required this.onDueDateChanged,
    required this.onGroupNameChanged,
    required this.onClearAll,
  });

  @override
  State<_FilterDropdownButton> createState() => _FilterDropdownButtonState();
}

class _FilterDropdownButtonState extends State<_FilterDropdownButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _isOpen = false;
    });
  }

  OverlayEntry _createOverlayEntry() {
    RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final size = renderBox!.size;

    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => _closeDropdown(),
        child: Material(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                width: 300,
                child: CompositedTransformFollower(
                  link: _layerLink,
                  showWhenUnlinked: false,
                  offset: Offset(-20, size.height + 4), // Shift left by 20px
                  child: GestureDetector(
                    onTap: () {}, // Prevent closing when clicking inside
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFE5E7EB),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Search bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Color(0xFFE5E7EB),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: TextField(
                                controller: _searchController,
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value.toLowerCase();
                                  });
                                },
                                decoration: const InputDecoration(
                                  hintText: 'Search...',
                                  hintStyle: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF),
                                  ),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(vertical: 8),
                                ),
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  color: Color(0xFF1A1F36),
                                ),
                              ),
                            ),
                            // Filter options
                            Flexible(
                              child: Container(
                                constraints:
                                    const BoxConstraints(maxHeight: 400),
                                child: SingleChildScrollView(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Priority section
                                        _buildFilterSection(
                                          'Priority',
                                          [
                                            _FilterOption(
                                                'High',
                                                'high',
                                                widget.selectedPriority ==
                                                    'high'),
                                            _FilterOption(
                                                'Moderate',
                                                'moderate',
                                                widget.selectedPriority ==
                                                    'moderate'),
                                            _FilterOption(
                                                'Low',
                                                'low',
                                                widget.selectedPriority ==
                                                    'low'),
                                          ],
                                          (value) => widget.onPriorityChanged(
                                              value == widget.selectedPriority
                                                  ? null
                                                  : value),
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(
                                            height: 1,
                                            color: Color(0xFFE5E7EB)),
                                        const SizedBox(height: 16),
                                        // Due Date section
                                        _buildFilterSection(
                                          'Due Date',
                                          [
                                            _FilterOption(
                                                'Has Due',
                                                'has_due',
                                                widget.selectedDueDateFilter ==
                                                    'has_due'),
                                            _FilterOption(
                                                'No Due',
                                                'no_due',
                                                widget.selectedDueDateFilter ==
                                                    'no_due'),
                                            _FilterOption(
                                                'Overdue',
                                                'overdue',
                                                widget.selectedDueDateFilter ==
                                                    'overdue'),
                                            _FilterOption(
                                                'Today',
                                                'today',
                                                widget.selectedDueDateFilter ==
                                                    'today'),
                                            _FilterOption(
                                                'This Week',
                                                'this_week',
                                                widget.selectedDueDateFilter ==
                                                    'this_week'),
                                          ],
                                          (value) => widget.onDueDateChanged(
                                              value ==
                                                      widget
                                                          .selectedDueDateFilter
                                                  ? null
                                                  : value),
                                        ),
                                        const SizedBox(height: 16),
                                        const Divider(
                                            height: 1,
                                            color: Color(0xFFE5E7EB)),
                                        const SizedBox(height: 16),
                                        // Group Name section
                                        _buildGroupNameSection(),
                                        const SizedBox(height: 12),
                                        const Divider(
                                            height: 1,
                                            color: Color(0xFFE5E7EB)),
                                        const SizedBox(height: 8),
                                        // Clear All button
                                        SizedBox(
                                          width: double.infinity,
                                          child: TextButton(
                                            onPressed: () {
                                              widget.onClearAll();
                                              _closeDropdown();
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8),
                                            ),
                                            child: const Text(
                                              'Clear All',
                                              style: TextStyle(
                                                fontFamily: 'Inter',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
      String title, List<_FilterOption> options, Function(String?) onChanged) {
    final filteredOptions = options.where((opt) {
      if (_searchQuery.isEmpty) return true;
      return opt.label.toLowerCase().contains(_searchQuery);
    }).toList();

    if (filteredOptions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: filteredOptions.map((option) {
            return InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: option.isSelected
                      ? const Color(0xFF374151)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: option.isSelected
                        ? const Color(0xFF374151)
                        : const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: option.isSelected
                        ? Colors.white
                        : const Color(0xFF4B5563),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildGroupNameSection() {
    final groupNames = <String>{};
    if (widget.cachedTodos != null) {
      for (var todo in widget.cachedTodos!) {
        if (todo.groupName.isNotEmpty) {
          groupNames.add(todo.groupName);
        }
      }
    }

    final sortedGroupNames = groupNames.toList()..sort();
    final filteredGroups = sortedGroupNames.where((name) {
      if (_searchQuery.isEmpty) return true;
      return name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Group Name',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
              width: 1,
            ),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              canvasColor: Colors.white,
            ),
            child: DropdownButton<String>(
              value: widget.selectedGroupName,
              isExpanded: true,
              isDense: true,
              underline: const SizedBox(),
              dropdownColor: Colors.white,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF4B5563),
              ),
              hint: const Text(
                'All Groups',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text(
                    'All Groups',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF4B5563),
                    ),
                  ),
                ),
                ...filteredGroups.map((groupName) {
                  return DropdownMenuItem<String>(
                    value: groupName,
                    child: Text(
                      groupName,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Color(0xFF4B5563),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                widget.onGroupNameChanged(value);
              },
              icon: const Icon(Icons.arrow_drop_down,
                  size: 18, color: Color(0xFF6B7280)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _closeDropdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        onTap: _toggleDropdown,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: widget.hasActiveFilters
                  ? const Color(0xFF2563EB)
                  : const Color(0xFFE5E7EB),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.tune,
                size: 16,
                color: widget.hasActiveFilters
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF4B5563),
              ),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.hasActiveFilters
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF4B5563),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                _isOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 18,
                color: widget.hasActiveFilters
                    ? const Color(0xFF2563EB)
                    : const Color(0xFF4B5563),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterOption {
  final String label;
  final String value;
  final bool isSelected;

  _FilterOption(this.label, this.value, this.isSelected);
}
