import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';

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

  // Track expanded state for Details dropdowns
  final Set<String> _expandedDetails = {};

  @override
  Widget build(BuildContext context) {
    if (currentUserReference == null) {
      return _buildEmptyState(context, filter: _selectedFilter);
    }

    // Get current user's display name for filtering
    final currentUserDisplayName =
        currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) {
          // Safe query: use user_ref which is indexed, then filter by name client-side
          return actionItemsRecord
              .where('user_ref', isEqualTo: currentUserReference)
              .orderBy('created_time', descending: true)
              .limit(100);
        },
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

        // Filter: only show tasks assigned to user by name (if name is available)
        // If no name, show all tasks from user_ref (fallback)
        final filteredTodos = currentUserDisplayName.isNotEmpty
            ? allTodos
                .where((t) => t.involvedPeople.contains(currentUserDisplayName))
            : allTodos;

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

        // Deduplicate tasks by normalized title
        final Map<String, ActionItemsRecord> uniqueTodos = {};
        for (var todo in statusFilteredTodos) {
          final titleKey = todo.title.toLowerCase().trim();
          if (!uniqueTodos.containsKey(titleKey)) {
            uniqueTodos[titleKey] = todo;
          }
        }
        final todos = uniqueTodos.values.toList();

        // Calculate statistics (deduplicated)
        final Map<String, ActionItemsRecord> uniqueForStats = {};
        for (var todo in filteredTodos) {
          final titleKey = todo.title.toLowerCase().trim();
          if (!uniqueForStats.containsKey(titleKey)) {
            uniqueForStats[titleKey] = todo;
          }
        }
        final uniqueAllTodos = uniqueForStats.values.toList();

        final pending = uniqueAllTodos
            .where((t) =>
                t.status == 'pending' &&
                !_completedTasks.contains(t.reference.path))
            .length;
        final inProgress = uniqueAllTodos
            .where((t) =>
                t.status == 'in-progress' &&
                !_completedTasks.contains(t.reference.path))
            .length;
        final completed = uniqueAllTodos
            .where((t) =>
                t.status == 'completed' ||
                _completedTasks.contains(t.reference.path))
            .length;
        final total = uniqueAllTodos.length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [
                Color(0xFFEFF6FF),
                Colors.white,
                Color(0xFFF8FAFC),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Text
              const Text(
                'Your Action Items',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
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

              const SizedBox(height: 10),

              // Summary Cards
              _buildSummaryCards(
                  context, total, pending, inProgress, completed),

              const SizedBox(height: 10),

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

  Widget _buildTodoList(List<ActionItemsRecord> todos) {
    return ListView.builder(
      key: ValueKey('todos-list-${_selectedFilter}'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: todos.length,
      itemBuilder: (context, index) {
        final todo = todos[index];
        return _buildTodoRow(context, todo, index);
      },
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
                // Top row: Priority, Group name, Assigned + Due
                Row(
                  children: [
                    _buildPriorityBadge(todo.priority),
                    const SizedBox(width: 8),
                    Flexible(
                      fit: FlexFit.loose,
                      child: (todo.groupName.isNotEmpty || todo.chatRef == null)
                          ? Text(
                              todo.groupName,
                              style: const TextStyle(
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

                // Task title
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

                // Task details row (people only)
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

                const SizedBox(height: 2),

                // (Due date moved to top row)

                const SizedBox(height: 4),

                // Details toggle button
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
                  duration: const Duration(milliseconds: 120),
                  child: _expandedDetails.contains(todo.reference.id)
                      ? Container(
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
                        )
                      : const SizedBox.shrink(),
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

            // Checkbox in top right
            Positioned(
              top: -10,
              right: -10,
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

  Widget _buildSummaryCards(BuildContext context, int total, int pending,
      int inProgress, int completed) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_selectedFilter != 'all') {
                setState(() {
                  _selectedFilter = 'all';
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: _buildSummaryCard(
                'Total',
                total.toString(),
                Icons.access_time_outlined,
                const Color(0xFF1E293B),
                isSelected: _selectedFilter == 'all',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_selectedFilter != 'pending') {
                setState(() {
                  _selectedFilter = 'pending';
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: _buildSummaryCard(
                'Pending',
                pending.toString(),
                Icons.info_outline,
                const Color(0xFF1E293B),
                isSelected: _selectedFilter == 'pending',
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (_selectedFilter != 'completed') {
                setState(() {
                  _selectedFilter = 'completed';
                });
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
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
        color: isHighlighted && highlightedBackground != null
            ? highlightedBackground
            : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? const Color(0xFF3B82F6) // Light blue border when selected
              : (isHighlighted
                  ? color.withOpacity(0.3)
                  : const Color(0xFFE5E7EB)),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? const Color(0xFF3B82F6).withOpacity(0.15)
                : (isHighlighted
                    ? color.withOpacity(0.1)
                    : const Color(0xFF1F2937).withOpacity(0.04)),
            blurRadius: isSelected ? 12 : (isHighlighted ? 12 : 4),
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
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

  Widget _buildErrorState(BuildContext context, String error) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 16),
            const Text(
              'Error loading tasks',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
}
