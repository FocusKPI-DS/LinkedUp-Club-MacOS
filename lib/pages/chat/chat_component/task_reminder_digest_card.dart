import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ff_theme/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Paths of action items marked done (persists across rebuilds so we show them as completed).
final Set<String> _kCompletedActionItemPaths = {};

/// Cache: digest task-set key -> completed paths from Firestore. Stops flicker when parent rebuilds.
final Map<String, Set<String>> _kCompletedPathsCache = {};

/// True if this action item path was marked done (show as completed / strikethrough).
bool _isActionItemPathCompleted(String? path) {
  if (path == null || path.isEmpty) return false;
  if (_kCompletedActionItemPaths.contains(path)) return true;
  if (path.contains('/'))
    return _kCompletedActionItemPaths.contains(path.split('/').last);
  return false;
}

/// Stable key for a task list (so we only reload when tasks actually change).
String _tasksCacheKey(List<Map<String, dynamic>> tasks) {
  final paths = <String>[];
  for (final t in tasks) {
    final refRaw = t['action_item_ref'];
    final p = refRaw == null
        ? ''
        : refRaw is String
            ? refRaw
            : (refRaw is DocumentReference ? refRaw.path : '');
    if (p.isNotEmpty) paths.add(p);
  }
  paths.sort();
  return paths.join('|');
}

/// Shared aesthetic card for task reminder digest (Urgent Digest).
/// Used both from reminder_digests collection (group chat section) and from message task_reminders payload.
/// Optional [onMarkDone] and [onRemindAgain] take action_items doc path; when provided, Done/Remind Again buttons are wired.
/// When Done is tapped, the task is marked completed in Firestore and the card shows as completed (strikethrough, muted).
class TaskReminderDigestCard extends StatefulWidget {
  const TaskReminderDigestCard({
    super.key,
    required this.overdueCount,
    required this.introText,
    required this.tasks,
    this.onMarkDone,
    this.onRemindAgain,
  });

  final int overdueCount;
  final String introText;
  final List<Map<String, dynamic>> tasks;
  final void Function(String actionItemRefPath)? onMarkDone;
  final void Function(String actionItemRefPath)? onRemindAgain;

  /// Build from ReminderDigestsRecord or from message task_reminders map.
  static TaskReminderDigestCard fromPayload(
    Map<String, dynamic> payload, {
    void Function(String actionItemRefPath)? onMarkDone,
    void Function(String actionItemRefPath)? onRemindAgain,
  }) {
    final overdueCount = (payload['overdue_count'] is num)
        ? (payload['overdue_count'] as num).toInt()
        : 0;
    final introText = payload['intro_text'] as String? ?? '';
    final tasksRaw = payload['tasks'];
    final tasks = (tasksRaw is List)
        ? tasksRaw
            .map((e) => e is Map<String, dynamic>
                ? Map<String, dynamic>.from(e)
                : <String, dynamic>{})
            .toList()
        : <Map<String, dynamic>>[];
    return TaskReminderDigestCard(
      overdueCount: overdueCount,
      introText: introText,
      tasks: tasks,
      onMarkDone: onMarkDone,
      onRemindAgain: onRemindAgain,
    );
  }

  @override
  State<TaskReminderDigestCard> createState() => _TaskReminderDigestCardState();
}

class _TaskReminderDigestCardState extends State<TaskReminderDigestCard> {
  /// Task paths marked done in this session (show as completed).
  final Set<String> _completedTaskPaths = {};

  /// Paths that are completed in Firestore (so we show them completed after rebuild).
  Set<String>? _completedPathsFromFirestore;

  /// Collapsed: only Urgent Digest heading visible (smaller); expanded: full content.
  bool _isExpanded = true;

  /// Randomly chosen intro line (set once in initState for stable UX).
  late String _displayIntroText;

  static const List<String> _introOptions = [
    'Several critical actions need your attention to keep things on track.',
    'A few items need a quick look—check them off when you\'re done.',
    'Here are your pending items. Mark them done as you go.',
    'Quick heads-up: some action items are waiting on you.',
    'Your attention is needed on a few tasks below.',
    'Stay on top of things—tackle these items when you can.',
  ];

