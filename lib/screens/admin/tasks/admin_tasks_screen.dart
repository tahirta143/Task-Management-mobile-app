import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../../provider/task_provider.dart';
import '../../../models/task_model.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  String _selectedTab = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final tp = Provider.of<TaskProvider>(context);

    final filtered = _selectedTab == 'All' 
        ? tp.tasks 
        : tp.tasks.where((t) {
            final String statusStr = t.status.toLowerCase().replaceAll('_', ' ');
            final String tabStr = _selectedTab.toLowerCase();
            return statusStr == tabStr;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Tasks', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAnimatedBlock(0, const Text('Admin', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
            const SizedBox(height: 4),
            _buildAnimatedBlock(100, Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tasks', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                Text('${filtered.length} items', style: TextStyle(fontSize: 12, color: th.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            )),
            const SizedBox(height: 16),
            
            _buildAnimatedBlock(200, TextField(
              decoration: InputDecoration(
                hintText: 'Search tasks...',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            )),
            const SizedBox(height: 16),

            _buildAnimatedBlock(300, SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab('All', isDark, th),
                  const SizedBox(width: 8),
                  _buildTab('Pending', isDark, th),
                  const SizedBox(width: 8),
                  _buildTab('In Progress', isDark, th),
                  const SizedBox(width: 8),
                  _buildTab('Hold', isDark, th),
                  const SizedBox(width: 8),
                  _buildTab('Completed', isDark, th),
                ],
              ),
            )),
            const SizedBox(height: 24),

            _buildTasksList(filtered, isDark, th),
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

  Widget _buildTab(String label, bool isDark, ThemeData th) {
    final isActive = _selectedTab == label;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = label;
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? th.colorScheme.primary : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildTasksList(List<Task> items, bool isDark, ThemeData th) {
    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No tasks found.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return _buildAnimatedBlock(400, Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
        boxShadow: isDark
            ? null
            : [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final int idx = e.key;
          final t = e.value;
          final bool isLast = items.last == t;
          return _buildAnimatedBlock(idx * 100, InkWell(
            onTap: () {
              _showTaskEditSheet(context, t, isDark, th);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: isLast ? Colors.transparent : Colors.grey.withAlpha(50))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${t.status.toUpperCase()} • ${t.priority.toUpperCase()} • ${t.points.length} points',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('#${t.id}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace')),
                ],
              ),
            ),
          ));
        }).toList(),
      ),
    ));
  }

  void _showTaskEditSheet(BuildContext context, Task t, bool isDark, ThemeData th) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final double width = MediaQuery.of(context).size.width;
        final double modalWidth = min(width * 0.95, 540);

        return Center(
          child: Container(
            width: modalWidth,
            height: MediaQuery.of(context).size.height * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: th.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Edit Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      _buildLabel('Title'),
                      TextField(decoration: InputDecoration(hintText: t.title, border: const OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildLabel('Status'),
                      TextField(decoration: InputDecoration(hintText: t.status, border: const OutlineInputBorder())),
                      const SizedBox(height: 16),
                      _buildLabel('Priority'),
                      TextField(decoration: InputDecoration(hintText: t.priority, border: const OutlineInputBorder())),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: th.colorScheme.primary,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16)
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}
