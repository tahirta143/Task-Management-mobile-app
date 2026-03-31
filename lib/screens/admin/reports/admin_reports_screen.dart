import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/report_models.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../widgets/custom_loader.dart';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  int _selectedReportTab = 0;
  bool _isTabLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ap = context.read<AdminProvider>();
      ap.fetchDashboardReport();
      ap.fetchUserPerformance();
      ap.fetchCompanySummary();
      ap.fetchProgressTasks();
      ap.fetchUsers();
    });
  }
  @override
  Widget build(BuildContext context) {
    final ap = Provider.of<AdminProvider>(context);
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final filteredTasks = ap.filteredProgressTasks;

    // Aggregated stats from filtered tasks
    final int total = filteredTasks.length;
    final int completed =
        filteredTasks.where((t) => t.status == 'completed').length;
    final int overdue = filteredTasks.where((t) => t.isOverdue).length;
    final int inProgress =
        filteredTasks.where((t) => t.status == 'in_progress').length;
    final int pending =
        filteredTasks.where((t) => t.status == 'pending').length;
    final double avgProgress = total == 0
        ? 0
        : filteredTasks.fold(0, (sum, t) => sum + t.progressPercent) / total;

    // Priority Split Distribution
    final Map<String, int> priorityDist = {
      'urgent': 0,
      'high': 0,
      'medium': 0,
      'low': 0
    };
    for (var t in filteredTasks) {
      if (priorityDist.containsKey(t.priority))
        priorityDist[t.priority] = (priorityDist[t.priority] ?? 0) + 1;
    }

    return Container(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: () async {
          await ap.fetchDashboardReport();
          await ap.fetchUserPerformance();
          await ap.fetchCompanySummary();
          await ap.fetchProgressTasks();
          await ap.fetchUsers();
        },
        child: ap.isLoading
            ? LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: const Center(
                        child: CustomLoader(),
                      ),
                    ),
                  );
                },
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMIN',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: th.colorScheme.primary,
                            letterSpacing: 1.5)),
                    const Text('Reports & Analytics',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),

                    // --- Filter Bar ---
                    _buildAnimatedBlock(
                        150,
                        _FilterBar(
                          selectedPreset: ap.datePreset,
                          selectedUserId: ap.selectedUserId,
                          users: ap.users,
                          onPresetSelected: (preset) async {
                            if (preset == 'custom') {
                              final picked = await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now());
                              if (picked != null)
                                ap.setFilters(
                                    datePreset: 'custom', customRange: picked);
                            } else {
                              ap.setFilters(datePreset: preset, customRange: null);
                            }
                          },
                          onUserSelected: (userId) =>
                              ap.setFilters(selectedUserId: userId),
                        )),
                    const SizedBox(height: 24),

                    // --- KPI Cards ---
                    _buildAnimatedBlock(
                        200,
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildKpiCard(isDark, LucideIcons.layers, Colors.cyan,
                                total.toString(), 'Total Tasks'),
                            _buildKpiCard(
                                isDark,
                                LucideIcons.clock,
                                Colors.amber,
                                (ap.datePreset == 'all' &&
                                        ap.selectedUserId == null
                                    ? (ap.overview?.counts['pending'] ?? 0)
                                    : pending)
                                    .toString(),
                                'Pending'),
                            _buildKpiCard(
                                isDark,
                                LucideIcons.trendingUp,
                                Colors.blue,
                                (ap.datePreset == 'all' &&
                                        ap.selectedUserId == null
                                    ? (ap.overview?.counts['inProgress'] ?? 0)
                                    : inProgress)
                                    .toString(),
                                'In Progress'),
                            _buildKpiCard(
                                isDark,
                                LucideIcons.checkCircle,
                                Colors.green,
                                (ap.datePreset == 'all' &&
                                        ap.selectedUserId == null
                                    ? (ap.overview?.totalCompleted ?? 0)
                                    : completed)
                                    .toString(),
                                'Completed'),
                            _buildKpiCard(isDark, LucideIcons.alertCircle,
                                Colors.red, overdue.toString(), 'Overdue',
                                sub: 'tasks past due date'),
                          ],
                        )),
                    const SizedBox(height: 24),

                    // --- Reports Tab Selector ---
                    _buildAnimatedBlock(
                        250,
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildTabChip(0, LucideIcons.users, 'Performance'),
                              _buildTabChip(1, LucideIcons.barChart, 'Priority'),
                              _buildTabChip(
                                  2, LucideIcons.trendingUp, 'Progress'),
                              _buildTabChip(
                                  3, LucideIcons.building2, 'Companies'),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),

                    // --- Tab content ---
                    _buildAnimatedBlock(
                        300,
                        _buildSelectedReport(isDark, th, ap, filteredTasks,
                            priorityDist, avgProgress.toInt())),
                    const SizedBox(height: 20),

                    // --- Calendar Section ---
                    _buildAnimatedBlock(
                        500, _CalendarCard(progress: filteredTasks)),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildTabChip(int index, IconData icon, String label) {
    final bool isActive = _selectedReportTab == index;
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 14, color: isActive ? Colors.white : (isDark ? Colors.white54 : Colors.black54)),
        label: Text(label, style: TextStyle(fontSize: 11, color: isActive ? Colors.white : null)),
        selected: isActive,
        selectedColor: th.colorScheme.primary,
        onSelected: (selected) {
          if (selected && _selectedReportTab != index) {
            setState(() {
              _isTabLoading = true;
              _selectedReportTab = index;
            });
            Future.delayed(const Duration(milliseconds: 400), () {
              if (mounted) setState(() => _isTabLoading = false);
            });
          }
        },
      ),
    );
  }

  Widget _buildSelectedReport(bool isDark, ThemeData th, AdminProvider ap, List<Task> tasks, Map<String, int> priorityDist, int avgProgress) {
    if (_isTabLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CustomLoader()));
    }

    final List<Widget> reports = [
      _buildUserPerformanceCard(isDark, th, ap),
      _buildPrioritySplitCard(isDark, th, tasks.length, priorityDist, avgProgress),
      _buildTaskProgressCard(isDark, th, tasks),
      _buildCompanyPerformanceCard(isDark, th, ap.companySummary),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: reports[_selectedReportTab],
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

  Widget _buildKpiCard(bool isDark, IconData icon, Color color, String value, String label, {String? sub}) {
    final width = (MediaQuery.of(context).size.width - 44) / 2; // 2 per row
    return Container(
      width: width,
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
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          if (sub != null) Text(sub, style: const TextStyle(fontSize: 8, color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildUserPerformanceCard(bool isDark, ThemeData th, AdminProvider ap) {
    final performance = ap.userPerformance.where((u) {
      if (ap.selectedUserId != null && u.userId != ap.selectedUserId) return false;
      return true;
    }).toList();

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
          const Row(
            children: [
              Icon(LucideIcons.users, size: 16, color: Colors.blue),
              SizedBox(width: 8),
              Text('User Performance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 350,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  ...performance.map((u) {
                    final int pct = u.completionRate;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: th.colorScheme.primary.withAlpha(30),
                                    child: Text(u.username[0].toUpperCase(), style: const TextStyle(fontSize: 10)),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.username, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      Text(u.email ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                                    ],
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(LucideIcons.star, size: 10, color: Colors.amber),
                                      const SizedBox(width: 2),
                                      Text(u.avgScore?.toStringAsFixed(1) ?? '--', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  Text('${u.evaluationCount} evals', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Progress', style: TextStyle(fontSize: 9, color: Colors.grey)),
                              Text('$pct%', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getRateColor(pct))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _UrgencyBar(pct: pct, color: _getRateColor(pct)),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildMiniDot(Colors.amber, '${u.pending} pending'),
                              const SizedBox(width: 8),
                              _buildMiniDot(Colors.blue, '${u.inProgress} active'),
                              const SizedBox(width: 8),
                              _buildMiniDot(Colors.green, '${u.completed} done'),
                            ],
                          )
                        ],
                      ),
                    );
                  }),
                  if (performance.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No performance data available', style: TextStyle(color: Colors.grey, fontSize: 12)))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrioritySplitCard(bool isDark, ThemeData th, int total, Map<String, int> dist, int avgComp) {
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
          const Text('Priority Split', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildPriorityBar('Urgent', dist['urgent'] ?? 0, total, Colors.red),
          _buildPriorityBar('High', dist['high'] ?? 0, total, Colors.orange),
          _buildPriorityBar('Medium', dist['medium'] ?? 0, total, Colors.blue),
          _buildPriorityBar('Low', dist['low'] ?? 0, total, Colors.green),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Avg Completion', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              Text('$avgComp%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _getRateColor(avgComp))),
            ],
          ),
          const SizedBox(height: 8),
          _UrgencyBar(pct: avgComp, color: _getRateColor(avgComp), height: 10),
        ],
      ),
    );
  }

  Widget _buildPriorityBar(String label, int val, int total, Color color) {
    final double pct = total == 0 ? 0 : (val / total);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
              Text('$val · ${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 6),
          _UrgencyBar(pct: (pct * 100).toInt(), color: color, height: 6),
        ],
      ),
    );
  }

  Widget _buildTaskProgressCard(bool isDark, ThemeData th, List<Task> tasks) {
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
              const Row(
                children: [
                  Icon(LucideIcons.trendingUp, size: 16, color: Colors.green),
                  SizedBox(width: 8),
                  Text('Task Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text('${tasks.length} tasks', style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 350,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final t = tasks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Icon(
                                  t.status == 'completed' ? LucideIcons.checkCircle : (t.isOverdue ? LucideIcons.alertTriangle : LucideIcons.clock),
                                  size: 14,
                                  color: t.status == 'completed' ? Colors.green : (t.isOverdue ? Colors.red : Colors.grey),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      decoration: t.status == 'completed' ? TextDecoration.lineThrough : null,
                                      color: t.status == 'completed' ? Colors.grey : null,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${t.progressPercent}%',
                            style: const TextStyle(fontSize: 10, color: Colors.grey, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _UrgencyBar(
                        pct: t.progressPercent,
                        color: t.status == 'completed' ? Colors.green : (t.isOverdue ? Colors.red : Colors.blue),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (tasks.isEmpty) const Center(child: Text('No tasks found for current filters', style: TextStyle(color: Colors.grey, fontSize: 11))),
        ],
      ),
    );
  }

  Widget _buildCompanyPerformanceCard(bool isDark, ThemeData th, List<CompanySummary> summaries) {
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
          const Row(
            children: [
              Icon(LucideIcons.building2, size: 16, color: Colors.cyan),
              SizedBox(width: 8),
              Text('Tasks by Company', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 20),
          ...summaries.map((c) {
            final int pct = c.tasks == 0 ? 0 : (c.completed / c.tasks * 100).toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.companyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          Text('${c.users} users · ${c.tasks} tasks', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                        ],
                      ),
                      Text('$pct%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getRateColor(pct))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _UrgencyBar(pct: pct, color: _getRateColor(pct)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildMiniDot(Color color, String text) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Color _getRateColor(int pct) {
    if (pct >= 75) return Colors.green;
    if (pct >= 40) return Colors.orange;
    return Colors.red;
  }
}

// --- Sub Widgets ---

class _UrgencyBar extends StatelessWidget {
  final int pct;
  final Color color;
  final double height;
  const _UrgencyBar({required this.pct, required this.color, this.height = 6});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(color: Colors.grey.withAlpha(30), borderRadius: BorderRadius.circular(height / 2)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: max(0, min(1.0, pct / 100)),
        child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2))),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selectedPreset;
  final int? selectedUserId;
  final List<User> users;
  final Function(String) onPresetSelected;
  final Function(int?) onUserSelected;

  const _FilterBar({
    required this.selectedPreset,
    this.selectedUserId,
    required this.users,
    required this.onPresetSelected,
    required this.onUserSelected,
  });

  @override
  Widget build(BuildContext context) {
    final presets = [
      {'val': 'all', 'label': 'All time'},
      {'val': 'today', 'label': 'Today'},
      {'val': 'week', 'label': 'This week'},
      {'val': 'month', 'label': 'This month'},
      {'val': '7d', 'label': 'Last 7d'},
      {'val': '30d', 'label': 'Last 30d'},
      {'val': '90d', 'label': 'Last 90d'},
      {'val': 'custom', 'label': 'Custom'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: presets.map((p) {
              final isActive = selectedPreset == p['val'];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(p['label']!, style: const TextStyle(fontSize: 11)),
                  selected: isActive,
                  onSelected: (selected) {
                    if (selected) onPresetSelected(p['val']!);
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int?>(
                value: selectedUserId,
                decoration: InputDecoration(
                  prefixIcon: const Icon(LucideIcons.users, size: 14),
                  hintText: 'All Users',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All Users', style: TextStyle(fontSize: 12))),
                  ...users.map((u) => DropdownMenuItem(value: u.id, child: Text(u.username, style: const TextStyle(fontSize: 12)))),
                ],
                onChanged: onUserSelected,
              ),
            ),
            if (selectedPreset != 'all' || selectedUserId != null) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  onPresetSelected('all');
                  onUserSelected(null);
                },
              )
            ]
          ],
        ),
      ],
    );
  }
}

