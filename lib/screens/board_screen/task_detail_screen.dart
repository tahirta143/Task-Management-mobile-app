import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/task_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../provider/task_provider.dart';
import '../../provider/auth_provider.dart';
import '../../services/socket_service.dart';
import '../../widgets/custom_loader.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoadingMessages = true;
  final Map<int, bool> _typingUsers = {};
  Message? _replyingTo;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _initSocket();
  }

  void _initSocket() async {
    final ss = SocketService();
    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;

    await ss.connect();
    if (!mounted) return;
    
    ss.joinTask(widget.task.id);

    ss.socket.on('message:new', (data) {
      if (data['taskId'] == widget.task.id) {
        final newMsg = Message.fromJson(data);
        if (mounted && !_messages.any((m) => m.id == newMsg.id)) {
          setState(() => _messages.add(newMsg));
          _scrollToBottom();
        }
      }
    });

    ss.socket.on('typing', (data) {
      if (data['taskId'] == widget.task.id) {
        final userId = data['userId'];
        if (userId != me?['id']) {
          setState(() => _typingUsers[userId] = data['isTyping']);
        }
      }
    });
  }

  void _loadMessages() async {
    try {
      final msgs = await context.read<TaskProvider>().fetchTaskMessages(widget.task.id);
      if (mounted) {
        setState(() {
          _messages.addAll(msgs);
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMessages = false);
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;
    if (me == null) return;

    // Optimistic Update
    final optimistic = Message(
      id: 'tmp-${DateTime.now().millisecondsSinceEpoch}',
      taskId: widget.task.id,
      type: 'text',
      content: text,
      senderId: me['id'],
      sender: User.fromJson(me),
      replyInfo: _replyingTo != null ? {
        'content': _replyingTo!.content ?? (_replyingTo!.type == 'image' ? 'Image attachment' : ''),
        'username': _replyingTo!.sender?.username,
        'type': _replyingTo!.type,
      } : null,
      createdAt: DateTime.now(),
    );

    setState(() {
      if (!_messages.any((m) => m.id == optimistic.id)) {
        _messages.add(optimistic);
      }
      _scrollToBottom();
    });

    final replyToId = _replyingTo?.id != null ? int.tryParse(_replyingTo!.id) : null;
    
    final ss = SocketService();
    ss.sendMessage(widget.task.id, text, replyToId: replyToId, onAck: (ack) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == optimistic.id);
        });
      }
    });
    
    _messageController.clear();
    setState(() => _replyingTo = null);
    ss.stopTyping(widget.task.id);
  }

  void _sendImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;
    if (me == null) return;

    // Optimistic Update with local file path
    final optimistic = Message(
      id: 'tmp-img-${DateTime.now().millisecondsSinceEpoch}',
      taskId: widget.task.id,
      type: 'image',
      imageUrl: image.path, // Use local path for immediate display
      senderId: me['id'],
      sender: User.fromJson(me),
      replyInfo: _replyingTo != null ? {
        'content': _replyingTo!.content ?? (_replyingTo!.type == 'image' ? 'Image attachment' : ''),
        'username': _replyingTo!.sender?.username,
        'type': _replyingTo!.type,
      } : null,
      createdAt: DateTime.now(),
    );

    setState(() {
      _messages.add(optimistic);
      _scrollToBottom();
    });

    final replyToId = _replyingTo?.id != null ? int.tryParse(_replyingTo!.id) : null;
    final tp = context.read<TaskProvider>();
    
    try {
      final msg = await tp.uploadTaskImage(widget.task.id, File(image.path));
      final ss = SocketService();
      ss.sendImage(widget.task.id, msg.imageUrl!, replyToId: replyToId, onAck: (ack) {
        if (mounted) {
          setState(() {
            _replyingTo = null;
            _messages.removeWhere((m) => m.id == optimistic.id);
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m.id == optimistic.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to upload image: $e')));
      }
    }
  }


  @override
  void dispose() {
    final ss = SocketService();
    ss.leaveTask(widget.task.id);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final me = context.watch<AuthProvider>().user;
    final isAdmin = me?['role'] == 'admin';
    final canChat = widget.task.status != 'pending' || isAdmin;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('#${widget.task.id} • ${widget.task.status.replaceAll('_', ' ').toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.moreVertical, size: 20)),
        ],
      ),
      body: Column(
        children: [
          // Checklist / Points
          Consumer<TaskProvider>(
            builder: (context, tp, child) {
              final currentTask = tp.tasks.firstWhere((t) => t.id == widget.task.id, orElse: () => widget.task);
              if (currentTask.points.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Checklist', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                        Text('${currentTask.points.where((p) => p.isDone).length}/${currentTask.points.length} done', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: currentTask.points.isEmpty ? 0 : currentTask.points.where((p) => p.isDone).length / currentTask.points.length,
                        minHeight: 6,
                        backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...currentTask.points.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: InkWell(
                        onTap: () async {
                          await tp.togglePoint(currentTask.id, p.id, !p.isDone);
                          // tp.fetchTasks() would ideally trigger notification, but adding local setState if needed
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Row(
                            children: [
                              Icon(p.isDone ? LucideIcons.checkCircle : LucideIcons.circle, size: 18, color: p.isDone ? Colors.green : Colors.grey),
                              const SizedBox(width: 12),
                              Expanded(child: Text(p.label, style: TextStyle(fontSize: 13, decoration: p.isDone ? TextDecoration.lineThrough : null, color: p.isDone ? Colors.grey : null))),
                            ],
                          ),
                        ),
                      ),
                    )).toList(),
                  ],
                ),
              );
            },
          ),

          // Messages
          Expanded(
            child: _isLoadingMessages 
              ? const CustomLoader()
              : RefreshIndicator(
                  onRefresh: () async {
                    final tp = context.read<TaskProvider>();
                    _messages.clear();
                    await tp.fetchTasks();
                    _loadMessages();
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMine = msg.senderId == me?['id'];
                      return _buildMessageBubble(msg, isMine);
                    },
                  ),
                ),
          ),

          if (_typingUsers.values.any((e) => e))
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const CustomLoader(size: 12),
                  const SizedBox(width: 8),
                  Text('Someone is typing...', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                ],
              ),
            ),

          // Input
          if (canChat) 
            _buildInput(th, isDark)
          else
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5),
              child: Column(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 8),
                  Text('Chat is disabled until the task is in progress.', style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, bool isMine) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(msg.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            _buildAvatar(msg.sender),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(msg.sender?.username ?? 'User',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                GestureDetector(
                  onLongPress: () => setState(() => _replyingTo = msg),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isMine
                          ? th.colorScheme.primary.withAlpha(isDark ? 40 : 20)
                          : (isDark ? Colors.white.withAlpha(10) : Colors.grey[100]),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(24),
                        topRight: const Radius.circular(24),
                        bottomLeft: Radius.circular(isMine ? 24 : 4),
                        bottomRight: Radius.circular(isMine ? 4 : 24),
                      ),
                      border: Border.all(
                        color: isMine 
                            ? th.colorScheme.primary.withAlpha(50) 
                            : (isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (msg.replyInfo != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha(10),
                              borderRadius: BorderRadius.circular(12),
                              border: const Border(left: BorderSide(color: Colors.grey, width: 3)),
                            ),
                            child: Text(
                              msg.replyInfo!['content'] ?? (msg.replyInfo!['type'] == 'image' ? 'Image' : ''),
                              style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        if (msg.type == 'image' && msg.imageUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: msg.imageUrl!.startsWith('http')
                                  ? Image.network(msg.imageUrl!, fit: BoxFit.cover)
                                  : (msg.id.startsWith('tmp')
                                      ? Image.file(File(msg.imageUrl!), fit: BoxFit.cover)
                                      : Image.network('${SocketService().baseUrl}${msg.imageUrl}', fit: BoxFit.cover)),
                            ),
                          ),
                        if (msg.content != null)
                          Text(msg.content!, style: const TextStyle(fontSize: 14, height: 1.4)),
                        const SizedBox(height: 6),
                        Text(dateStr, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isMine) ...[
            const SizedBox(width: 8),
            _buildAvatar(msg.sender),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar(User? sender) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.withAlpha(50)),
        color: Colors.grey.withAlpha(30),
      ),
      clipBehavior: Clip.antiAlias,
      child: sender?.profileImageUrl != null
          ? Image.network(sender!.profileImageUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                (sender?.username ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
    );
  }

  Widget _buildInput(ThemeData th, bool isDark) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: th.scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5))),
      ),
      child: Column(
        children: [
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_replyingTo!.content ?? 'Image attachment', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() => _replyingTo = null), icon: const Icon(LucideIcons.x, size: 16)),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(onPressed: _sendImage, icon: const Icon(LucideIcons.plus, color: Colors.grey)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (val) {
                    final ss = SocketService();
                    if (val.isNotEmpty) ss.startTyping(widget.task.id);
                    else ss.stopTyping(widget.task.id);
                  },
                  decoration: InputDecoration(
                    hintText: 'Message...',
                    filled: true,
                    fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sendMessage, 
                icon: Icon(LucideIcons.send, color: th.colorScheme.primary),
                style: IconButton.styleFrom(
                  backgroundColor: th.colorScheme.primary.withAlpha(30),
                  padding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
