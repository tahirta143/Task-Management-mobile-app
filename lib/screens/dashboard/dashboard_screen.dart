import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/report_models.dart';
import '../../provider/auth_provider.dart';
import '../../provider/admin_provider.dart';
import '../../provider/task_provider.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToBoard;

  const DashboardScreen({super.key, required this.onNavigateToBoard});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final auth = Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);
    final tp = Provider.of<TaskProvider>(context);

    final user = auth.user;
    final isAdmin = user?['role'] == 'admin';

    // If loading reports (for admin) or tasks (for all)
    final isLoading = (isAdmin && admin.isLoading) || tp.isLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnimatedBlock(0, _buildHeader(th)),
          const SizedBox(height: 24),
          _buildAnimatedBlock(100, _buildProfileCard(isDark, th, user, isAdmin)),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()))
          else ...[
            _buildAnimatedBlock(200, _buildMiniStatsGrid(th, isDark, admin, tp, isAdmin)),
            const SizedBox(height: 16),
            _buildAnimatedBlock(600, _buildTaskProgressList(th, isDark, tp.tasks)),
            const SizedBox(height: 16),
            _buildAnimatedBlock(700, _buildMockHeatmap(th, isDark, admin.overview?.completionTrend)), 
            const SizedBox(height: 16),
            _buildAnimatedBlock(800, _buildRecentTasks(th, isDark, tp.tasks)),
          ],
          const SizedBox(height: 32),
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

  Widget _buildHeader(ThemeData th) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview Dashboard',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text('Monday, Mar 30', style: TextStyle(fontSize: 14, color: th.textTheme.bodySmall?.color)),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            const Icon(Icons.wb_sunny, size: 16, color: Colors.amber),
            const SizedBox(width: 4),
            const Text('24°C', style: TextStyle(fontSize: 14, color: Colors.amber, fontWeight: FontWeight.bold))
          ],
        )
      ],
    );
  }

  Widget _buildProfileCard(bool isDark, ThemeData th, Map<String, dynamic>? user, bool isAdmin) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: Stack(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.white,
                      image: _imageFile != null
                          ? DecorationImage(
                              image: FileImage(_imageFile!),
                              fit: BoxFit.cover,
                              colorFilter: ColorFilter.mode(
                                Colors.white.withOpacity(0.9),
                                BlendMode.multiply,
                              ),
                            )
                          : (user?['profileImageUrl'] != null
                              ? DecorationImage(
                                  image: NetworkImage(user!['profileImageUrl']),
                                  fit: BoxFit.cover,
                                )
                              : null),
                    ),
                    child: (_imageFile == null && user?['profileImageUrl'] == null)
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.white : Colors.black).withAlpha(20),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Icon(LucideIcons.camera, size: 24, color: Colors.grey.withAlpha(128)),
                                const SizedBox(height: 4),
                                const Text('Tap to set banner', style: TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        : null,
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withAlpha(10),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_imageFile != null || user?['profileImageUrl'] != null)
                    Positioned(
                      right: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.black.withAlpha(100), shape: BoxShape.circle),
                        child: const Icon(LucideIcons.camera, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['username'] ?? 'Current User', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    Text(isAdmin ? 'Administrator' : 'Team Member', style: TextStyle(fontSize: 12, color: th.textTheme.bodySmall?.color, fontWeight: FontWeight.w500)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: th.colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.activity, color: th.colorScheme.primary, size: 18),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMiniStatsGrid(ThemeData th, bool isDark, AdminProvider admin, TaskProvider tp, bool isAdmin) {
    if (isAdmin && admin.overview != null) {
      final ov = admin.overview!;
      return Row(
        children: [
          Expanded(child: _buildStatCard(th, isDark, ov.totalTasks.toString(), 'Total Tasks')),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard(th, isDark, ov.totalInProgress.toString(), 'In Progress')),
          const SizedBox(width: 8),
          Expanded(child: _buildStatCard(th, isDark, ov.totalCompleted.toString(), 'Completed')),
        ],
      );
    }

    // Default stats for non-admin or if data failed
    final total = tp.tasks.length;
    final completed = tp.tasks.where((t) => t.status == 'completed').length;
    final active = tp.tasks.where((t) => t.status == 'in_progress').length;

    return Row(
      children: [
        Expanded(child: _buildStatCard(th, isDark, total.toString(), 'Your Tasks')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(th, isDark, completed.toString(), 'Completed')),
        const SizedBox(width: 8),
        Expanded(child: _buildStatCard(th, isDark, active.toString(), 'Active')),
      ],
    );
  }

  Widget _buildStatCard(ThemeData th, bool isDark, String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(5)),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Text(val, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildActiveSession(ThemeData th, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: isDark ? Colors.white.withAlpha(30) : Colors.transparent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Active Session', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(LucideIcons.moreHorizontal, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: widget.onNavigateToBoard,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFCCEFED),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Task title here', style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('02:45:12', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                          child: const Icon(LucideIcons.play, color: Colors.white, size: 20),
                        )
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              const Column(
                children: [
                  Icon(LucideIcons.layers, size: 20, color: Colors.grey),
                  SizedBox(height: 12),
                  Icon(LucideIcons.settings, size: 20, color: Colors.grey),
                ],
              )
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWeeklySchedule(ThemeData th, bool isDark) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Weekly Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(LucideIcons.calendarDays, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: days.map((d) => _buildDayItem(d, d == 'Mon')).toList(),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: th.colorScheme.primary.withAlpha(40),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: th.colorScheme.primary.withAlpha(50)),
            ),
            child: InkWell(
              onTap: widget.onNavigateToBoard,
              child: Row(
                children: [
                  const Icon(LucideIcons.briefcase, size: 18),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Homepage Redesign • Alex Developer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('In Progress • HIGH', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  ),
                  Text('12:00', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: th.colorScheme.primary)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildDayItem(String label, bool isToday) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 8),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isToday ? Colors.black : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              '30', // Mock date
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isToday ? Colors.white : Colors.grey,
              ),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildTaskProgressList(ThemeData th, bool isDark, List<dynamic> tasks) {
    final displayTasks = tasks.take(3).toList();
    if (displayTasks.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Task Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Icon(LucideIcons.trendingUp, color: Colors.grey, size: 18),
            ],
          ),
          const SizedBox(height: 24),
          ...displayTasks.map((t) {
            // Calculate a simple progression (mock logic since DB might not have many steps)
            final pct = t.status == 'completed' ? 100 : (t.status == 'in_progress' ? 50 : 0);
            return InkWell(
              onTap: widget.onNavigateToBoard,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${t.title}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        Text('$pct%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: pct / 100,
                        child: Container(
                          decoration: BoxDecoration(
                            color: t.status == 'completed' ? Colors.green : th.colorScheme.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildMockHeatmap(ThemeData th, bool isDark, List<CompletionTrendItem>? trend) {
    // Generate last 49 days of intensity
    final Map<String, int> dailyActivity = {};
    if (trend != null) {
      for (var item in trend) {
        // day is usually YYYY-MM-DD
        final dayStr = item.day.split('T')[0];
        dailyActivity[dayStr] = item.completed;
      }
    }

    final List<int> intensities = List.generate(49, (index) {
      final date = DateTime.now().subtract(Duration(days: 48 - index));
      final dateStr = date.toIso8601String().split('T')[0];
      final count = dailyActivity[dateStr] ?? 0;
      if (count == 0) return 0;
      if (count < 3) return 1;
      if (count < 6) return 2;
      return 3;
    });

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Work Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(12)),
                child: const Text('Last 49 Days', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
              )
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: 49,
            itemBuilder: (context, index) {
              int intensity = intensities[index];
              Color color;
              if (intensity == 0) color = isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10);
              else if (intensity == 1) color = th.colorScheme.primary.withAlpha(60);
              else if (intensity == 2) color = th.colorScheme.primary.withAlpha(160);
              else color = th.colorScheme.primary;

              return Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)));
            },
          )
        ],
      ),
    );
  }

  Widget _buildRecentTasks(ThemeData th, bool isDark, List<dynamic> tasks) {
    final recent = tasks.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(10)),
                child: Text(recent.length.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          ...recent.expand((t) => [
            _buildTaskItem(t.title, '', t.status, t.id.toString()),
            _buildDivider(),
          ]).toList()..removeLast(),
        ],
      ),
    );
  }

  Widget _buildTaskItem(String title, String devName, String status, String id) {
    return InkWell(
      onTap: widget.onNavigateToBoard,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(
                status == 'completed' ? LucideIcons.checkCircle2 : LucideIcons.clock,
                size: 16,
                color: status == 'completed' ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title • $devName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(status.toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
            ),
            Text('#$id', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Divider(color: Colors.grey.withAlpha(30)),
  );
}

class _StatusIndicator extends StatelessWidget {
  final Color color;
  final String label;
  const _StatusIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
