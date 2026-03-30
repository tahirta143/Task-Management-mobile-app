import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../provider/chat_provider.dart';
import '../../provider/task_provider.dart';
import '../../provider/auth_provider.dart';
import '../../models/task_model.dart';

class ChatDetailScreen extends StatefulWidget {
  final int taskId;
  final String taskTitle;
  const ChatDetailScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().fetchMessages(widget.taskId);
    });
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  void _onSend() async {
    if (_msgController.text.trim().isEmpty) return;
    final text = _msgController.text.trim();
    _msgController.clear();
    
    try {
      await context.read<ChatProvider>().sendTextMessage(widget.taskId, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    
    final tp = Provider.of<TaskProvider>(context);
    final cp = Provider.of<ChatProvider>(context);
    
    final task = tp.tasks.firstWhere((t) => t.id == widget.taskId);
    final points = task.points;
    final doneCount = points.where((p) => p.isDone).length;
    final totalCount = points.length;
    final progress = totalCount > 0 ? doneCount / totalCount : 0.0;
    final allDone = doneCount == totalCount && totalCount > 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(widget.taskTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(LucideIcons.moreVertical), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          _buildChecklistPanel(isDark, th, doneCount, totalCount, progress, allDone, points, task),
          Expanded(
            child: cp.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: cp.messages.length,
                  itemBuilder: (ctx, i) {
                    final m = cp.messages[i];
                    final isMe = m.senderId == context.read<AuthProvider>().user?['id'];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildBubble(
                        isDark, th, 
                        m.content ?? '', 
                        m.sender?.username ?? 'User', 
                        DateFormat('HH:mm').format(m.createdAt), 
                        isMe, 
                        0
                      ),
                    );
                  },
                ),
          ),
          _buildInputArea(isDark, th),
        ],
      ),
    );
  }

  Widget _buildChecklistPanel(bool isDark, ThemeData th, int done, int total, double progress, bool allDone, List<TaskPoint> points, Task task) {
    if (points.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(2),
        border: Border(bottom: BorderSide(color: Colors.grey.withAlpha(50))),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withAlpha(50)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
                Text('$done/$total done', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 6,
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(3)),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: allDone ? Colors.green : th.colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...points.map((p) => _buildChecklistItem(p, task.id)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(TaskPoint point, int taskId) {
    final bool isDone = point.isDone;
    return InkWell(
      onTap: () {
        context.read<TaskProvider>().togglePoint(taskId, point.id, !isDone);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
        child: Row(
          children: [
            Container(
              height: 16,
              width: 16,
              decoration: BoxDecoration(
                color: isDone ? Colors.green : Colors.transparent,
                border: Border.all(color: isDone ? Colors.transparent : Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
              child: isDone ? const Center(child: Icon(LucideIcons.check, size: 10, color: Colors.white)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                point.label,
                style: TextStyle(
                  fontSize: 13,
                  decoration: isDone ? TextDecoration.lineThrough : null,
                  color: isDone ? Colors.grey : null,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(String text) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey.withAlpha(50), borderRadius: BorderRadius.circular(12)),
        child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBubble(bool isDark, ThemeData th, String message, String sender, String time, bool isMe, int delay) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (delay * 100)),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(isMe ? 20 * (1 - value) : -20 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? th.colorScheme.primary : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10)),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMe ? 16 : 0),
              bottomRight: Radius.circular(isMe ? 0 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sender, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isMe ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87))),
                  const SizedBox(width: 8),
                  Text(time, style: TextStyle(fontSize: 9, color: isMe ? Colors.black54 : Colors.grey)),
                ],
              ),
              const SizedBox(height: 4),
              Text(message, style: TextStyle(fontSize: 13, color: isMe ? Colors.black : (isDark ? Colors.white : Colors.black))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, ThemeData th) {
    return Container(
      padding: const EdgeInsets.all(16.0).copyWith(bottom: 32.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff121212) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.withAlpha(50))),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(LucideIcons.paperclip, size: 20), onPressed: () {}, color: Colors.grey),
          Expanded(
            child: TextField(
              controller: _msgController,
              onSubmitted: (_) => _onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                filled: true,
                fillColor: isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: th.colorScheme.primary,
            child: IconButton(icon: const Icon(LucideIcons.send, size: 16, color: Colors.black), onPressed: _onSend),
          )
        ],
      ),
    );
  }
}
