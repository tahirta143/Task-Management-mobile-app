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
      // 1. Get Geo Location from IP
      final geoRes = await http.get(Uri.parse('https://get.geojs.io/v1/ip/geo.json'));
      if (geoRes.statusCode != 200) return;
      final geoData = json.decode(geoRes.body);
      final lat = geoData['latitude'];
      final lon = geoData['longitude'];

      // 2. Get Weather from Open-Meteo
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

        // Auto-upload to server
        try {
          final auth = context.read<AuthProvider>();
          await auth.updateProfileImage(_imageFile!);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile image updated successfully'), backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
            );
          }
        } finally {
          if (mounted) {
            setState(() {
              _isUploading = false;
            });
          }
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
    final w = MediaQuery.of(context).size.width;
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
                    _buildAnimatedBlock(0, _buildHeader(th)),
                    const SizedBox(height: 24),
                    _buildAnimatedBlock(100, _buildProfileCard(isDark, th, user, isAdmin)),
                    const SizedBox(height: 16),
                    _buildAnimatedBlock(200, _buildMiniStatsGrid(th, isDark, admin, tp, isAdmin)),
                    const SizedBox(height: 16),
                    _buildAnimatedBlock(600, _buildTaskProgressList(th, isDark, tp.tasks)),
                    const SizedBox(height: 16),
                    _buildAnimatedBlock(700, _buildWorkActivityHeatmap(th, isDark, admin.overview?.completionTrend)),
                    const SizedBox(height: 16),
                    _buildAnimatedBlock(800, _buildRecentTasks(th, isDark, tp.tasks)),
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
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(dateStr, style: TextStyle(fontSize: 14, color: th.textTheme.bodySmall?.color)),
            const SizedBox(width: 8),
            const Text('•', style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 8),
            Icon(_weatherIcon, size: 16, color: _weatherColor),
            const SizedBox(width: 4),
            Text(_weatherTemp ?? '--°C', style: TextStyle(fontSize: 14, color: _weatherColor, fontWeight: FontWeight.bold))
          ],
        )
      ],
    );
  }

  Widget _buildProfileCard(bool isDark, ThemeData th, Map<String, dynamic>? user, bool isAdmin) {
    final String? profileUrl = user?['profileImageUrl'];
    final String fullUrl = profileUrl == null ? '' : (profileUrl.startsWith('http') ? profileUrl : '${context.read<SocketService>().baseUrl}${profileUrl.startsWith('/') ? '' : '/'}$profileUrl');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner Area
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  gradient: LinearGradient(
                    colors: isDark 
                      ? [Colors.blueGrey.withAlpha(40), Colors.black26] 
                      : [th.colorScheme.primary.withAlpha(40), th.colorScheme.primary.withAlpha(10)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // DP Avatar
              Positioned(
                bottom: -40,
                left: 24,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1D21) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withAlpha(30), blurRadius: 15, offset: const Offset(0, 8))],
                    ),
                    child: CircleAvatar(
                      radius: 46,
                      backgroundColor: isDark ? Colors.white10 : Colors.black.withAlpha(5),
                      backgroundImage: _imageFile != null 
                        ? FileImage(_imageFile!) as ImageProvider
                        : (profileUrl != null ? NetworkImage(fullUrl) : null),
                      child: (_imageFile == null && profileUrl == null)
                        ? Icon(LucideIcons.user, size: 40, color: Colors.grey.withAlpha(100))
                        : null,
                    ),
                  ),
                ),
              ),
              // Camera Icon Overlay for DP
              Positioned(
                bottom: -40,
                left: 24 + 68,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: th.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: isDark ? const Color(0xFF1A1D21) : Colors.white, width: 2),
                    ),
                    child: const Icon(LucideIcons.camera, size: 12, color: Colors.black),
                  ),
                ),
              ),
              if (_isUploading)
                Positioned(
                  bottom: -40,
                  left: 24,
                  child: IgnorePointer(
                    child: Container(
                      width: 100, // Roughly matching avatar + padding
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CustomLoader(size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 50),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?['username'] ?? 'Current User', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                    const SizedBox(height: 2),
                    Text(isAdmin ? 'Administrator' : 'Team Member', style: TextStyle(fontSize: 13, color: th.textTheme.bodySmall?.color, fontWeight: FontWeight.w500)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: th.colorScheme.primary.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.activity, color: th.colorScheme.primary, size: 20),
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

  Widget _buildWorkActivityHeatmap(ThemeData th, bool isDark, List<CompletionTrendItem>? trend) {
    // We'll show 15 weeks = 105 days
    final Map<String, int> dailyActivity = {};
    if (trend != null) {
      for (var item in trend) {
        final dayStr = item.day.split('T')[0];
        dailyActivity[dayStr] = item.completed;
      }
    }

    final today = DateTime.now();
    // Adjust to end of current week (Saturday)
    final endDate = today.add(Duration(days: 6 - today.weekday)); 
    final startDate = endDate.subtract(const Duration(days: 104)); // 15 weeks total

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
                child: const Text('Last 15 Weeks', style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
              )
            ],
          ),
          const SizedBox(height: 20),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // Show most recent on the right
            child: Row(
              children: List.generate(15, (weekIdx) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Column(
                    children: List.generate(7, (dayIdx) {
                      final dayInTotal = (weekIdx * 7) + dayIdx;
                      final date = startDate.add(Duration(days: dayInTotal));
                      final dateStr = DateFormat('yyyy-MM-dd').format(date);
                      final count = dailyActivity[dateStr] ?? 0;
                      
                      Color color;
                      if (count == 0) color = isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(10);
                      else if (count < 2) color = th.colorScheme.primary.withAlpha(60);
                      else if (count < 4) color = th.colorScheme.primary.withAlpha(140);
                      else if (count < 7) color = th.colorScheme.primary.withAlpha(200);
                      else color = th.colorScheme.primary;

                      return GestureDetector(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${DateFormat('MMM dd').format(date)}: $count tasks completed'),
                              duration: const Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(20),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: th.colorScheme.primary,
                            ),
                          );
                        },
                        child: Container(
                          width: 14,
                          height: 14,
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text('Less', style: TextStyle(fontSize: 9, color: Colors.grey)),
              const SizedBox(width: 4),
              _buildLegendBox(isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(5)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(60)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(140)),
              _buildLegendBox(th.colorScheme.primary.withAlpha(200)),
              _buildLegendBox(th.colorScheme.primary),
              const SizedBox(width: 4),
              const Text('More', style: TextStyle(fontSize: 9, color: Colors.grey)),
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
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
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
