/*
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedBlock(0, const Text('Tracking', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
          const SizedBox(height: 4),
          _buildAnimatedBlock(100, const Text('Task Progress', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5))),
          const SizedBox(height: 24),
          
          _buildAnimatedBlock(200, _buildStatsRow(isDark)),
          const SizedBox(height: 24),

          _buildAnimatedBlock(300, _buildTaskProgressList(isDark, th)),
        ],
      ),
    );
  }

  Widget _buildAnimatedBlock(int delayMs, Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delayMs),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildStatsRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatCard(isDark, LucideIcons.target, Colors.cyan, '24', 'Total Tasks'),
          const SizedBox(width: 12),
          _buildStatCard(isDark, LucideIcons.checkCircle2, Colors.green, '12', 'Completed'),
          const SizedBox(width: 12),
          _buildStatCard(isDark, LucideIcons.trendingUp, Colors.blue, '8', 'On Track'),
          const SizedBox(width: 12),
          _buildStatCard(isDark, LucideIcons.alertTriangle, Colors.red, '4', 'Overdue'),
          const SizedBox(width: 12),
          _buildStatCard(isDark, LucideIcons.flame, Colors.orange, '68%', 'Avg Progress'),
        ],
      ),
    );
  }

  Widget _buildStatCard(bool isDark, IconData icon, Color color, String value, String label) {
    return Container(
      width: 110,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTaskProgressList(bool isDark, ThemeData th) {
    final tasks = [
      {'title': 'Implement Auth Module', 'pct': 100, 'priority': 'HIGH', 'status': 'completed', 'date': '12/10/2026'},
      {'title': 'Dashboard Layout Design', 'pct': 80, 'priority': 'MEDIUM', 'status': 'in_progress', 'date': '15/10/2026'},
      {'title': 'Fix Navigation Bug in Sidebar', 'pct': 45, 'priority': 'URGENT', 'status': 'in_progress', 'date': '13/10/2026'},
      {'title': 'Update User Schema DB', 'pct': 15, 'priority': 'LOW', 'status': 'overdue', 'date': '05/10/2026'},
      {'title': 'Draft Marketing Copy', 'pct': 0, 'priority': 'LOW', 'status': 'pending', 'date': '20/10/2026'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('All Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${tasks.length} tasks', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 24),
          ...tasks.asMap().entries.map((e) => _buildAnimatedBlock(e.key * 100, _buildTaskRow(e.value, isDark, th))),
        ],
      ),
    );
  }

  Widget _buildTaskRow(Map<String, dynamic> t, bool isDark, ThemeData th) {
    final int pct = t['pct'];
    final bool completed = t['status'] == 'completed';
    final bool overdue = t['status'] == 'overdue';
    
    Color iconColor = Colors.grey;
    IconData icon = LucideIcons.clock;
    if (completed) { iconColor = Colors.green; icon = LucideIcons.checkCircle2; }
    else if (overdue) { iconColor = Colors.red; icon = LucideIcons.alertTriangle; }

    Color barColor = th.colorScheme.primary;
    if (completed) barColor = Colors.green;
    else if (overdue) barColor = Colors.red;
    else if (pct >= 80) barColor = Colors.orange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  t['title'],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: completed ? TextDecoration.lineThrough : null,
                    color: completed ? Colors.grey : (isDark ? Colors.white : Colors.black),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.withAlpha(50)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(t['priority'], style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                child: Text(t['date'], style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey), textAlign: TextAlign.right),
              ),
              SizedBox(
                width: 35,
                child: Text('$pct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), textAlign: TextAlign.right),
              )
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 10,
            width: double.infinity,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13),
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: pct / 100,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (ctx, val, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: val,
                    child: Container(
                      decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(5)),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Points logged', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text(
                completed ? 'Done' : overdue ? 'Overdue' : 'In progress',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: iconColor),
              ),
            ],
          )
        ],
      ),
    );
  }
}
*/
