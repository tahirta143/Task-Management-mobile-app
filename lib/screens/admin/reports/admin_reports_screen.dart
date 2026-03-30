import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/report_models.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AdminProvider>();
      ap.fetchDashboardReport();
      ap.fetchUserPerformance();
      ap.fetchCompanySummary();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final ap = Provider.of<AdminProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Reports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: ap.isLoading && ap.overview == null
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedBlock(0, const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
            const SizedBox(height: 4),
            _buildAnimatedBlock(100, Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reports & Analytics', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: th.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12)
                  ),
                  child: Icon(LucideIcons.slidersHorizontal, size: 20, color: th.colorScheme.primary),
                )
              ],
            )),
            const SizedBox(height: 24),

            if (ap.overview != null)
            _buildAnimatedBlock(200, SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildKpiCard(isDark, LucideIcons.layers, Colors.cyan, ap.overview!.totalTasks.toString(), 'Total Tasks'),
                  const SizedBox(width: 12),
                  _buildKpiCard(isDark, LucideIcons.clock, Colors.amber, ap.overview!.counts['pending']?.toString() ?? '0', 'Pending'),
                  const SizedBox(width: 12),
                  _buildKpiCard(isDark, LucideIcons.trendingUp, Colors.blue, ap.overview!.counts['inProgress']?.toString() ?? '0', 'In Progress'),
                  const SizedBox(width: 12),
                  _buildKpiCard(isDark, LucideIcons.checkCircle, Colors.green, ap.overview!.totalCompleted.toString(), 'Completed'),
                  const SizedBox(width: 12),
                  _buildKpiCard(isDark, LucideIcons.alertCircle, Colors.red, ap.overview!.overdueTasks.toString(), 'Overdue'),
                ],
              ),
            )),
            const SizedBox(height: 24),

            _buildAnimatedBlock(300, _buildPerformanceList(isDark, th, ap.userPerformance)),
          ],
        ),
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

  Widget _buildKpiCard(bool isDark, IconData icon, Color color, String value, String label) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildPerformanceList(bool isDark, ThemeData th, List<UserPerformance> performance) {
    if (performance.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.users, size: 16),
              SizedBox(width: 8),
              Text('User Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          ...performance.map((u) {
            final int pct = u.completionRate;
            Color barColor = th.colorScheme.primary;
            if (pct >= 80) barColor = Colors.green;
            else if (pct <= 50) barColor = Colors.red;

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('Tasks: ${u.assigned} | Completed: ${u.completed}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                      Text('$pct%', style: TextStyle(fontWeight: FontWeight.bold, color: barColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withAlpha(50),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: pct / 100,
                      child: Container(
                        decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                  )
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
