import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:fl_chart/fl_chart.dart';
import '/backend/backend.dart';
import '/auth/firebase_auth/auth_util.dart';

class ProductivityTrendChart extends StatefulWidget {
  const ProductivityTrendChart({super.key});

  @override
  State<ProductivityTrendChart> createState() => _ProductivityTrendChartState();
}

class _ProductivityTrendChartState extends State<ProductivityTrendChart> {
  @override
  Widget build(BuildContext context) {
    if (currentUserReference == null) {
      return _buildEmptyChart();
    }

    // Get current user's display name for filtering
    final currentUserDisplayName =
        currentUserDocument?.displayName ?? currentUser?.displayName ?? '';

    return StreamBuilder<List<ActionItemsRecord>>(
      stream: queryActionItemsRecord(
        queryBuilder: (actionItemsRecord) => actionItemsRecord
            .where('status', isEqualTo: 'completed')
            .orderBy('created_time', descending: true)
            .limit(500), // Get more tasks to filter in memory
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingChart();
        }

        if (snapshot.hasError) {
          return _buildEmptyChart();
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyChart();
        }

        final sevenDaysAgo = _getSevenDaysAgo();

        // Filter tasks: must belong to current user (by user_ref or involved_people)
        // and have completed_time in last 7 days
        final completedTasks = snapshot.data!.where((task) {
          // Check if task belongs to current user
          bool belongsToUser = false;

          // Check user_ref
          if (task.userRef == currentUserReference) {
            belongsToUser = true;
          }

          // Also check involved_people as fallback
          if (!belongsToUser &&
              currentUserDisplayName.isNotEmpty &&
              task.involvedPeople.isNotEmpty) {
            final displayNameLower =
                currentUserDisplayName.toLowerCase().trim();
            belongsToUser = task.involvedPeople.any((name) {
              final nameLower = name.toLowerCase().trim();
              if (nameLower == displayNameLower) return true;
              // Check comma-separated names
              final nameParts =
                  nameLower.split(',').map((s) => s.trim()).toList();
              return nameParts.any((part) => part == displayNameLower);
            });
          }

          // Must belong to user, have completed_time, and be within last 7 days
          return belongsToUser &&
              task.completedTime != null &&
              task.completedTime!.isAfter(sevenDaysAgo);
        }).toList();

        if (completedTasks.isEmpty) {
          return _buildEmptyChart();
        }

        // Group tasks by day
        final dailyCounts = _groupTasksByDay(completedTasks);

        return _buildChart(dailyCounts);
      },
    );
  }

  DateTime _getSevenDaysAgo() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 7));
  }

  Map<int, int> _groupTasksByDay(List<ActionItemsRecord> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Initialize map with last 7 days (index 0-6 represents days ago)
    final Map<int, int> dailyCounts = {};
    for (int i = 0; i < 7; i++) {
      dailyCounts[i] = 0;
    }

    // Count tasks per day
    for (final task in tasks) {
      if (task.completedTime != null) {
        final completedDate = DateTime(
          task.completedTime!.year,
          task.completedTime!.month,
          task.completedTime!.day,
        );

        // Check if within last 7 days
        final daysDiff = today.difference(completedDate).inDays;
        if (daysDiff >= 0 && daysDiff < 7) {
          // daysDiff = 0 is today, 1 is yesterday, etc.
          // We want to map: 6 days ago -> index 0, 5 days ago -> index 1, ..., today -> index 6
          final index = 6 - daysDiff;
          dailyCounts[index] = (dailyCounts[index] ?? 0) + 1;
        }
      }
    }

    return dailyCounts;
  }

  Widget _buildChart(Map<int, int> dailyCounts) {
    // Get last 7 days
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Create list of last 7 days (6 days ago to today)
    final List<MapEntry<String, int>> chartData = [];
    for (int i = 0; i < 7; i++) {
      final daysAgo = 6 - i; // 6 days ago, 5 days ago, ..., today
      final date = today.subtract(Duration(days: daysAgo));
      final dayName = _getDayAbbreviation(date.weekday);
      chartData.add(MapEntry(dayName, dailyCounts[i] ?? 0));
    }

    // Find max value for Y-axis scaling
    final maxValue =
        chartData.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final yMax = maxValue > 15 ? (maxValue + 2) : 15;

    final spots = chartData.asMap().entries.map((entry) {
      return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
    }).toList();

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'User Productivity Trends',
            style: TextStyle(
              fontFamily: '.SF Pro Display',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Task completion, last 7 days',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: CupertinoColors.secondaryLabel,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 28),
          // Chart
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: const Color(0xFFE5E7EB),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 35,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < chartData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              chartData[index].key,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(
                    color: const Color(0xFFE5E7EB),
                    width: 1,
                  ),
                ),
                minX: 0,
                maxX: (chartData.length - 1).toDouble(),
                minY: 0,
                maxY: yMax.toDouble(),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((LineBarSpot touchedSpot) {
                        final index = touchedSpot.x.toInt();
                        if (index >= 0 && index < chartData.length) {
                          return LineTooltipItem(
                            '${chartData[index].key}\n${chartData[index].value} tasks',
                            const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          );
                        }
                        return null;
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF2563EB),
                    barWidth: 3.5,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 5,
                          color: const Color(0xFF2563EB),
                          strokeWidth: 3,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: const Color(0xFF2563EB).withOpacity(0.08),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFF2563EB).withOpacity(0.15),
                          const Color(0xFF2563EB).withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayAbbreviation(int weekday) {
    // weekday: 1 = Monday, 7 = Sunday
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    // Convert: 1->Mon(0), 2->Tue(1), ..., 7->Sun(6)
    final index = weekday == 7 ? 6 : weekday - 1;
    return days[index];
  }

  Widget _buildLoadingChart() {
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
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
        ),
      ),
    );
  }

  Widget _buildEmptyChart() {
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
            'User Productivity Trends',
            style: TextStyle(
              fontFamily: '.SF Pro Display',
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label,
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Task completion, last 7 days',
            style: TextStyle(
              fontFamily: '.SF Pro Text',
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: CupertinoColors.secondaryLabel,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.show_chart,
                  size: 48,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'No data available',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete some tasks to see your productivity trend',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
