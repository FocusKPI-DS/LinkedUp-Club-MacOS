import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';
import 'dart:async';
import 'dart:ui';

class SummerAITodos extends StatefulWidget {
  const SummerAITodos({super.key, this.isMobile = false});

  final bool isMobile;

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
        print(
            '🔍 Loaded ${chats.length} groups for user. Group IDs: ${_userGroupChatIds?.toList()}');
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
          // REQUIREMENT: User must be in involved_people
          // For tasks with chatRef: User must also be in the group
          // For tasks without chatRef (manually created): Only check involvement

          // Step 1: Check if task is from a group the user is a member of
          bool isFromUserGroup = false;
          if (task.chatRef != null) {
            final chatId = task.chatRef!.id;
            if (_userGroupChatIds != null) {
              isFromUserGroup = _userGroupChatIds!.contains(chatId);
            } else {
              // Groups haven't loaded yet - for now, allow through if user is involved
              // This prevents showing 0 tasks while groups are loading
              // We'll still check involvement below
              isFromUserGroup = true; // Assume true temporarily for group tasks
            }

            // If groups are loaded and task is from a group the user is NOT in, hide it
            if (_userGroupChatIds != null && !isFromUserGroup) {
              return false; // User is not a member of this group - HIDE THIS TASK
            }
          }
          // If chatRef is null, it's a personal task (or non-group task), so we allow it
          // and rely on the involved_people check below.

          // Step 2: Check if user is in involved_people (STRICT: name-based only)
          // Only show tasks where the user's name (Mitansh, Mitan, Patel, etc.) is
          // present in involved_people — no "owner" bypass so unrelated tasks stay hidden.
          // User MUST be in involved_people to see the task
          if (task.involvedPeople.isEmpty) {
            return false; // No involved_people - HIDE THIS TASK
          }

          if (currentUserDisplayName.isEmpty) {
            return false; // Can't match without a display name
          }

          final displayNameLower = currentUserDisplayName.toLowerCase().trim();

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
            final userWords =
                displayNameLower.split(' ').where((w) => w.length > 1).toList();
            final involvedWords =
                nameLower.split(' ').where((w) => w.length > 1).toList();

            // Check if both names have the same words (bidirectional exact match)
            final userWordsSet = userWords.toSet();
            final involvedWordsSet = involvedWords.toSet();
            if (userWordsSet.length > 0 && involvedWordsSet.length > 0) {
              // All user words must be in involved words AND all involved words must be in user words
              // This ensures "Mitansh Patel" matches "Mitansh Patel" but "Mitansh" doesn't match "Dan Zhang"
              bool userWordsAllMatch =
                  userWordsSet.every((word) => involvedWordsSet.contains(word));
              bool involvedWordsAllMatch =
                  involvedWordsSet.every((word) => userWordsSet.contains(word));
              if (userWordsAllMatch && involvedWordsAllMatch) {
                return true;
              }

              // Also allow if user name is a subset (all user words match)
              // e.g., "Mitansh" should match "Mitansh Patel"
              if (userWordsSet.length < involvedWordsSet.length) {
                if (userWordsSet
                    .every((word) => involvedWordsSet.contains(word))) {
                  return true;
                }
              }
              
              // More flexible: if user name contains any significant word from involved name
              // This helps with variations like "Mitansh P." vs "Mitansh Patel"
              if (userWordsSet.length > 0) {
                final significantUserWords = userWordsSet.where((w) => w.length >= 3).toSet();
                final significantInvolvedWords = involvedWordsSet.where((w) => w.length >= 3).toSet();
                if (significantUserWords.length > 0 && significantInvolvedWords.length > 0) {
                  // If at least one significant word matches
                  if (significantUserWords.intersection(significantInvolvedWords).isNotEmpty) {
                    // Additional check: first name or last name should match
                    if (userWordsSet.first == involvedWordsSet.first || 
                        (userWordsSet.length > 1 && involvedWordsSet.length > 1 && 
                         userWordsSet.last == involvedWordsSet.last)) {
                      return true;
                    }
                  }
                }
              }
            }

