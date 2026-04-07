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

class ChatDetailScreen extends StatefulWidget {
  final int taskId;
  final String taskTitle;
  const ChatDetailScreen({super.key, required this.taskId, required this.taskTitle});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Message> _messages = [];
  bool _isLoadingMessages = true;
  final Map<int, bool> _typingUsers = {};
  Message? _replyingTo;
  Message? _editingMessage;
  File? _pendingImage;
  bool _isUploading = false;


  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMessages();
      _initSocket();
    });
  }

  void _initSocket() async {
    final ss = SocketService();
    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;

    await ss.connect();
    if (!mounted) return;

    ss.joinTask(widget.taskId);

    ss.socket.on('message:new', (data) {
      if (data['taskId'] == widget.taskId) {
        final newMsg = Message.fromJson(data);
        if (mounted && !_messages.any((m) => m.id == newMsg.id)) {
          setState(() => _messages.add(newMsg));
          _scrollToBottom();
          context.read<TaskProvider>().markTaskAsRead(widget.taskId);
        }
      }
    });

    ss.socket.on('typing', (data) {
      if (data['taskId'] == widget.taskId) {
        final userId = data['userId']?.toString();
        if (userId != me?['id']?.toString()) {
          setState(() => _typingUsers[int.parse(userId!)] = data['isTyping']);
        }
      }
    });

    ss.socket.on('message:update', (data) {
      if (data['taskId']?.toString() == widget.taskId.toString()) {
        final updated = Message.fromJson(data);
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == updated.id);
            if (idx != -1) {
              _messages[idx] = updated;
            }
          });
        }
      }
    });

    ss.socket.on('message:delete', (data) {
      if (data['taskId']?.toString() == widget.taskId.toString()) {
        final messageId = (data['id'] ?? data['messageId'] ?? data['id']).toString();
        if (mounted) {
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == messageId);
            if (idx != -1) {
              if (data['id'] != null && data['isDeleted'] == true) {
                _messages[idx] = Message.fromJson(data);
              } else {
                _messages[idx] = Message(
                  id: _messages[idx].id,
                  taskId: _messages[idx].taskId,
                  type: _messages[idx].type,
                  content: 'This message was deleted',
                  senderId: _messages[idx].senderId,
                  sender: _messages[idx].sender,
                  createdAt: _messages[idx].createdAt,
                  isDeleted: true,
                );
              }
            }
          });
        }
      }
    });

  }


  void _loadMessages() async {
    try {
      final msgs = await context.read<TaskProvider>().fetchTaskMessages(widget.taskId);
      if (mounted) {
        setState(() {
          _messages.clear();
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

    final ss = SocketService();

    if (_editingMessage != null) {
      ss.editMessage(widget.taskId, _editingMessage!.id, text, onAck: (ack) {
        if (mounted) {
          setState(() => _editingMessage = null);
          _messageController.clear();
        }
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;
    if (me == null) return;

    final optimistic = Message(
      id: 'tmp-${DateTime.now().millisecondsSinceEpoch}',
      taskId: widget.taskId,
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
      _messages.add(optimistic);
      _scrollToBottom();
    });

    final replyToId = _replyingTo?.id != null ? int.tryParse(_replyingTo!.id) : null;
    ss.sendMessage(widget.taskId, text, replyToId: replyToId, onAck: (ack) {
      if (mounted) {
        setState(() => _messages.removeWhere((m) => m.id == optimistic.id));
      }
    });

    _messageController.clear();
    setState(() => _replyingTo = null);
    ss.stopTyping(widget.taskId);
  }

  void _deleteMessage(String messageId) {
    SocketService().deleteMessage(widget.taskId, messageId);
  }

  void _startEdit(Message msg) {
    setState(() {
      _editingMessage = msg;
      _messageController.text = msg.content ?? '';
    });
  }

  void _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _pendingImage = File(image.path));
  }

  void _sendImage() async {
    if (_pendingImage == null) return;
    
    final imagePath = _pendingImage!.path;
    setState(() {
      _isUploading = true;
      _pendingImage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final me = authProvider.user;
    if (me == null) return;

    final optimistic = Message(
      id: 'tmp-img-${DateTime.now().millisecondsSinceEpoch}',
      taskId: widget.taskId,
      type: 'image',
      imageUrl: imagePath,
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
    try {
      final msg = await context.read<TaskProvider>().uploadTaskImage(widget.taskId, File(imagePath));
      SocketService().sendImage(widget.taskId, msg.imageUrl!, replyToId: replyToId, onAck: (ack) {
        if (mounted) {
          setState(() {
            _replyingTo = null;
            _isUploading = false;
            _messages.removeWhere((m) => m.id == optimistic.id);
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _messages.removeWhere((m) => m.id == optimistic.id);
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }


  @override
  void dispose() {
    final ss = SocketService();
    ss.stopTyping(widget.taskId);
    ss.leaveTask(widget.taskId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Widget _buildMessageBubble(Message msg, bool isMine) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final dateStr = DateFormat('hh:mm a').format(msg.createdAt.toLocal());

    return Dismissible(
      key: Key('chat-reply-${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (dir) async {
        setState(() => _replyingTo = msg);
        return false;
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        child: Icon(LucideIcons.reply, size: 20, color: th.colorScheme.primary),
      ),
      child: Padding(
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
              flex: 3,
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMine)
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text(msg.sender?.username ?? 'User',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ),
                  GestureDetector(
                    onLongPress: msg.isDeleted ? null : () {
                      _showActionSheet(msg, isMine);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMine
                            ? th.colorScheme.primary.withAlpha(isDark ? 50 : 30)
                            : (isDark ? Colors.white.withAlpha(15) : Colors.grey[200]),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isMine ? 20 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 20),
                        ),
                        border: Border.all(
                          color: isMine
                              ? th.colorScheme.primary.withAlpha(60)
                              : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(8)),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.replyInfo != null)
                            Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border(
                                  left: !isMine ? const BorderSide(color: Colors.grey, width: 3) : BorderSide.none,
                                  right: isMine ? const BorderSide(color: Colors.grey, width: 3) : BorderSide.none,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Replied to ${msg.replyInfo!['username'] ?? 'User'}',
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: th.colorScheme.primary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg.replyInfo!['content'] ?? (msg.replyInfo!['type'] == 'image' ? 'Image attachment' : ''),
                                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
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
                          Text(
                            msg.isDeleted ? 'This message was deleted' : (msg.content ?? ''), 
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontStyle: msg.isDeleted ? FontStyle.italic : null,
                              fontSize: msg.isDeleted ? 12 : 14,
                            )
                          ),
                          if (!msg.isDeleted && msg.editedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('edited', style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                            ),
                          const SizedBox(height: 4),
                          Text(dateStr, style: TextStyle(fontSize: 9, color: Colors.grey[600])),
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
            if (!isMine) const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  void _showActionSheet(Message msg, bool isMine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(LucideIcons.reply),
              title: const Text('Reply'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _replyingTo = msg);
              },
            ),
            if (isMine && msg.type == 'text')
              ListTile(
                leading: const Icon(LucideIcons.edit2),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startEdit(msg);
                },
              ),
            if (isMine)
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.redAccent),
                title: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteMessage(msg.id);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
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
          ? Image.network(
        sender!.profileImageUrl!.startsWith('http')
            ? sender.profileImageUrl!
            : '${SocketService().baseUrl}${sender.profileImageUrl}',
        fit: BoxFit.cover,
      )
          : Center(
        child: Text(
          (sender?.username ?? 'U').substring(0, 1).toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final me = context.watch<AuthProvider>().user;
    final mq = MediaQuery.of(context);
    final bottomInset = mq.viewInsets.bottom;
    final bottomPadding = mq.padding.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Room', style: TextStyle(fontSize: 10, color: Colors.grey)),
            Text(widget.taskTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
              final currentTask = tp.tasks.firstWhere((t) => t.id == widget.taskId, orElse: () => Task(id: widget.taskId, title: widget.taskTitle, description: '', status: 'unknown', priority: 'medium', creatorId: 0, assignees: [], points: [], updatedAt: DateTime.now()));
              if (currentTask.points.isEmpty) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: bottomInset > 0 ? 120 : 180),
                      child: SingleChildScrollView(
                        child: Column(
                          children: currentTask.points.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: InkWell(
                              onTap: () async {
                                await tp.togglePoint(currentTask.id, p.id, !p.isDone);
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
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: _isLoadingMessages
                ? const Center(child: CustomLoader())
                : RefreshIndicator(
              onRefresh: () async {
                _loadMessages();
              },
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final myId = me?['id']?.toString();
                  final senderId = (msg.senderId ?? msg.sender?.id)?.toString();
                  final isMine = senderId != null && myId != null && senderId == myId;
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
          _buildInput(th, isDark, bottomInset, bottomPadding),
        ],
      ),
    );
  }

  Widget _buildInput(ThemeData th, bool isDark, double bottomInset, double bottomPadding) {
    double effectiveBottomPadding = bottomInset > 0 ? 8.0 : 16.0 + bottomPadding;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, effectiveBottomPadding),
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
                   Icon(_replyingTo!.type == 'image' ? LucideIcons.image : LucideIcons.reply, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_replyingTo!.content ?? (_replyingTo!.type == 'image' ? 'Image attachment' : ''), style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)),
                  IconButton(onPressed: () => setState(() => _replyingTo = null), icon: const Icon(LucideIcons.x, size: 16)),
                ],
              ),
            ),
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: th.colorScheme.primary.withAlpha(10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: th.colorScheme.primary.withAlpha(30)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.edit2, size: 16, color: Colors.grey),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Editing message', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  IconButton(onPressed: () => setState(() {
                    _editingMessage = null;
                    _messageController.clear();
                  }), icon: const Icon(LucideIcons.x, size: 16)),
                ],
              ),
            ),
          if (_pendingImage != null)
             Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(_pendingImage!, width: 40, height: 40, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(child: Text('Image preview', style: TextStyle(fontSize: 12, color: Colors.grey))),
                  if (_isUploading)
                    const CustomLoader(size: 16)
                  else ...[
                      IconButton(onPressed: _sendImage, icon: Icon(LucideIcons.send, color: th.colorScheme.primary, size: 18)),
                      IconButton(onPressed: () => setState(() => _pendingImage = null), icon: const Icon(LucideIcons.x, size: 16)),
                  ]
                ],
              ),
            ),

          Row(
            children: [
              IconButton(onPressed: _pickImage, icon: const Icon(LucideIcons.plus, color: Colors.grey)),

              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: 4,
                  minLines: 1,
                  onChanged: (val) {
                    final ss = SocketService();
                    if (val.isNotEmpty) ss.startTyping(widget.taskId);
                    else ss.stopTyping(widget.taskId);
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