import 'package:flutter/cupertino.dart';
import '/utils/debug_log.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '/backend/backend.dart';
import '/backend/firestore/firestore_desktop_adapter.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/pages/desktop_chat/rest_poll_builder.dart';
import 'dart:async';
import 'dart:ui';

class SummerAITodos extends StatefulWidget {
  const SummerAITodos({
    super.key,
    this.isMobile = false,
    this.onShowAnnouncement,
  });

  final bool isMobile;
  final void Function(String message)? onShowAnnouncement;

  @override
  State<SummerAITodos> createState() => _SummerAITodosState();
}

class _SummerAITodosState extends State<SummerAITodos> {
  final Set<String> _completedTasks = {};
  String _selectedFilter = 'pending'; // 'all', 'pending', or 'completed'
  List<ActionItemsRecord>? _cachedTodos; // Cache to prevent flickering
  /// Paths removed locally until the server/stream catch up (avoids resurrecting deletes).
  final Set<String> _locallyDeletedTodoPaths = {};

  // Track tasks being completed with animation progress
  final Map<String, double> _completingTasks =
      {}; // taskId -> progress (0.0 to 1.0)

  // Cache of user's group chat IDs for filtering
  Set<String>? _userGroupChatIds;
  StreamSubscription? _chatsSubscription;
  Timer? _groupsPollTimer;

  // Filter state
  String? _selectedPriority; // null, 'high', 'moderate', 'low'
  String?
      _selectedDueDateFilter; // null, 'has_due', 'no_due', 'overdue', 'today', 'this_week'

