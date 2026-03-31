import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../provider/task_provider.dart';

import '../../widgets/custom_loader.dart';
import 'chat_detail_screen.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final tp = Provider.of<TaskProvider>(context);
    final tasks = tp.tasks;

    return RefreshIndicator(
      onRefresh: () => tp.fetchTasks(),
      child: tp.isLoading
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
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                              offset: Offset(0, 10 * (1 - value)),
                              child: child),
                        );
                      },
                      child: const Text('Collaboration',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey)),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 400),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                              offset: Offset(0, 10 * (1 - value)),
                              child: child),
                        );
                      },
                      child: const Text('Task Chat',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5)),
                    ),
                    const SizedBox(height: 24),
                    _buildChatLayout(context, isDark, th, tp, tasks),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildChatLayout(BuildContext context, bool isDark, ThemeData th,
      TaskProvider tp, List tasks) {
    return Container(
      constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isDark
                ? Colors.white.withAlpha(25)
                : Colors.black.withAlpha(13)),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 4))
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tasks',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(tasks.length.toString(),
                    style: TextStyle(
                        fontSize: 12,
                        color: th.colorScheme.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (tp.isLoading)
            const Padding(
              padding: EdgeInsets.all(64.0),
              child: CustomLoader(),
            )
          else if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(64.0),
              child: Center(
                child: Text('No active tasks to chat in.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final t = tasks[index];
                return _buildChatTile(
                  context,
                  th,
                  isDark,
                  taskId: t.id,
                  title: t.title,
                  subtitle:
                      '${t.status.replaceAll('_', ' ')} • ${t.priority.toUpperCase()}',
                  lastMessage: 'Tap to open chat room',
                  time: '',
                  unread: 0,
                  isSelected: false,
                  delay: index * 50,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(BuildContext context, ThemeData th, bool isDark, {required int taskId, required String title, required String subtitle, required String lastMessage, required String time, required int unread, required bool isSelected, required int delay}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + delay),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 10 * (1 - value)), child: child),
        );
      },
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChatDetailScreen(taskId: taskId, taskTitle: title)));
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? th.colorScheme.primary.withAlpha(25) : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? th.colorScheme.primary.withAlpha(76) : Colors.transparent),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  if (unread > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: th.colorScheme.primary, shape: BoxShape.circle),
                      child: Text(unread.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black)),
                    )
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              const SizedBox(height: 12),
              Text(lastMessage, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
