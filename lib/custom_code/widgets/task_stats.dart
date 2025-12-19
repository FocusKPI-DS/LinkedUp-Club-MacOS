import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';

class TaskStats extends StatefulWidget {
  const TaskStats({super.key});

  @override
  State<TaskStats> createState() => _TaskStatsState();
}

class _TaskStatsState extends State<TaskStats> {
  final Set<String> _completedTasks = {};

  @override
  Widget build(BuildContext context) {
    if (currentUserReference == null) {
      return _buildEmptyStats();
    }

    // Get current user's display name for filtering
    final currentUserDisplayName =
        currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .orderBy('created_time', descending: true)
            .limit(200),
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingStats();
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return _buildEmptyStats();
        }

        final allTodos = snapshot.data!;

        // Filter tasks: ONLY show tasks where user is in involved_people
        final filteredTodos = allTodos.where((task) {
          bool isInvolved = false;
          if (currentUserDisplayName.isNotEmpty &&
              task.involvedPeople.isNotEmpty) {
            final displayNameLower =
                currentUserDisplayName.toLowerCase().trim();

            isInvolved = task.involvedPeople.any((name) {
              final nameLower = name.toLowerCase().trim();
              if (nameLower == displayNameLower) {
                return true;
              }
              final nameParts =
                  nameLower.split(',').map((s) => s.trim()).toList();
              for (final part in nameParts) {
                if (part == displayNameLower) {
                  return true;
                }
              }
              return false;
            });
          }
          return isInvolved;
        }).toList();

        // Deduplicate tasks by normalized title
        final Map<String, ActionItemsRecord> uniqueTodos = {};
        for (var todo in filteredTodos) {
          final titleKey = todo.title.toLowerCase().trim();
          if (!uniqueTodos.containsKey(titleKey)) {
            uniqueTodos[titleKey] = todo;
          }
        }
        final uniqueAllTodos = uniqueTodos.values.toList();

        final pending = uniqueAllTodos
            .where((t) =>
                t.status == 'pending' &&
                !_completedTasks.contains(t.reference.path))
            .length;
        final completed = uniqueAllTodos
            .where((t) =>
                t.status == 'completed' ||
                _completedTasks.contains(t.reference.path))
            .length;
        final total = uniqueAllTodos.length;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and AI Insights button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Task Stats',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement AI Insights
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'AI Insights',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Circular progress indicator
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Background circle
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: CircularProgressIndicator(
                          value: total > 0 ? (completed / total) : 0.0,
                          strokeWidth: 20,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2563EB)),
                        ),
                      ),
                      // Center content
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            pending.toString(),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pending Tasks',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Total', total.toString()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Completed', completed.toString()),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _buildEmptyStats() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task Stats',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: 0.0,
                      strokeWidth: 20,
                      backgroundColor: const Color(0xFFF1F5F9),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color.fromARGB(255, 16, 184, 239)),
                    ),
                  ),
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '0',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 48,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Pending Tasks',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _buildStatCard('Total', '0'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard('Completed', '0'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