  @override
  void initState() {
    super.initState();
    _loadUserGroups();
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    _groupsPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshUserGroups() async {
    if (currentUserReference == null) return;
    try {
      final chats = await fsQueryMemberChats(currentUserReference!);
      final groupIds = chats
          .where((c) => c.isGroup)
          .map((c) => c.reference.id)
          .toSet();
      if (mounted) {
        setState(() {
          _userGroupChatIds = groupIds;
        });
        debugLog(
            '🔍 Loaded ${groupIds.length} groups for user. Group IDs: ${groupIds.toList()}');
      }
    } catch (error) {
      debugLog('❌ Error loading user groups: $error');
    }
  }

  List<ActionItemsRecord> _mergeTodosWithCache(
    List<ActionItemsRecord> serverTodos,
    List<ActionItemsRecord>? cached,
  ) {
    final serverPaths = serverTodos.map((t) => t.reference.path).toSet();
    // Drop tombstones once the server no longer returns those docs.
    _locallyDeletedTodoPaths.removeWhere((path) => !serverPaths.contains(path));

    final filteredServer = serverTodos
        .where((t) => !_locallyDeletedTodoPaths.contains(t.reference.path))
        .toList();

    if (cached == null || cached.isEmpty) {
      return filteredServer;
    }

    final localOnly = cached
        .where((t) => !serverPaths.contains(t.reference.path))
        .where((t) => !_locallyDeletedTodoPaths.contains(t.reference.path))
        .toList();
    final merged = [...localOnly, ...filteredServer];
    merged.sort((a, b) {
      final aTime = a.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return merged;
  }

  void _prependCachedTodo(ActionItemsRecord todo) {
    setState(() {
      final existing = _cachedTodos ?? [];
      if (existing.any((t) => t.reference.path == todo.reference.path)) {
        return;
      }
      _cachedTodos = [todo, ...existing];
    });
  }

  void _loadUserGroups() {
    if (currentUserReference == null) return;

    if (useWindowsFirestoreRest) {
      _refreshUserGroups();
      _groupsPollTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _refreshUserGroups(),
      );
      return;
    }

    _chatsSubscription = queryChatsRecord(
      queryBuilder: (chatsRecord) => chatsRecord
          .where('members', arrayContains: currentUserReference)
          .where('is_group', isEqualTo: true),
    ).listen((chats) {
      setState(() {
        _userGroupChatIds = chats.map((c) => c.reference.id).toSet();
        debugLog(
            '🔍 Loaded ${chats.length} groups for user. Group IDs: ${_userGroupChatIds?.toList()}');
      });
    }, onError: (error) {
      debugLog('❌ Error loading user groups: $error');
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
    return _buildActionItemsStream(
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            _cachedTodos == null) {
          return _buildLoadingState(context);
        }

        // Handle errors gracefully - return empty state to not block the app
        if (snapshot.hasError) {
          debugLog('Error loading action items: ${snapshot.error}');
          return _buildEmptyState(context, filter: _selectedFilter);
        }

        // Use cached data if available during loading, otherwise use fresh data
        List<ActionItemsRecord> allTodos;
        try {
          if (snapshot.hasData) {
            final serverTodos = snapshot.data!;
            if (serverTodos.isNotEmpty) {
              allTodos = _mergeTodosWithCache(serverTodos, _cachedTodos);
              _cachedTodos = allTodos;
            } else if (_cachedTodos != null && _cachedTodos!.isNotEmpty) {
              allTodos = _cachedTodos!;
            } else {
              return _buildEmptyState(context, filter: _selectedFilter);
            }
          } else if (_cachedTodos != null && _cachedTodos!.isNotEmpty) {
            allTodos = _cachedTodos!;
          } else {
            return _buildEmptyState(context, filter: _selectedFilter);
          }
        } catch (e) {
          debugLog('Error processing action items: $e');
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
                                      fontSize: 24,
                                      fontWeight: FontWeight.w500,
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
                                _buildAddTaskButton(),
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
                                  fontSize: 24,
                                  fontWeight: FontWeight.w500,
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
                            _buildAddTaskButton(),
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

    final currentUser = await fsGetUserOnce(currentUserReference!);
    String selectedPriority = 'low';
    DateTime? selectedDueDate;
    var isCreating = false;
    final dueDateFieldKey = GlobalKey();
    material.OverlayEntry? dueDateOverlay;

    void closeDueDateOverlay() {
      dueDateOverlay?.remove();
      dueDateOverlay = null;
    }

    final parentContext = context;
    final createdItem = await material.showDialog<ActionItemsRecord?>(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) {
        return material.StatefulBuilder(
          builder: (context, setDialogState) {
            DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

            String dueDateLabel() {
              if (selectedDueDate == null) return 'No due date';
              return DateFormat('MMM d, yyyy').format(selectedDueDate!);
            }

            Future<void> openDueDateCalendar() async {
              final box = dueDateFieldKey.currentContext?.findRenderObject()
                  as RenderBox?;
              if (box == null || !box.hasSize) return;

              closeDueDateOverlay();

              final overlayState = material.Overlay.of(context);
              final overlayBox = overlayState.context.findRenderObject()
                  as RenderBox;
              final topLeft =
                  box.localToGlobal(Offset.zero, ancestor: overlayBox);
              final fieldWidth = box.size.width;
              final left = topLeft.dx;
              final top = topLeft.dy + box.size.height + 6;
              final panelWidth = fieldWidth.clamp(280.0, 320.0);

              var viewedMonth = DateTime(
                (selectedDueDate ?? DateTime.now()).year,
                (selectedDueDate ?? DateTime.now()).month,
              );

              late material.OverlayEntry entry;
              entry = material.OverlayEntry(
                builder: (overlayContext) {
                  return material.Stack(
                    children: [
                      material.Positioned.fill(
                        child: material.GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: closeDueDateOverlay,
                          child: const ColoredBox(color: Color(0x00000000)),
                        ),
                      ),
                      material.Positioned(
                        left: left,
                        top: top,
                        width: panelWidth,
                        child: material.Material(
                          color: Colors.white,
                          elevation: 10,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: material.StatefulBuilder(
                            builder: (menuContext, setMenuState) {
                              return _DueDateCalendarPanel(
                                viewedMonth: viewedMonth,
                                selectedDate: selectedDueDate,
                                onViewedMonthChanged: (month) {
                                  setMenuState(() => viewedMonth = month);
                                },
                                onSelected: (date) {
                                  setDialogState(
                                      () => selectedDueDate = date);
                                  closeDueDateOverlay();
                                },
                                onClear: () {
                                  setDialogState(
                                      () => selectedDueDate = null);
                                  closeDueDateOverlay();
                                },
                                onToday: () {
                                  final today = dateOnly(DateTime.now());
                                  setDialogState(() {
                                    selectedDueDate = today;
                                  });
                                  closeDueDateOverlay();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
              dueDateOverlay = entry;
              overlayState.insert(entry);
            }

            Future<void> createTask() async {
              if (isCreating) return;
              if (titleController.text.trim().isEmpty) {
                if (parentContext.mounted) {
                  material.ScaffoldMessenger.of(parentContext).showSnackBar(
                    const material.SnackBar(
                      content: Text('Please enter a task title'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
                return;
              }

              setDialogState(() => isCreating = true);
              try {
                final now = DateTime.now();
                final actionItemData = createActionItemsRecordData(
                  title: titleController.text.trim(),
                  groupName: '',
                  priority: selectedPriority,
                  status: 'pending',
                  userRef: currentUser.reference,
                  workspaceRef: currentUser.currentWorkspaceRef,
                  chatRef: null,
                  involvedPeople: [currentUser.displayName],
                  createdTime: now,
                  lastSummaryAt: now,
                  dueDate: selectedDueDate,
                  description: descriptionController.text.trim(),
                );

                final ref = await fsCreateActionItem(actionItemData);
                final newItem = ActionItemsRecord.getDocumentFromData(
                  actionItemData,
                  ref,
                );

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, newItem);
                }
              } catch (e) {
                setDialogState(() => isCreating = false);
                if (parentContext.mounted) {
                  material.ScaffoldMessenger.of(parentContext).showSnackBar(
                    material.SnackBar(
                      content: Text('Error creating action item: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            }

            Widget priorityChip(String value, String label) {
              final selected = selectedPriority == value;
              return material.Expanded(
                child: material.InkWell(
                  onTap: isCreating
                      ? null
                      : () => setDialogState(() => selectedPriority = value),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFDBEAFE)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }

            material.InputDecoration fieldDecoration(String hint) {
              return material.InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              );
            }

            const labelStyle = TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            );

            return material.Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'New task',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Title', style: labelStyle),
                      const SizedBox(height: 8),
                      material.TextField(
                        controller: titleController,
                        autofocus: true,
                        enabled: !isCreating,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration:
                            fieldDecoration('What needs to get done?'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Priority', style: labelStyle),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          priorityChip('low', 'Low'),
                          const SizedBox(width: 8),
                          priorityChip('moderate', 'Medium'),
                          const SizedBox(width: 8),
                          priorityChip('high', 'High'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Due date (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      material.InkWell(
                        key: dueDateFieldKey,
                        onTap: isCreating ? null : openDueDateCalendar,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const material.Icon(
                                material.Icons.calendar_today_outlined,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dueDateLabel(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: selectedDueDate != null
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              const material.Icon(
                                material.Icons.keyboard_arrow_down,
                                size: 20,
                                color: Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Description (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      material.TextField(
                        controller: descriptionController,
                        enabled: !isCreating,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: fieldDecoration('Add more detail'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          material.OutlinedButton(
                            onPressed: isCreating
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: material.OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          material.ElevatedButton(
                            onPressed: isCreating ? null : createTask,
                            style: material.ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isCreating
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: material.CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Task',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    closeDueDateOverlay();

    if (createdItem != null && parentContext.mounted) {
      _prependCachedTodo(createdItem);
      widget.onShowAnnouncement?.call('Action item added');
    }
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
        fetch: () => fsQueryRecentActionItems(limit: 200),
        builder: builder,
      );
    }
    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .orderBy('created_time', descending: true)
            .limit(200),
      ),
      builder: builder,
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
        await fsMarkActionItemDone(todo.reference);

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
        await fsPatchDocument(todo.reference, {'status': 'pending'});
        await fsDeleteDocumentField(todo.reference, 'completed_time');

        if (mounted) {
          setState(() {
            _completedTasks.remove(todo.reference.path);
          });
        }
      }
    } catch (e) {
      debugLog('Error updating task: $e');
      if (mounted && isCompleting) {
        setState(() {
          _completingTasks.remove(taskId);
        });
      }
    }
  }

  Widget _buildTaskIconButton({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return material.Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(6),
      child: material.InkWell(
        mouseCursor: material.MaterialStateMouseCursor.clickable,
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  Future<void> _handleDeleteTask(ActionItemsRecord todo) async {
    final confirmed = await material.showDialog<bool>(
      context: context,
      builder: (context) => material.AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Task',
          style: TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1F2937),
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${todo.title}"? This action cannot be undone.',
          style: const TextStyle(
            fontFamily: '.SF Pro Display',
            fontSize: 14,
            color: Color(0xFF64748B),
          ),
        ),
        actions: [
          material.TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          material.ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: material.ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await fsDeleteMatchingActionItems(todo);
      final titleKey = todo.title.toLowerCase().trim();
      final chatPath = todo.chatRef?.path;
      setState(() {
        final matchingPaths = (_cachedTodos ?? [])
            .where(
              (t) =>
                  t.reference.path == todo.reference.path ||
                  (t.title.toLowerCase().trim() == titleKey &&
                      (chatPath == null || t.chatRef?.path == chatPath)),
            )
            .map((t) => t.reference.path);
        _locallyDeletedTodoPaths.add(todo.reference.path);
        _locallyDeletedTodoPaths.addAll(matchingPaths);
        _cachedTodos = (_cachedTodos ?? [])
            .where(
                (t) => !_locallyDeletedTodoPaths.contains(t.reference.path))
            .toList();
      });
      if (mounted) {
        widget.onShowAnnouncement?.call('Action item deleted');
      }
    } catch (e) {
      if (mounted) {
        material.ScaffoldMessenger.of(context).showSnackBar(
          material.SnackBar(
            content: Text('Error deleting task: $e'),
            backgroundColor: material.Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showEditDialog(ActionItemsRecord todo) async {
    final titleController = TextEditingController(text: todo.title);
    final descriptionController =
        TextEditingController(text: todo.description);
    final priorityValue =
        todo.priority.isNotEmpty ? todo.priority.toLowerCase() : 'low';
    String selectedPriority;
    switch (priorityValue) {
      case 'high':
      case 'urgent':
        selectedPriority = 'high';
        break;
      case 'medium':
      case 'moderate':
        selectedPriority = 'moderate';
        break;
      default:
        selectedPriority = 'low';
    }
    DateTime? selectedDueDate = todo.dueDate;
    var isSaving = false;
    final dueDateFieldKey = GlobalKey();
    material.OverlayEntry? dueDateOverlay;

    void closeDueDateOverlay() {
      dueDateOverlay?.remove();
      dueDateOverlay = null;
    }

    final parentContext = context;
    await material.showDialog(
      context: context,
      barrierColor: const Color(0x66000000),
      builder: (dialogContext) {
        return material.StatefulBuilder(
          builder: (context, setDialogState) {
            DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

            String dueDateLabel() {
              if (selectedDueDate == null) return 'No due date';
              return DateFormat('MMM d, yyyy').format(selectedDueDate!);
            }

            Future<void> openDueDateCalendar() async {
              final box = dueDateFieldKey.currentContext?.findRenderObject()
                  as RenderBox?;
              if (box == null || !box.hasSize) return;

              closeDueDateOverlay();

              final overlayState = material.Overlay.of(context);
              final overlayBox =
                  overlayState.context.findRenderObject() as RenderBox;
              final topLeft =
                  box.localToGlobal(Offset.zero, ancestor: overlayBox);
              final fieldWidth = box.size.width;
              final left = topLeft.dx;
              final top = topLeft.dy + box.size.height + 6;
              final panelWidth = fieldWidth.clamp(280.0, 320.0);

              var viewedMonth = DateTime(
                (selectedDueDate ?? DateTime.now()).year,
                (selectedDueDate ?? DateTime.now()).month,
              );

              late material.OverlayEntry entry;
              entry = material.OverlayEntry(
                builder: (overlayContext) {
                  return material.Stack(
                    children: [
                      material.Positioned.fill(
                        child: material.GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: closeDueDateOverlay,
                          child: const ColoredBox(color: Color(0x00000000)),
                        ),
                      ),
                      material.Positioned(
                        left: left,
                        top: top,
                        width: panelWidth,
                        child: material.Material(
                          color: Colors.white,
                          elevation: 10,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                          ),
                          child: material.StatefulBuilder(
                            builder: (menuContext, setMenuState) {
                              return _DueDateCalendarPanel(
                                viewedMonth: viewedMonth,
                                selectedDate: selectedDueDate,
                                onViewedMonthChanged: (month) {
                                  setMenuState(() => viewedMonth = month);
                                },
                                onSelected: (date) {
                                  setDialogState(
                                      () => selectedDueDate = date);
                                  closeDueDateOverlay();
                                },
                                onClear: () {
                                  setDialogState(
                                      () => selectedDueDate = null);
                                  closeDueDateOverlay();
                                },
                                onToday: () {
                                  final today = dateOnly(DateTime.now());
                                  setDialogState(() {
                                    selectedDueDate = today;
                                  });
                                  closeDueDateOverlay();
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
              dueDateOverlay = entry;
              overlayState.insert(entry);
            }

            Future<void> saveTask() async {
              if (isSaving) return;
              final title = titleController.text.trim();
              if (title.isEmpty) {
                if (parentContext.mounted) {
                  material.ScaffoldMessenger.of(parentContext).showSnackBar(
                    const material.SnackBar(
                      content: Text('Please enter a task title'),
                      backgroundColor: Color(0xFFEF4444),
                    ),
                  );
                }
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                await fsPatchDocument(todo.reference, {
                  'title': title,
                  'priority': selectedPriority,
                  'due_date': selectedDueDate,
                  'description': descriptionController.text.trim(),
                });
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              } catch (e) {
                setDialogState(() => isSaving = false);
                if (parentContext.mounted) {
                  material.ScaffoldMessenger.of(parentContext).showSnackBar(
                    material.SnackBar(
                      content: Text('Error updating task: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            }

            Widget priorityChip(String value, String label) {
              final selected = selectedPriority == value;
              return material.Expanded(
                child: material.InkWell(
                  onTap: isSaving
                      ? null
                      : () => setDialogState(() => selectedPriority = value),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFDBEAFE)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: selected
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                ),
              );
            }

            material.InputDecoration fieldDecoration(String hint) {
              return material.InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: Color(0xFF9CA3AF),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: material.OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
              );
            }

            const labelStyle = TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            );

            return material.Dialog(
              backgroundColor: Colors.white,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Edit task',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text('Title', style: labelStyle),
                      const SizedBox(height: 8),
                      material.TextField(
                        controller: titleController,
                        autofocus: true,
                        enabled: !isSaving,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration:
                            fieldDecoration('What needs to get done?'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Priority', style: labelStyle),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          priorityChip('low', 'Low'),
                          const SizedBox(width: 8),
                          priorityChip('moderate', 'Medium'),
                          const SizedBox(width: 8),
                          priorityChip('high', 'High'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Due date (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      material.InkWell(
                        key: dueDateFieldKey,
                        onTap: isSaving ? null : openDueDateCalendar,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border:
                                Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const material.Icon(
                                material.Icons.calendar_today_outlined,
                                size: 18,
                                color: Color(0xFF6B7280),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  dueDateLabel(),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    color: selectedDueDate != null
                                        ? const Color(0xFF111827)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              const material.Icon(
                                material.Icons.keyboard_arrow_down,
                                size: 20,
                                color: Color(0xFF9CA3AF),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Description (optional)', style: labelStyle),
                      const SizedBox(height: 8),
                      material.TextField(
                        controller: descriptionController,
                        enabled: !isSaving,
                        maxLines: 4,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                        decoration: fieldDecoration('Add more detail'),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          material.OutlinedButton(
                            onPressed: isSaving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            style: material.OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF111827),
                              side:
                                  const BorderSide(color: Color(0xFFE5E7EB)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          material.ElevatedButton(
                            onPressed: isSaving ? null : saveTask,
                            style: material.ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF3B82F6),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: material.CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Save Task',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    closeDueDateOverlay();
    titleController.dispose();
    descriptionController.dispose();
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
        clipBehavior: Clip.antiAlias,
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
          children: [
            // Left accent — clipped by the card's border radius
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: priorityColor,
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
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
                            ),
                            const SizedBox(width: 8),
                            _buildPeopleAvatars(todo),
                          ],
                        ),
                        if (todo.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            todo.description.trim(),
                            style: TextStyle(
                              fontFamily: '.SF Pro Display',
                              fontSize: 13,
                              fontWeight: FontWeight.w400,
                              color: todo.status == 'completed'
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                              decoration: todo.status == 'completed'
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              decorationColor: const Color(0xFF94A3B8),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
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
                                  if (todo.groupName.isNotEmpty ||
                                      todo.chatRef != null)
                                    _buildGroupChip(todo),
                                  _buildDueDateChip(todo),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildTaskIconButton(
                              icon: CupertinoIcons.pencil,
                              color: const Color(0xFF3B82F6),
                              backgroundColor: const Color(0xFFEFF6FF),
                              onTap: () => _showEditDialog(todo),
                            ),
                            const SizedBox(width: 6),
                            _buildTaskIconButton(
                              icon: CupertinoIcons.trash,
                              color: const Color(0xFFDC2626),
                              backgroundColor: const Color(0xFFFEE2E2),
                              onTap: () => _handleDeleteTask(todo),
                            ),
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
    if (todo.groupName.isNotEmpty || todo.chatRef == null) {
      if (todo.groupName.isEmpty) {
        return const SizedBox.shrink();
      }
      return _buildGroupChipContent(todo.groupName);
    }

    if (useWindowsFirestoreRest) {
      return FutureBuilder<ChatsRecord>(
        future: fsGetChatOnce(todo.chatRef!),
        builder: (context, chatSnap) {
          final name = chatSnap.data?.title ?? '';
          if (name.isEmpty) return const SizedBox.shrink();
          return _buildGroupChipContent(name);
        },
      );
    }

    return StreamBuilder<ChatsRecord>(
      stream: ChatsRecord.getDocument(todo.chatRef!),
      builder: (context, chatSnap) {
        final name = chatSnap.data?.title ?? '';
        if (name.isEmpty) return const SizedBox.shrink();
        return _buildGroupChipContent(name);
      },
    );
  }

  Widget _buildGroupChipContent(String name) {
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
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: CupertinoColors.secondaryLabel,
              size: 32,
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.label,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: '.SF Pro Text',
                fontSize: 14,
                color: CupertinoColors.secondaryLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    return _selectedPriority != null || _selectedDueDateFilter != null;
  }

  Widget _buildAddTaskButton() {
    return material.Material(
      color: Colors.transparent,
      child: material.InkWell(
        onTap: _showAddNewDialog,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              material.Icon(
                material.Icons.add,
                size: 16,
                color: Colors.white,
              ),
              SizedBox(width: 6),
              Text(
                'Task',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return _FilterDropdownButton(
      hasActiveFilters: _hasActiveFilters(),
      selectedPriority: _selectedPriority,
      selectedDueDateFilter: _selectedDueDateFilter,
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
      onClearAll: () {
        setState(() {
          _selectedPriority = null;
          _selectedDueDateFilter = null;
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
  final Function(String?) onPriorityChanged;
  final Function(String?) onDueDateChanged;
  final VoidCallback onClearAll;

  const _FilterDropdownButton({
    required this.hasActiveFilters,
    required this.selectedPriority,
    required this.selectedDueDateFilter,
    required this.onPriorityChanged,
    required this.onDueDateChanged,
    required this.onClearAll,
  });

  @override
  State<_FilterDropdownButton> createState() => _FilterDropdownButtonState();
}

class _FilterDropdownButtonState extends State<_FilterDropdownButton> {
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  static const _labelStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: Color(0xFF374151),
  );

  @override
  void didUpdateWidget(covariant _FilterDropdownButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_overlayEntry == null) return;
    if (oldWidget.selectedPriority == widget.selectedPriority &&
        oldWidget.selectedDueDateFilter == widget.selectedDueDateFilter &&
        oldWidget.hasActiveFilters == widget.hasActiveFilters) {
      return;
    }
    // Parent setState rebuilds StreamBuilder; marking the overlay dirty during
    // that build throws. Refresh after the current frame instead.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _overlayEntry?.markNeedsBuild();
    });
  }

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
      builder: (context) {
        final maxDialogHeight =
            MediaQuery.sizeOf(context).height * 0.85;
        return material.Material(
          color: const Color(0x66000000),
          child: material.GestureDetector(
            onTap: _closeDropdown,
            behavior: HitTestBehavior.opaque,
            child: Center(
              child: material.GestureDetector(
                onTap: () {},
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: 440,
                    maxHeight: maxDialogHeight,
                  ),
                  child: material.Material(
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Filter',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFilterSection(
                            'Priority',
                            [
                              _FilterOption('Low', 'low',
                                  widget.selectedPriority == 'low'),
                              _FilterOption(
                                  'Medium',
                                  'moderate',
                                  widget.selectedPriority == 'moderate'),
                              _FilterOption('High', 'high',
                                  widget.selectedPriority == 'high'),
                            ],
                            (value) {
                              widget.onPriorityChanged(
                                  value == widget.selectedPriority
                                      ? null
                                      : value);
                            },
                            equalWidth: true,
                          ),
                          const SizedBox(height: 16),
                          _buildFilterSection(
                            'Due date',
                            [
                              _FilterOption(
                                  'Has due',
                                  'has_due',
                                  widget.selectedDueDateFilter == 'has_due'),
                              _FilterOption(
                                  'No due',
                                  'no_due',
                                  widget.selectedDueDateFilter == 'no_due'),
                              _FilterOption(
                                  'Overdue',
                                  'overdue',
                                  widget.selectedDueDateFilter == 'overdue'),
                              _FilterOption(
                                  'Today',
                                  'today',
                                  widget.selectedDueDateFilter == 'today'),
                              _FilterOption(
                                  'This week',
                                  'this_week',
                                  widget.selectedDueDateFilter ==
                                      'this_week'),
                            ],
                            (value) {
                              widget.onDueDateChanged(
                                  value == widget.selectedDueDateFilter
                                      ? null
                                      : value);
                            },
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              material.OutlinedButton(
                                onPressed: widget.onClearAll,
                                style: material.OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF111827),
                                  side: const BorderSide(
                                      color: Color(0xFFE5E7EB)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Clear all',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              material.ElevatedButton(
                                onPressed: _closeDropdown,
                                style: material.ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                child: const Text(
                                  'Done',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(_FilterOption option, VoidCallback onTap) {
    return material.InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: option.isSelected
              ? const Color(0xFFDBEAFE)
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: option.isSelected
                ? const Color(0xFF93C5FD)
                : const Color(0xFFE5E7EB),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          option.label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: option.isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<_FilterOption> options,
    Function(String?) onChanged, {
    bool equalWidth = false,
  }) {
    if (options.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: _labelStyle),
        const SizedBox(height: 8),
        if (equalWidth)
          Row(
            children: [
              for (var i = 0; i < options.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _buildFilterChip(
                    options[i],
                    () => onChanged(options[i].value),
                  ),
                ),
              ],
            ],
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((option) {
              return IntrinsicWidth(
                child: _buildFilterChip(
                  option,
                  () => onChanged(option.value),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  @override
  void dispose() {
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
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFDBEAFE) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              material.Icon(
                material.Icons.tune_rounded,
                size: 16,
                color: isActive
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF374151),
              ),
              const SizedBox(width: 6),
              Text(
                'Filter',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF374151),
                ),
              ),
              const SizedBox(width: 4),
              material.Icon(
                _isOpen
                    ? material.Icons.keyboard_arrow_up
                    : material.Icons.keyboard_arrow_down,
                size: 18,
                color: isActive
                    ? const Color(0xFF1D4ED8)
                    : const Color(0xFF9CA3AF),
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

class _DueDateCalendarPanel extends StatelessWidget {
  const _DueDateCalendarPanel({
    required this.viewedMonth,
    required this.selectedDate,
    required this.onViewedMonthChanged,
    required this.onSelected,
    required this.onClear,
    required this.onToday,
  });

  final DateTime viewedMonth;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onViewedMonthChanged;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onClear;
  final VoidCallback onToday;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(viewedMonth.year, viewedMonth.month, 1);
    // Sunday-start grid to match the mockup.
    final startOffset = firstOfMonth.weekday % 7;
    final daysInMonth =
        DateTime(viewedMonth.year, viewedMonth.month + 1, 0).day;
    final today = _dateOnly(DateTime.now());
    final selected =
        selectedDate != null ? _dateOnly(selectedDate!) : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              material.InkWell(
                onTap: () => onViewedMonthChanged(
                  DateTime(viewedMonth.year, viewedMonth.month - 1),
                ),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    CupertinoIcons.chevron_left,
                    size: 16,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  DateFormat('MMMM yyyy').format(firstOfMonth),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              material.InkWell(
                onTap: () => onViewedMonthChanged(
                  DateTime(viewedMonth.year, viewedMonth.month + 1),
                ),
                borderRadius: BorderRadius.circular(16),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 16,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: const [
              Expanded(child: Center(child: Text('S', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('M', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('T', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('W', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('T', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('F', style: _weekdayStyle))),
              Expanded(child: Center(child: Text('S', style: _weekdayStyle))),
            ],
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 42,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              final dayNum = index - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox.shrink();
              }
              final date =
                  DateTime(viewedMonth.year, viewedMonth.month, dayNum);
              final isSelected = selected == date;
              final isToday = today == date;
              return material.InkWell(
                onTap: () => onSelected(date),
                customBorder: const CircleBorder(),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? const Color(0xFFDBEAFE)
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected || isToday
                          ? const Color(0xFF93C5FD)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              material.OutlinedButton(
                onPressed: onClear,
                style: material.OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  minimumSize: const Size(88, 40),
                  tapTargetSize: material.MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Clear',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              material.OutlinedButton(
                onPressed: onToday,
                style: material.OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF374151),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  minimumSize: const Size(88, 40),
                  tapTargetSize: material.MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Today',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _weekdayStyle = TextStyle(
  fontFamily: 'Inter',
  fontSize: 12,
  fontWeight: FontWeight.w500,
  color: Color(0xFF9CA3AF),
);