  // Urgent Digest header – warm orange/amber (reference style)
  static const Color _headerBg = Color(0xFFFFF7ED);
  static const Color _headerAccent = Color(0xFFC2410C);
  static const Color _badgeBg = Color(0xFFFED7AA);
  // Priority badge colors
  static const Color _priorityUrgent = Color(0xFFDC2626);
  static const Color _priorityHigh = Color(0xFFDC2626);
  static const Color _priorityMedium = Color(0xFFEA580C);
  static const Color _priorityLow = Color(0xFF6B7280);
  static const Color _priorityUrgentBg = Color(0xFFFEE2E2);
  static const Color _priorityHighBg = Color(0xFFFEE2E2);
  static const Color _priorityMediumBg = Color(0xFFFFEDD5);
  static const Color _priorityLowBg = Color(0xFFF3F4F6);
  // Actions
  static const Color _doneBlue = Color(0xFF2563EB);
  static const Color _remindOutline = Color(0xFF2563EB);

  /// Parse due_date or created_time from payload (Timestamp or Map with _seconds).
  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is Map && v['_seconds'] != null) {
      final sec = v['_seconds'] is int
          ? v['_seconds'] as int
          : (v['_seconds'] as num).toInt();
      return DateTime.fromMillisecondsSinceEpoch(sec * 1000);
    }
    return null;
  }

  static String _formatCreated(DateTime? d) {
    if (d == null) return '';
    return DateFormat('MMM d, yyyy').format(d);
  }

  static String _formatDue(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(d.year, d.month, d.day);
    if (dueDay == today) return 'Today, ${DateFormat('h:mm a').format(d)}';
    return '${DateFormat('MMM d').format(d)}, ${DateFormat('h:mm a').format(d)}';
  }

  static bool _isOverdue(DateTime? due) {
    return due != null && due.isBefore(DateTime.now());
  }

  /// Path string for Firestore lookup. Always returns full path "action_items/xxx"
  /// so we match dashboard and backend (ActionItemsRecord lives in action_items collection).
  static String? _actionItemPathFromTask(Map<String, dynamic> t) {
    final refRaw = t['action_item_ref'];
    if (refRaw == null) return null;
    String? path;
    if (refRaw is String) {
      if (refRaw.isEmpty) return null;
      path = refRaw;
    } else if (refRaw is DocumentReference) {
      path = refRaw.path;
    } else {
      return null;
    }
    // Normalize to full path so Firestore.doc(path) hits action_items/xxx
    if (path.contains('/')) return path;
    return 'action_items/$path';
  }

  String get _cacheKey => _tasksCacheKey(widget.tasks);

  Future<void> _loadCompletedPathsFromFirestore() async {
    if (widget.tasks.isEmpty) {
      if (mounted) setState(() => _completedPathsFromFirestore = {});
      _kCompletedPathsCache[_cacheKey] = {};
      return;
    }
    final paths = <String>[];
    for (final t in widget.tasks) {
      final path = _actionItemPathFromTask(t);
      if (path != null && path.isNotEmpty) paths.add(path);
    }
    if (paths.isEmpty) {
      if (mounted) setState(() => _completedPathsFromFirestore = {});
      _kCompletedPathsCache[_cacheKey] = {};
      return;
    }
    try {
      final snaps = await Future.wait(
        paths.map((p) => FirebaseFirestore.instance.doc(p).get()),
      );
      final completed = <String>{};
      for (int i = 0; i < paths.length; i++) {
        if (i < snaps.length &&
            snaps[i].exists &&
            snaps[i].data()?['status'] == 'completed') {
          completed.add(paths[i]);
        }
      }
      _kCompletedPathsCache[_cacheKey] = completed;
      if (!mounted) return;
      final same = _completedPathsFromFirestore != null &&
          _completedPathsFromFirestore!.length == completed.length &&
          completed.every(_completedPathsFromFirestore!.contains);
      if (!same) setState(() => _completedPathsFromFirestore = completed);
    } catch (_) {
      _kCompletedPathsCache[_cacheKey] = {};
      if (mounted) setState(() => _completedPathsFromFirestore = {});
    }
  }

  /// Normalize to full path for consistent comparison with backend/dashboard.
  static String _normalizePath(String? path) {
    if (path == null || path.isEmpty) return path ?? '';
    if (path.contains('/')) return path;
    return 'action_items/$path';
  }

  bool _isTaskCompleted(String? actionItemRefPath) {
    if (actionItemRefPath == null || actionItemRefPath.isEmpty) return false;
    final normalized = _normalizePath(actionItemRefPath);
    if (_completedTaskPaths.contains(actionItemRefPath) ||
        _completedTaskPaths.contains(normalized)) return true;
    if (_isActionItemPathCompleted(actionItemRefPath) ||
        _isActionItemPathCompleted(normalized)) return true;
    if (_completedPathsFromFirestore != null &&
        (_completedPathsFromFirestore!.contains(actionItemRefPath) ||
            _completedPathsFromFirestore!.contains(normalized))) return true;
    final id = actionItemRefPath.contains('/')
        ? actionItemRefPath.split('/').last
        : actionItemRefPath;
    if (_completedPathsFromFirestore != null &&
        _completedPathsFromFirestore!.any((p) => p.endsWith('/$id')))
      return true;
    return false;
  }

  @override
  void initState() {
    super.initState();
    _displayIntroText = _introOptions[Random().nextInt(_introOptions.length)];
    final key = _cacheKey;
    final cached = _kCompletedPathsCache[key];
    if (cached != null) {
      _completedPathsFromFirestore = Set<String>.from(cached);
    }
    _loadCompletedPathsFromFirestore();
  }

  @override
  void didUpdateWidget(covariant TaskReminderDigestCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey = _tasksCacheKey(oldWidget.tasks);
    final newKey = _cacheKey;
    if (oldKey == newKey) return;
    final cached = _kCompletedPathsCache[newKey];
    if (cached != null) {
      _completedPathsFromFirestore = Set<String>.from(cached);
    } else {
      _completedPathsFromFirestore = null;
    }
    _loadCompletedPathsFromFirestore();
  }

  void _onDoneTapped(String actionItemRefPath) {
    widget.onMarkDone?.call(actionItemRefPath);
    _kCompletedActionItemPaths.add(actionItemRefPath);
    if (actionItemRefPath.contains('/'))
      _kCompletedActionItemPaths.add(actionItemRefPath.split('/').last);
    setState(() {
      _completedTaskPaths.add(actionItemRefPath);
      _completedPathsFromFirestore ??= {};
      _completedPathsFromFirestore!.add(actionItemRefPath);
      _kCompletedPathsCache[_cacheKey] =
          Set<String>.from(_completedPathsFromFirestore!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final completedCount = widget.tasks.where((t) {
      final path = _actionItemPathFromTask(t);
      return path != null && _isTaskCompleted(path);
    }).length;
    final visibleCount =
        (widget.tasks.length - completedCount).clamp(0, widget.tasks.length);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _headerAccent.withOpacity(0.15),
            child: const Icon(
              Icons.notification_important_outlined,
              size: 22,
              color: _headerAccent,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Urgent Digest + N ITEMS OVERDUE (warm orange)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                      decoration: const BoxDecoration(
                        color: _headerBg,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              size: 20, color: _headerAccent),
                          const SizedBox(width: 8),
                          Text(
                            'Urgent Digest',
                            style: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Inter',
                                  color: const Color(0xFF9A3412),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _badgeBg,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$visibleCount ITEMS OVERDUE',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    fontFamily: 'Inter',
                                    color: _headerAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isExpanded) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Text(
                        _displayIntroText,
                        style:
                            FlutterFlowTheme.of(context).bodySmall.override(
                                  fontFamily: 'Inter',
                                  color: const Color(0xFF5F6368),
                                  fontSize: 13,
                                ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: Divider(
                          height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                    ),
                    // Task cards – all tasks shown; completed ones with strikethrough and muted style
                    ...widget.tasks.asMap().entries.map((entry) {
                      final t = entry.value;
                      final title = t['title'] as String? ?? 'Task';
                      final priority = (t['priority'] as String? ?? 'Moderate')
                          .toString()
                          .toUpperCase();
                      final involved = t['involved_people'] is List
                          ? (t['involved_people'] as List)
                              .map((e) => e?.toString() ?? '')
                              .where((s) => s.isNotEmpty)
                              .toList()
                          : <String>[];
                      final involvedStr = involved.isEmpty
                          ? 'Everyone'
                          : involved.map((s) => '@$s').join(', ');
                      final created = _parseDate(t['created_time']);
                      final due = _parseDate(t['due_date']);
                      final overdue = _isOverdue(due);
                      final refRaw = t['action_item_ref'];
                      final String? actionItemRefPath = refRaw is String
                          ? (refRaw.isNotEmpty ? refRaw : null)
                          : (refRaw is DocumentReference ? refRaw.path : null);
                      final isCompleted = actionItemRefPath != null &&
                          _isTaskCompleted(actionItemRefPath);
                      final hasActions = !isCompleted &&
                          (widget.onMarkDone != null ||
                              widget.onRemindAgain != null) &&
                          actionItemRefPath != null;

                      final muted = isCompleted;
                      final textColor = muted
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF202124);
                      final secondaryColor = muted
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280);

                      Color priorityBg = _priorityMediumBg;
                      Color priorityFg = _priorityMedium;
                      if (priority == 'URGENT') {
                        priorityBg = _priorityUrgentBg;
                        priorityFg = _priorityUrgent;
                      } else if (priority == 'HIGH') {
                        priorityBg = _priorityHighBg;
                        priorityFg = _priorityHigh;
                      } else if (priority == 'LOW') {
                        priorityBg = _priorityLowBg;
                        priorityFg = _priorityLow;
                      } else {
                        priorityBg = _priorityMediumBg;
                        priorityFg = _priorityMedium;
                      }
                      if (muted) {
                        priorityBg = const Color(0xFFF3F4F6);
                        priorityFg = const Color(0xFF9CA3AF);
                      }

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                muted ? const Color(0xFFF9FAFB) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: muted
                                  ? const Color(0xFFE5E7EB)
                                  : const Color(0xFFE5E7EB),
                            ),
                            boxShadow: muted
                                ? []
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.04),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: priorityBg,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      isCompleted
                                          ? 'COMPLETED'
                                          : (priority == 'MODERATE'
                                              ? 'MEDIUM'
                                              : priority),
                                      style: FlutterFlowTheme.of(context)
                                          .bodySmall
                                          .override(
                                            fontFamily: 'Inter',
                                            color: priorityFg,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                title,
                                style: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: textColor,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                involvedStr,
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      fontFamily: 'Inter',
                                      color: secondaryColor,
                                      fontSize: 12,
                                      decoration: isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                              ),
                              if (created != null || due != null) ...[
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 6,
                                  children: [
                                    if (created != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.calendar_today_outlined,
                                              size: 14, color: secondaryColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Created: ${_formatCreated(created)}',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  fontFamily: 'Inter',
                                                  color: secondaryColor,
                                                  fontSize: 12,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                          ),
                                        ],
                                      ),
                                    if (due != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.schedule_outlined,
                                            size: 14,
                                            color: muted
                                                ? secondaryColor
                                                : (overdue
                                                    ? _priorityHigh
                                                    : const Color(0xFF6B7280)),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Due: ${_formatDue(due)}',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  fontFamily: 'Inter',
                                                  color: muted
                                                      ? secondaryColor
                                                      : (overdue
                                                          ? _priorityHigh
                                                          : const Color(
                                                              0xFF6B7280)),
                                                  fontSize: 12,
                                                  fontWeight: overdue && !muted
                                                      ? FontWeight.w600
                                                      : FontWeight.normal,
                                                  decoration: isCompleted
                                                      ? TextDecoration
                                                          .lineThrough
                                                      : null,
                                                ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                              if (hasActions) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Material(
                                      color: _doneBlue,
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        onTap: () =>
                                            _onDoneTapped(actionItemRefPath),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check,
                                                  size: 18,
                                                  color: Colors.white),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Done',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: Colors.white,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () => widget.onRemindAgain
                                            ?.call(actionItemRefPath),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 8),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                                color: _remindOutline),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                  Icons
                                                      .notifications_active_outlined,
                                                  size: 18,
                                                  color: _remindOutline),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Remind Again',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          fontFamily: 'Inter',
                                                          color: _remindOutline,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(Icons.more_horiz,
                                        size: 20,
                                        color: const Color(0xFF9CA3AF)),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    }),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'Make sure to mark items done when you\'re finished.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                    ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      child: Center(
                        child: IconButton(
                          icon: Icon(
                            _isExpanded
                                ? Icons.keyboard_arrow_up
                                : Icons.keyboard_arrow_down,
                            size: 28,
                            color: _headerAccent,
                          ),
                          onPressed: () =>
                              setState(() => _isExpanded = !_isExpanded),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 40, minHeight: 40),
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
    );
  }
}