            return false;
          });

          // User must be in involved_people to see the task
          if (!isInvolved) {
            return false; // User not in involved_people - HIDE THIS TASK
          }

          // For tasks with chatRef: verify user is in the group (if groups are loaded)
          // For manually created tasks (chatRef == null): only involvement check is needed
          if (task.chatRef != null && _userGroupChatIds != null) {
            final chatId = task.chatRef!.id;
            final isFromUserGroup = _userGroupChatIds!.contains(chatId);
            if (!isFromUserGroup) {
              return false; // Double-check: user not in group
            }
          }

          // Conditions met: 
          // - For group tasks: user is in the group (or groups still loading) AND in involved_people
          // - For manual tasks: user is in involved_people
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

        // Use LayoutBuilder to get available height and fill it properly
        return widget.isMobile
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Header with title, subtitle, and action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Action Items title
                                  Text(
                                    'Action Items',
                                    style: const TextStyle(
                                      fontFamily: '.SF Pro Display',
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                      color: CupertinoColors.label,
                                      letterSpacing: -0.8,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Subtitle on separate line
                                  Text(
                                    'Focus on what matters most.',
                                    style: const TextStyle(
                                      fontFamily: '.SF Pro Text',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w400,
                                      color: CupertinoColors.secondaryLabel,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Action buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Filter button with dropdown
                                _buildFilterDropdown(),
                                const SizedBox(width: 8),
                                // Add Task button - iOS style
                                CupertinoButton(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  color: CupertinoColors.systemBlue,
                                  borderRadius: BorderRadius.circular(8),
                                  onPressed: () {
                                    _showAddNewDialog();
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        CupertinoIcons.add,
                                        size: 16,
                                        color: CupertinoColors.white,
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        'Task',
                                        style: TextStyle(
                                          fontFamily: '.SF Pro Text',
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: CupertinoColors.white,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Todo List - Fill remaining height
                      Expanded(
                        child: AnimatedSwitcher(
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
                      ),
                    ],
                  );
                },
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Header with title, subtitle, and action buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Action Items title
                              Text(
                                'Action Items',
                                style: const TextStyle(
                                  fontFamily: '.SF Pro Display',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: CupertinoColors.label,
                                  letterSpacing: -0.8,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Subtitle on separate line
                              Text(
                                'Focus on what matters most.',
                                style: const TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w400,
                                  color: CupertinoColors.secondaryLabel,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Action buttons
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Filter button with dropdown
                            _buildFilterDropdown(),
                            const SizedBox(width: 8),
                            // Add Task button - iOS style
                            CupertinoButton(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              color: CupertinoColors.systemBlue,
                              borderRadius: BorderRadius.circular(8),
                              onPressed: () {
                                _showAddNewDialog();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    CupertinoIcons.add,
                                    size: 16,
                                    color: CupertinoColors.white,
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Task',
                                    style: TextStyle(
                                      fontFamily: '.SF Pro Text',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.white,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Todo List - Desktop uses calculated height
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
              );
      },
    );
  }

  Future<void> _showAddNewDialog() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    // Get current user
    if (currentUserReference == null) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: const Text('Please log in to create action items'),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return;
    }

    final currentUser =
        await UsersRecord.getDocumentOnce(currentUserReference!);

    // Note: Group assignment removed for iOS-native dialog simplicity

    // Initialize priority
    String selectedPriority = 'low';

    // Track selected due date (nullable)
    DateTime? selectedDueDate;

    return showCupertinoDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return CupertinoAlertDialog(
              title: const Text(
                'Create New Action Item',
                style: TextStyle(
                  fontFamily: '.SF Pro Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
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
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: titleController,
                        autofocus: true,
                        maxLines: 2,
                        placeholder: 'Enter task title',
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Description (Optional)',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: descriptionController,
                        maxLines: 4,
                        placeholder: 'Enter task description',
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Priority',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      CupertinoPicker(
                        itemExtent: 32,
                        scrollController: FixedExtentScrollController(
                          initialItem: ['low', 'moderate', 'high', 'urgent']
                              .indexOf(selectedPriority),
                        ),
                        onSelectedItemChanged: (index) {
                          setDialogState(() {
                            selectedPriority =
                                ['low', 'moderate', 'high', 'urgent'][index];
                          });
                        },
                        children: const [
                          Text('Low'),
                          Text('Moderate'),
                          Text('High'),
                          Text('Urgent'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Due Date (Optional)',
                        style: TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
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
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                selectedDueDate != null
                                    ? DateFormat('MMM dd, yyyy')
                                        .format(selectedDueDate!)
                                    : 'No due date',
                                style: const TextStyle(
                                  fontFamily: '.SF Pro Text',
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            color: CupertinoColors.systemGrey6,
                            onPressed: () async {
                              final now = DateTime.now();
                              await showCupertinoModalPopup<DateTime>(
                                context: context,
                                builder: (context) => Container(
                                  height: 216,
                                  padding: const EdgeInsets.only(top: 6),
                                  margin: EdgeInsets.only(
                                    bottom: MediaQuery.of(context)
                                        .viewInsets
                                        .bottom,
                                  ),
                                  color: CupertinoColors.systemBackground
                                      .resolveFrom(context),
                                  child: SafeArea(
                                    top: false,
                                    child: CupertinoDatePicker(
                                      initialDateTime: selectedDueDate ?? now,
                                      minimumDate: DateTime(now.year - 5),
                                      maximumDate: DateTime(now.year + 10),
                                      mode: CupertinoDatePickerMode.date,
                                      use24hFormat: true,
                                      onDateTimeChanged: (DateTime newDate) {
                                        setDialogState(() {
                                          selectedDueDate = DateTime(
                                              newDate.year,
                                              newDate.month,
                                              newDate.day);
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                            child: const Text('Pick date'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) {
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: const Text('Error'),
                          content: const Text('Please enter a task title'),
                          actions: [
                            CupertinoDialogAction(
                              child: const Text('OK'),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      );
                      return;
                    }

                    try {
                      final now = DateTime.now();

                      // Automatically assign to current user
                      final actionItemRef = ActionItemsRecord.collection.doc();

                      final actionItemData = createActionItemsRecordData(
                        title: titleController.text.trim(),
                        groupName: '',
                        priority: selectedPriority,
                        status: 'pending',
                        userRef: currentUser.reference,
                        chatRef: null,
                        involvedPeople: [currentUser.displayName],
                        createdTime: now,
                        lastSummaryAt: now,
                        dueDate: selectedDueDate,
                        description: descriptionController.text.trim(),
                      );

                      await actionItemRef.set(actionItemData);

                      if (mounted) {
                        Navigator.pop(context);
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Success'),
                            content:
                                const Text('Action item created successfully!'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text('Error'),
                            content: Text('Error creating action item: $e'),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('OK'),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTodoList(List<ActionItemsRecord> todos) {
    // On mobile, the list should expand to fill available space
    // On desktop, use calculated height based on screen size
    if (widget.isMobile) {
      // Mobile: Fill available space
      return ListView.builder(
        key: ValueKey('todos-list-${_selectedFilter}'),
        shrinkWrap: false,
        physics: const BouncingScrollPhysics(),
        itemCount: todos.length,
        itemBuilder: (context, index) {
          final todo = todos[index];
          return _buildTodoRow(context, todo, index);
        },
      );
    } else {
      // Desktop: height for exactly 4 task cards (card ~118px with margin) so container looks full
      const double cardHeightWithMargin = 118.0;
      const int visibleCards = 4;
      const double maxHeight = visibleCards * cardHeightWithMargin;

      return SizedBox(
        height: maxHeight,
        child: ListView.builder(
          key: ValueKey('todos-list-${_selectedFilter}'),
          shrinkWrap: false,
          physics: const BouncingScrollPhysics(),
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return _buildTodoRow(context, todo, index);
          },
        ),
      );
    }
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
        await todo.reference.update({
          'status': 'completed',
          'completed_time': FieldValue.serverTimestamp(),
        });

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
        await todo.reference.update({
          'status': 'pending',
          'completed_time': null,
        });

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

    // Get priority color for accent
    final priorityColor = _getPriorityColor(todo.priority);

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 50),
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: priorityColor.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 1),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Left accent border
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: priorityColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Checkbox on the left
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 14),
                    child: CupertinoCheckbox(
                      value: (todo.status == 'completed' ||
                              _completedTasks.contains(todo.reference.path)) &&
                          !_completingTasks.containsKey(todo.reference.id),
                      onChanged: (value) {
                        final isCompleting = value ?? false;
                        _handleTaskToggle(todo, isCompleting);
                      },
                      activeColor: CupertinoColors.systemGreen,
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
                            fontFamily: '.SF Pro Display',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF1E293B),
                            decoration: todo.status == 'completed'
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            decorationColor: const Color(0xFF94A3B8),
                            letterSpacing: -0.3,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        // Metadata row with better spacing - use Expanded to prevent overflow
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _buildPriorityBadge(todo.priority),
                                  if (todo.groupName.isNotEmpty || todo.chatRef != null)
                                    _buildGroupChip(todo),
                                  _buildDueDateChip(todo),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Overlapping people avatars - constrained width
                            _buildPeopleAvatars(todo),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Progress bar overlay when completing
            if (_completingTasks.containsKey(todo.reference.id))
              Positioned(
                left: 0,
                bottom: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                  child: SizedBox(
                    height: 3,
                    child: material.LinearProgressIndicator(
                      value: _completingTasks[todo.reference.id],
                      backgroundColor: CupertinoColors.systemGrey6,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          CupertinoColors.systemGreen),
                      minHeight: 3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'urgent':
      case 'high':
        return const Color(0xFFEF4444);
      case 'moderate':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF3B82F6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Widget _buildGroupChip(ActionItemsRecord todo) {
    return Builder(
      builder: (context) {
        if (todo.groupName.isNotEmpty || todo.chatRef == null) {
          if (todo.groupName.isEmpty) {
            return const SizedBox.shrink();
          }
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  CupertinoIcons.group_solid,
                  size: 11,
                  color: const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  todo.groupName,
                  style: const TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    letterSpacing: -0.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }
        return StreamBuilder<ChatsRecord>(
          stream: ChatsRecord.getDocument(todo.chatRef!),
          builder: (context, chatSnap) {
            final name = chatSnap.data?.title ?? '';
            if (name.isEmpty) return const SizedBox.shrink();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.group_solid,
                    size: 11,
                    color: const Color(0xFF64748B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    name,
                    style: const TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                      letterSpacing: -0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDueDateChip(ActionItemsRecord todo) {
    final hasDueDate = todo.dueDate != null;
    final isOverdue = hasDueDate && todo.dueDate!.isBefore(DateTime.now());
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOverdue 
            ? const Color(0xFFFEF2F2)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            CupertinoIcons.calendar,
            size: 11,
            color: isOverdue 
                ? const Color(0xFFDC2626)
                : const Color(0xFF64748B),
          ),
          const SizedBox(width: 4),
          Text(
            hasDueDate
                ? DateFormat('MMM dd').format(todo.dueDate!)
                : 'No due',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isOverdue 
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF64748B),
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color dotColor;
    Color bgColor;
    String label;

    switch (priority.toLowerCase()) {
      case 'urgent':
        dotColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEF2F2);
        label = 'Urgent';
        break;
      case 'high':
        dotColor = const Color(0xFFEF4444);
        bgColor = const Color(0xFFFEF2F2);
        label = 'High';
        break;
      case 'moderate':
        dotColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEFCE8);
        label = 'Moderate';
        break;
      case 'low':
        dotColor = const Color(0xFF3B82F6);
        bgColor = const Color(0xFFEFF6FF);
        label = 'Low';
        break;
      default:
        dotColor = const Color(0xFFF59E0B);
        bgColor = const Color(0xFFFEFCE8);
        label = 'Moderate';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dotColor.withOpacity(0.2),
          width: 1,
        ),
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
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dotColor,
              letterSpacing: -0.1,
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
        child: CupertinoActivityIndicator(
          radius: 12,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, {String filter = 'pending'}) {
    IconData icon;
    String title;
    String subtitle;

    if (filter == 'all') {
      icon = CupertinoIcons.doc_text;
      title = 'No tasks yet';
      subtitle = 'Tasks from SummerAI will appear here';
    } else if (filter == 'pending') {
      icon = CupertinoIcons.doc_text;
      title = 'No pending tasks';
      subtitle = 'All tasks have been completed';
    } else {
      icon = CupertinoIcons.check_mark_circled;
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
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontFamily: '.SF Pro Display',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 15,
                color: CupertinoColors.secondaryLabel,
                letterSpacing: -0.2,
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
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: CupertinoColors.systemBackground,
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: CupertinoColors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: CupertinoColors.label,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                fontFamily: '.SF Pro Text',
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
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    }
  }

  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => _closeDropdown(),
        child: Container(
          color: CupertinoColors.black.withOpacity(0.3),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when clicking inside
              child: Container(
                width: 300,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: CupertinoColors.separator,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.black.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: CupertinoColors.separator,
                            width: 1,
                          ),
                        ),
                      ),
                      child: CupertinoTextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                        placeholder: 'Search...',
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        style: const TextStyle(
                          fontFamily: '.SF Pro Text',
                          fontSize: 14,
                          color: CupertinoColors.label,
                        ),
                      ),
                    ),
                    // Filter options
                    Flexible(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Priority section
                              _buildFilterSection(
                                'Priority',
                                [
                                  _FilterOption('High', 'high',
                                      widget.selectedPriority == 'high'),
                                  _FilterOption('Moderate', 'moderate',
                                      widget.selectedPriority == 'moderate'),
                                  _FilterOption('Low', 'low',
                                      widget.selectedPriority == 'low'),
                                ],
                                (value) => widget.onPriorityChanged(
                                    value == widget.selectedPriority
                                        ? null
                                        : value),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: CupertinoColors.separator,
                              ),
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
                                  _FilterOption('No Due', 'no_due',
                                      widget.selectedDueDateFilter == 'no_due'),
                                  _FilterOption(
                                      'Overdue',
                                      'overdue',
                                      widget.selectedDueDateFilter ==
                                          'overdue'),
                                  _FilterOption('Today', 'today',
                                      widget.selectedDueDateFilter == 'today'),
                                  _FilterOption(
                                      'This Week',
                                      'this_week',
                                      widget.selectedDueDateFilter ==
                                          'this_week'),
                                ],
                                (value) => widget.onDueDateChanged(
                                    value == widget.selectedDueDateFilter
                                        ? null
                                        : value),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                height: 1,
                                color: CupertinoColors.separator,
                              ),
                              const SizedBox(height: 16),
                              // Group Name section
                              _buildGroupNameSection(),
                              const SizedBox(height: 12),
                              Container(
                                height: 1,
                                color: CupertinoColors.separator,
                              ),
                              const SizedBox(height: 8),
                              // Clear All button
                              SizedBox(
                                width: double.infinity,
                                child: CupertinoButton(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  minSize: 0,
                                  onPressed: () {
                                    widget.onClearAll();
                                    _closeDropdown();
                                  },
                                  child: const Text(
                                    'Clear All',
                                    style: TextStyle(
                                      fontFamily: '.SF Pro Text',
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: CupertinoColors.secondaryLabel,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
            return CupertinoButton(
              padding: EdgeInsets.zero,
              minSize: 0,
              onPressed: () => onChanged(option.value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: option.isSelected
                      ? CupertinoColors.systemBlue
                      : CupertinoColors.systemGrey6,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: option.isSelected
                        ? CupertinoColors.systemBlue
                        : CupertinoColors.separator,
                    width: 1,
                  ),
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: option.isSelected
                        ? CupertinoColors.white
                        : CupertinoColors.label,
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
            color: CupertinoColors.systemBackground,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: CupertinoColors.separator,
              width: 1,
            ),
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minSize: 0,
            onPressed: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => Container(
                  height: 200,
                  child: CupertinoPicker(
                    itemExtent: 32,
                    scrollController: FixedExtentScrollController(
                      initialItem: widget.selectedGroupName == null
                          ? 0
                          : filteredGroups.indexOf(widget.selectedGroupName!) +
                              1,
                    ),
                    onSelectedItemChanged: (index) {
                      widget.onGroupNameChanged(
                        index == 0 ? null : filteredGroups[index - 1],
                      );
                    },
                    children: [
                      const Text('All Groups'),
                      ...filteredGroups.map((name) => Text(name)),
                    ],
                  ),
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.selectedGroupName ?? 'All Groups',
                  style: const TextStyle(
                    fontFamily: '.SF Pro Text',
                    fontSize: 12,
                    color: CupertinoColors.label,
                  ),
                ),
                const Icon(
                  CupertinoIcons.chevron_down,
                  size: 18,
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Only remove overlay; do not call _closeDropdown() which uses setState (unsafe during dispose)
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.hasActiveFilters || _isOpen;

    return material.Material(
      color: Colors.transparent,
      child: material.InkWell(
        onTap: _toggleDropdown,
        borderRadius: BorderRadius.circular(20.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                // Liquid Glass effect with semi-transparent background
                color: isActive
                    ? CupertinoColors.systemBlue.withOpacity(0.7)
                    : CupertinoColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20.0),
                border: Border.all(
                  color: isActive
                      ? CupertinoColors.systemBlue.withOpacity(0.8)
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.slider_horizontal_3,
                    size: 16,
                    color: isActive
                        ? CupertinoColors.white
                        : CupertinoColors.systemBlue,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Filter',
                    style: TextStyle(
                      fontFamily: '.SF Pro Text',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isActive
                          ? CupertinoColors.white
                          : CupertinoColors.systemBlue,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isOpen
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    size: 16,
                    color: isActive
                        ? CupertinoColors.white
                        : CupertinoColors.systemBlue,
                  ),
                ],
              ),
            ),
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