class _CalendarCard extends StatelessWidget {
  final List<Task> progress;
  const _CalendarCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final daysInMonth = lastDay.day;
    final firstWeekday = firstDay.weekday % 7; // 0 = Sunday

    final Map<int, Map<String, int>> tasksByDay = {};
    for (var t in progress) {
      if (t.dueDate != null && t.dueDate!.month == now.month && t.dueDate!.year == now.year) {
        final day = t.dueDate!.day;
        if (!tasksByDay.containsKey(day)) {
          tasksByDay[day] = {'total': 0, 'completed': 0, 'overdue': 0};
        }
        tasksByDay[day]!['total'] = tasksByDay[day]!['total']! + 1;
        if (t.status == 'completed') tasksByDay[day]!['completed'] = tasksByDay[day]!['completed']! + 1;
        if (t.isOverdue) tasksByDay[day]!['overdue'] = tasksByDay[day]!['overdue']! + 1;
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              const Row(
                children: [
                  Icon(LucideIcons.calendar, size: 16, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Calendar View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              Text(DateFormat('MMMM yyyy').format(now), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: 7 + firstWeekday + daysInMonth,
            itemBuilder: (context, index) {
              if (index < 7) {
                final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                return Center(child: Text(days[index], style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)));
              }
              final relativeIndex = index - 7 - firstWeekday;
              if (relativeIndex < 0) return const SizedBox.shrink();
              
              final day = relativeIndex + 1;
              final dayData = tasksByDay[day];
              final isToday = day == now.day;
              final bool hasTasks = dayData != null && dayData['total']! > 0;
              final bool hasOverdue = dayData != null && dayData['overdue']! > 0;
              final bool allDone = hasTasks && dayData['completed'] == dayData['total'];

              Color bgColor = isToday 
                ? Theme.of(context).colorScheme.primary.withAlpha(40) 
                : (isDark ? Colors.white.withAlpha(8) : Colors.black.withAlpha(5));
              
              if (!isToday && hasTasks) {
                if (allDone) {
                  bgColor = Colors.green.withAlpha(30);
                } else if (hasOverdue) {
                  bgColor = Colors.red.withAlpha(30);
                } else {
                  bgColor = Colors.amber.withAlpha(30);
                }
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$day', style: TextStyle(fontSize: 11, fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
                    if (dayData != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(min(dayData['total']!, 3), (j) {
                          Color dotColor;
                          if (j < dayData['completed']!) {
                            dotColor = Colors.green;
                          } else if (dayData['overdue']! > 0) {
                            dotColor = Colors.red;
                          } else {
                            dotColor = Colors.amber;
                          }
                          return Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                          );
                        }),
                      )
                    ]
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(Colors.green, 'Completed'),
              SizedBox(width: 12),
              _LegendItem(Colors.amber, 'Active'),
              SizedBox(width: 12),
              _LegendItem(Colors.red, 'Overdue'),
            ],
          )
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem(this.color, this.label);
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }
}
