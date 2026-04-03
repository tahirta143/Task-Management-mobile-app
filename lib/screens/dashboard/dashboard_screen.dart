import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../models/report_models.dart';
import '../../provider/auth_provider.dart';
import '../../provider/admin_provider.dart';
import '../../provider/task_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/custom_loader.dart';
import '../../models/task_model.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback onNavigateToBoard;

  const DashboardScreen({super.key, required this.onNavigateToBoard});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

  String? _weatherTemp;
  IconData _weatherIcon = LucideIcons.sun;
  Color _weatherColor = Colors.amber;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    try {
      final geoRes = await http.get(Uri.parse('https://get.geojs.io/v1/ip/geo.json'));
      if (geoRes.statusCode != 200) return;
      final geoData = json.decode(geoRes.body);
      final lat = geoData['latitude'];
      final lon = geoData['longitude'];

      final weatherRes = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current_weather=true'));
      if (weatherRes.statusCode != 200) return;
      final weatherData = json.decode(weatherRes.body);

      if (mounted && weatherData['current_weather'] != null) {
        final double temp = weatherData['current_weather']['temperature'];
        final int code = weatherData['current_weather']['weathercode'];

        IconData icon = LucideIcons.sun;
        Color color = Colors.amber;

        if (code >= 1 && code <= 3) {
          icon = LucideIcons.cloud;
          color = Colors.blueGrey;
        } else if (code >= 45 && code <= 48) {
          icon = LucideIcons.wind;
          color = Colors.blueGrey;
        } else if (code >= 51 && code <= 67) {
          icon = LucideIcons.cloudRain;
          color = Colors.blue;
        } else if (code >= 71 && code <= 77) {
          icon = LucideIcons.snowflake;
          color = Colors.cyan;
        } else if (code >= 80 && code <= 82) {
          icon = LucideIcons.cloudDrizzle;
          color = Colors.lightBlue;
        } else if (code >= 95 && code <= 99) {
          icon = LucideIcons.cloudLightning;
          color = Colors.deepPurple;
        }

        setState(() {
          _weatherTemp = '${temp.round()}°C';
          _weatherIcon = icon;
          _weatherColor = color;
        });
      }
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

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
          _isUploading = true;
        });

        try {
          final auth = context.read<AuthProvider>();
          await auth.updateProfileImage(_imageFile!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Profile image updated successfully'),
                  backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Upload failed: $e'),
                  backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) setState(() => _isUploading = false);
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final auth = Provider.of<AuthProvider>(context);
    final admin = Provider.of<AdminProvider>(context);
    final tp = Provider.of<TaskProvider>(context);

    final user = auth.user;
    final isAdmin = user?['role'] == 'admin';
    final isLoading = (isAdmin && admin.isLoading) || tp.isLoading;

    return Container(
      color: Colors.transparent,
      child: RefreshIndicator(
        onRefresh: () async {
          await tp.fetchTasks();
          if (isAdmin) await admin.fetchDashboardReport();
        },
        child: isLoading
            ? LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints:
                BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(child: CustomLoader()),
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
              _buildAnimatedBlock(0, _buildHeader(th)),
              const SizedBox(height: 24),
              _buildAnimatedBlock(
                  100, _buildProfileCard(isDark, th, user, isAdmin)),
              const SizedBox(height: 16),
              _buildAnimatedBlock(200,
                  _buildMiniStatsGrid(th, isDark, admin, tp, isAdmin)),
              const SizedBox(height: 16),
              _buildAnimatedBlock(
                  600, _buildTaskProgressList(th, isDark, tp.tasks)),
              const SizedBox(height: 16),
              _buildAnimatedBlock(
                  700, _buildWorkActivityHeatmap(th, isDark, tp.tasks)),
              const SizedBox(height: 16),
              _buildAnimatedBlock(
                  800, _buildRecentTasks(th, isDark, tp.tasks)),
              const SizedBox(height: 32),
            ],
          ),
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

  Widget _buildHeader(ThemeData th) {
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, MMM dd').format(now);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Overview Dashboard',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(dateStr,
                style: TextStyle(
                    fontSize: 14, color: th.textTheme.bodySmall?.color)),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            Icon(_weatherIcon, size: 16, color: _weatherColor),
            const SizedBox(width: 4),
            Text(_weatherTemp ?? '--°C',
                style: TextStyle(
                    fontSize: 14,
                    color: _weatherColor,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE CARD — full-bleed image at top, name + role badges at bottom
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildProfileCard(
      bool isDark, ThemeData th, Map<String, dynamic>? user, bool isAdmin) {
    final String? profileUrl = user?['profileImageUrl'];
    final String fullUrl = profileUrl == null
        ? ''
        : (profileUrl.startsWith('http')
        ? profileUrl
        : '${context.read<SocketService>().baseUrl}${profileUrl.startsWith('/') ? '' : '/'}$profileUrl');

    final ImageProvider? imageProvider = _imageFile != null
        ? FileImage(_imageFile!) as ImageProvider
        : (profileUrl != null ? NetworkImage(fullUrl) : null);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Full-bleed image area ──────────────────────────────────────
          GestureDetector(
            onTap: _pickImage,
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image or placeholder
                  imageProvider != null
                      ? Image(
                    image: imageProvider,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    color: isDark
                        ? Colors.white.withAlpha(18)
                        : th.colorScheme.primary.withAlpha(20),
                    child: Center(
                      child: Icon(
                        LucideIcons.user,
                        size: 64,
                        color: th.colorScheme.primary.withAlpha(80),
                      ),
                    ),
                  ),

                  // Upload spinner overlay
                  if (_isUploading)
                    Container(
                      color: Colors.black.withAlpha(80),
                      child: const Center(
                          child: CustomLoader(size: 28, color: Colors.white)),
                    ),

                  // Camera button — bottom-right corner
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withAlpha(160)
                            : Colors.white.withAlpha(220),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: isDark
                                ? Colors.white.withAlpha(40)
                                : Colors.black.withAlpha(15)),
                      ),
                      child: Icon(
                        LucideIcons.camera,
                        size: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Name + badges + activity icon ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?['username'] ?? 'Current User',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: th.colorScheme.primary.withAlpha(30),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isAdmin ? 'Administrator' : 'Member',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: th.colorScheme.primary,
                              ),
                            ),
                          ),
                          // Team badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withAlpha(18)
                                  : Colors.black.withAlpha(8),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Team Member',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Activity icon button
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: th.colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.activity,
                      color: th.colorScheme.primary, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatsGrid(ThemeData th, bool isDark, AdminProvider admin,
      TaskProvider tp, bool isAdmin) {
    if (isAdmin && admin.overview != null) {
      final ov = admin.overview!;
      return Row(
        children: [
          Expanded(
              child: _buildStatCard(
                  th, isDark, ov.totalTasks.toString(), 'Total Tasks')),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatCard(
                  th, isDark, ov.totalInProgress.toString(), 'In Progress')),
          const SizedBox(width: 8),
          Expanded(
              child: _buildStatCard(
                  th, isDark, ov.totalCompleted.toString(), 'Completed')),
        ],
      );
    }

    final total = tp.tasks.length;
    final completed =
        tp.tasks.where((t) => t.status.toLowerCase() == 'completed').length;
    final active =
        tp.tasks.where((t) => t.status.toLowerCase() == 'in_progress').length;

    return Row(
      children: [
        Expanded(
            child:
            _buildStatCard(th, isDark, total.toString(), 'Your Tasks')),
        const SizedBox(width: 8),
        Expanded(
            child: _buildStatCard(
                th, isDark, completed.toString(), 'Completed')),
        const SizedBox(width: 8),
        Expanded(
            child:
            _buildStatCard(th, isDark, active.toString(), 'Active')),
      ],
    );
  }

  Widget _buildStatCard(
      ThemeData th, bool isDark, String val, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(25)
                : Colors.black.withAlpha(5)),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Text(val,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold)),
          Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildTaskProgressList(
      ThemeData th, bool isDark, List<Task> tasks) {
    if (tasks.isEmpty) return const SizedBox.shrink();

    final sortedTasks = List<Task>.from(tasks)
      ..sort((a, b) {
        if (a.status == 'completed' && b.status != 'completed') return 1;
        if (b.status == 'completed' && a.status != 'completed') return -1;
        return b.progressPercent.compareTo(a.progressPercent);
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
              const Text('Task Progress',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('${tasks.length} tasks',
                  style:
                  const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: sortedTasks.length,
              separatorBuilder: (context, index) =>
              const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final t = sortedTasks[index];
                final pct = t.progressPercent;

                Color barColor = th.colorScheme.primary;
                if (t.status == 'completed') {
                  barColor = Colors.green;
                } else if (t.isOverdue) {
                  barColor = Colors.red;
                } else if (pct >= 80) {
                  barColor = Colors.amber;
                }

                Color priorityColor = Colors.blue;
                if (t.priority == 'urgent') {
                  priorityColor = Colors.red;
                } else if (t.priority == 'high') {
                  priorityColor = Colors.amber;
                } else if (t.priority == 'low') {
                  priorityColor = Colors.green;
                }

                return InkWell(
                  onTap: widget.onNavigateToBoard,
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    t.title,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      decoration: t.status == 'completed'
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: t.status == 'completed'
                                          ? Colors.grey
                                          : null,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: priorityColor.withAlpha(40),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                        color: priorityColor.withAlpha(80)),
                                  ),
                                  child: Text(
                                    t.priority.toUpperCase(),
                                    style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        color: priorityColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text('${t.progressPercent}%',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withAlpha(20)
                              : Colors.black.withAlpha(10),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: pct / 100,
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${t.points.where((p) => p.isDone).length} of ${t.points.length} points',
                            style: const TextStyle(
                                fontSize: 9, color: Colors.grey),
                          ),
                          Text(
                            t.status == 'completed'
                                ? 'Done'
                                : (t.isOverdue ? 'Overdue' : 'In progress'),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: t.status == 'completed'
                                  ? Colors.green
                                  : (t.isOverdue ? Colors.red : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkActivityHeatmap(
      ThemeData th, bool isDark, List<Task> tasks) {
    final Map<String, int> dailyActivity = {};
    for (var task in tasks) {
      final date = task.startDate ?? task.updatedAt;
      final dayStr = DateFormat('yyyy-MM-dd').format(date);
      dailyActivity[dayStr] = (dailyActivity[dayStr] ?? 0) + 1;
    }

    final today = DateTime.now();
    final todayTruncated = DateTime(today.year, today.month, today.day);
    final startDate = todayTruncated.subtract(const Duration(days: 48));

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark
            ? null
            : [
          BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 20,
              offset: const Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Work Activity',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(12)),
                child: const Text('Last 7 Weeks',
                    style: TextStyle(
                        fontSize: 10, fontFamily: 'monospace')),
              )
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, constraints) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(7, (weekIdx) {
                return Column(
                  children: List.generate(7, (dayIdx) {
                    final dayInTotal = (weekIdx * 7) + dayIdx;
                    final date =
                    startDate.add(Duration(days: dayInTotal));
                    final dateStr =
                    DateFormat('yyyy-MM-dd').format(date);
                    final count = dailyActivity[dateStr] ?? 0;

                    Color color;
                    if (count == 0)
                      color = isDark
                          ? Colors.white.withAlpha(15)
                          : Colors.black.withAlpha(5);
                    else if (count < 3)
                      color = th.colorScheme.primary.withAlpha(60);
                    else if (count < 6)
                      color = th.colorScheme.primary.withAlpha(140);
                    else if (count < 10)
                      color = th.colorScheme.primary.withAlpha(200);
                    else
                      color = th.colorScheme.primary;

                    return GestureDetector(
                      onTap: () {
                        final label = count > 0
                            ? '$count task${count > 1 ? 's' : ''}'
                            : 'No activity';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '$label on ${DateFormat('MMM dd').format(date)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black)),
                            backgroundColor: th.colorScheme.primary,
                            duration: const Duration(seconds: 1),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.all(20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      },
                      child: Container(
                        width: (constraints.maxWidth - 40) / 7,
                        height: (constraints.maxWidth - 40) / 7,
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  }),
                );
              }),
            );
          }),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less',
                  style: TextStyle(fontSize: 9, color: Colors.grey)),
              const SizedBox(width: 4),
              _buildLegendBox(isDark
                  ? Colors.white.withAlpha(15)
                  : Colors.black.withAlpha(5)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(60)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(140)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(200)),
              _buildLegendBox(th.colorScheme.primary),
              const SizedBox(width: 4),
              const Text('More',
                  style: TextStyle(fontSize: 9, color: Colors.grey)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildLegendBox(Color color) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
          color: color, borderRadius: BorderRadius.circular(2)),
    );
  }

  Widget _buildRecentTasks(
      ThemeData th, bool isDark, List<Task> tasks) {
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
              const Text('Recent Tasks',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : Colors.black12,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(recent.length.toString(),
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
              )
            ],
          ),
          const SizedBox(height: 20),
          ...recent
              .expand((t) => [
            _buildTaskItem(
                t.title, '', t.status, t.id.toString()),
            _buildDivider(),
          ])
              .toList()
            ..removeLast(),
        ],
      ),
    );
  }

  Widget _buildTaskItem(
      String title, String devName, String status, String id) {
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
                status == 'completed'
                    ? LucideIcons.checkCircle2
                    : LucideIcons.clock,
                size: 16,
                color:
                status == 'completed' ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$title • $devName',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(
                      status
                          .toUpperCase()
                          .replaceAll('_', ' '),
                      style: const TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
            Text('#$id',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.bold)),
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