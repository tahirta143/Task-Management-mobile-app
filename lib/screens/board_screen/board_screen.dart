import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:task_manager/provider/admin_provider.dart';
import 'package:task_manager/screens/board_screen/task_detail_screen.dart';
import 'package:task_manager/services/socket_service.dart';
import '../../provider/task_provider.dart';
import '../../provider/auth_provider.dart';
import '../../models/task_model.dart';
import '../../widgets/custom_loader.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final List<String> _tabs = ['Pending', 'In Progress', 'Hold', 'Completed'];
  String _selectedTab = 'Pending';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Form Controllers
  final _titleController = TextEditingController();
  final _pointInputController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _dueTimeController = TextEditingController();

  String _status = 'pending';
  String _priority = 'medium';
  final List<String> _points = [];
  final List<int> _selectedAssigneeIds = [];
  String _dueTime = DateFormat('HH:mm').format(DateTime.now());
  // Removed initialization here to use controller
  String _userSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _initSocket();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
    });
  }

  void _initSocket() async {
    final ss = SocketService();
    await ss.connect();

    ss.socket.on('task:new', (_) {
      if (mounted) context.read<TaskProvider>().fetchTasks();
    });
    ss.socket.on('task:update', (_) {
      if (mounted) context.read<TaskProvider>().fetchTasks();
    });
    ss.socket.on('task:delete', (_) {
      if (mounted) context.read<TaskProvider>().fetchTasks();
    });
    ss.socket.on('message:new', (_) {
      if (mounted) context.read<TaskProvider>().fetchTasks();
    });
  }

  @override
  void dispose() {
    final ss = SocketService();
    ss.socket.off('task:new');
    ss.socket.off('task:update');
    ss.socket.off('task:delete');
    ss.socket.off('message:new');
    _titleController.dispose();
    _pointInputController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _dueTimeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  final List<Map<String, String>> _statusOptions = [
    {'value': 'pending', 'label': 'Pending'},
    {'value': 'in_progress', 'label': 'In Progress'},
    {'value': 'hold', 'label': 'Hold'},
  ];

  final List<Map<String, String>> _priorityOptions = [
    {'value': 'low', 'label': 'Low'},
    {'value': 'medium', 'label': 'Medium'},
    {'value': 'high', 'label': 'High'},
    {'value': 'urgent', 'label': 'Urgent'},
  ];

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.black,
              surface: Colors.grey[900]!,
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      controller.text = DateFormat('MMM dd, yyyy').format(picked);
    }
  }

  void _onCreateTask() async {
    if (_titleController.text.isEmpty) return;

    final tp = context.read<TaskProvider>();
    final auth = context.read<AuthProvider>();

    final payload = {
      'title': _titleController.text,
      'status': _status,
      'priority': _priority,
      'startDate': _startDateController.text.isNotEmpty
          ? DateFormat('MMM dd, yyyy')
          .parse(_startDateController.text)
          .toIso8601String()
          : null,
      'dueDate': _endDateController.text.isNotEmpty
          ? DateFormat('MMM dd, yyyy')
          .parse(_endDateController.text)
          .add(
        Duration(
          hours: DateFormat('hh:mm a').parse(_dueTimeController.text).hour,
          minutes: DateFormat('hh:mm a').parse(_dueTimeController.text).minute,
        ),
      )
          .toIso8601String()
          : null,
      'points': _points,
      'creatorId': auth.user?['id'],
      'assigneeIds': _selectedAssigneeIds,
    };

    try {
      await tp.createTask(payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateTaskPopup() {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    _titleController.clear();
    _pointInputController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _dueTimeController.text = DateFormat('hh:mm a').format(DateTime.now());
    _status = 'pending';
    _priority = 'medium';
    _points.clear();
    _selectedAssigneeIds.clear();
    // _dueTime will be retrieved from controller text
    _userSearchQuery = '';

    context.read<AdminProvider>().fetchUsers();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Create Task Dialog',
      barrierColor: Colors.black.withAlpha(120),
      transitionDuration: const Duration(milliseconds: 350),
      pageBuilder: (ctx, anim1, anim2) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final double width = MediaQuery.of(context).size.width;
            final double modalWidth = min(width * 0.95, 540);

            return Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: modalWidth,
                  height: MediaQuery.of(context).size.height * 0.9,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: th.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(40),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Admin',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500)),
                              const Text('Create task',
                                  style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: -0.5)),
                            ],
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(10),
                                  shape: BoxShape.circle),
                              child: const Icon(LucideIcons.x, size: 20),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildLabel('Title'),
                            TextField(
                              controller: _titleController,
                              decoration: InputDecoration(
                                hintText:
                                'E.g. Prepare weekly operations report',
                                fillColor: isDark
                                    ? Colors.white.withAlpha(10)
                                    : Colors.black.withAlpha(5),
                                filled: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildLabel('Points (checklist items)'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _pointInputController,
                                    onSubmitted: (_) {
                                      if (_pointInputController
                                          .text.isNotEmpty) {
                                        setModalState(() {
                                          _points
                                              .add(_pointInputController.text);
                                          _pointInputController.clear();
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Add a requirement...',
                                      fillColor: isDark
                                          ? Colors.white.withAlpha(10)
                                          : Colors.black.withAlpha(5),
                                      filled: true,
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    if (_pointInputController.text.isNotEmpty) {
                                      setModalState(() {
                                        _points
                                            .add(_pointInputController.text);
                                        _pointInputController.clear();
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                        color: th.colorScheme.primary,
                                        borderRadius:
                                        BorderRadius.circular(16)),
                                    child: const Icon(LucideIcons.plus,
                                        size: 20, color: Colors.black),
                                  ),
                                ),
                              ],
                            ),
                            if (_points.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _points
                                      .map((p) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: th.colorScheme.primary
                                          .withAlpha(30),
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      border: Border.all(
                                          color: th.colorScheme.primary
                                              .withAlpha(50)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(p,
                                            style: TextStyle(
                                                fontSize: 12,
                                                fontWeight:
                                                FontWeight.bold,
                                                color: th.colorScheme
                                                    .primary)),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => setModalState(
                                                  () => _points.remove(p)),
                                          child: Icon(LucideIcons.x,
                                              size: 14,
                                              color: th
                                                  .colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                  ))
                                      .toList(),
                                ),
                              ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Status'),
                                      DropdownButtonFormField<String>(
                                        value: _status,
                                        dropdownColor:
                                        th.scaffoldBackgroundColor,
                                        elevation: 8,
                                        decoration: InputDecoration(
                                          fillColor: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              borderSide: BorderSide.none),
                                        ),
                                        items: _statusOptions
                                            .map((opt) => DropdownMenuItem(
                                          value: opt['value']!,
                                          child: Text(opt['label']!,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ))
                                            .toList(),
                                        onChanged: (val) => setModalState(
                                                () => _status = val!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Priority'),
                                      DropdownButtonFormField<String>(
                                        value: _priority,
                                        dropdownColor:
                                        th.scaffoldBackgroundColor,
                                        decoration: InputDecoration(
                                          fillColor: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              borderSide: BorderSide.none),
                                        ),
                                        items: _priorityOptions
                                            .map((opt) => DropdownMenuItem(
                                          value: opt['value']!,
                                          child: Text(opt['label']!,
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ))
                                            .toList(),
                                        onChanged: (val) => setModalState(
                                                () => _priority = val!),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Start date'),
                                      TextField(
                                        controller: _startDateController,
                                        readOnly: true,
                                        onTap: () =>
                                            _selectDate(ctx, _startDateController),
                                        style:
                                        const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Pick a date',
                                          prefixIcon: const Icon(
                                              LucideIcons.calendar,
                                              size: 16),
                                          fillColor: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('End date'),
                                      TextField(
                                        controller: _endDateController,
                                        readOnly: true,
                                        onTap: () =>
                                            _selectDate(ctx, _endDateController),
                                        style:
                                        const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText: 'Pick a date',
                                          prefixIcon: const Icon(
                                              LucideIcons.calendar,
                                              size: 16),
                                          fillColor: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Time'),
                                      TextField(
                                        controller: _dueTimeController,
                                        readOnly: true,
                                        onTap: () async {
                                          final TimeOfDay? picked =
                                          await showTimePicker(
                                            context: context,
                                            initialTime: TimeOfDay(
                                                hour: DateFormat('hh:mm a').parse(_dueTimeController.text).hour,
                                              minute: DateFormat('hh:mm a').parse(_dueTimeController.text).minute),
                                          );
                                          if (picked != null) {
                                            setModalState(() {
                                              final now = DateTime.now();
                                              final dt = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
                                              _dueTimeController.text = DateFormat('hh:mm a').format(dt);
                                            });
                                          }
                                        },
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          prefixIcon: const Icon(
                                              LucideIcons.clock,
                                              size: 16),
                                          fillColor: isDark
                                              ? Colors.white.withAlpha(10)
                                              : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(
                                              borderRadius:
                                              BorderRadius.circular(16),
                                              borderSide: BorderSide.none),
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Assign Users
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildLabel('Assign users'),
                                Text(
                                    '${_selectedAssigneeIds.length} selected',
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            TextField(
                              onChanged: (val) => setModalState(
                                      () => _userSearchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: const Icon(LucideIcons.search,
                                    size: 18),
                                fillColor: isDark
                                    ? Colors.white.withAlpha(10)
                                    : Colors.black.withAlpha(5),
                                filled: true,
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Consumer<AdminProvider>(
                              builder: (context, ap, child) {
                                  if (ap.isLoading && ap.users.isEmpty) {
                                    return const Padding(
                                      padding: EdgeInsets.all(24.0),
                                      child: CustomLoader(size: 24),
                                    );
                                  }

                                final staff = ap.users
                                    .where((u) =>
                                u.username.toLowerCase().contains(
                                    _userSearchQuery.toLowerCase()) ||
                                    (u.email?.toLowerCase().contains(
                                        _userSearchQuery
                                            .toLowerCase()) ??
                                        false))
                                    .toList();

                                if (staff.isEmpty) {
                                  return const Center(
                                      child: Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Text('No users found.',
                                              style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey))));
                                }

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics:
                                  const NeverScrollableScrollPhysics(),
                                  gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    childAspectRatio: 2.1,
                                    mainAxisSpacing: 8,
                                    crossAxisSpacing: 8,
                                  ),
                                  itemCount: staff.length,
                                  itemBuilder: (context, index) {
                                    final u = staff[index];
                                    final isSelected =
                                    _selectedAssigneeIds.contains(u.id);

                                    return InkWell(
                                      onTap: () {
                                        setModalState(() {
                                          if (isSelected)
                                            _selectedAssigneeIds.remove(u.id);
                                          else
                                            _selectedAssigneeIds.add(u.id);
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? th.colorScheme.primary
                                              .withAlpha(30)
                                              : (isDark
                                              ? Colors.white.withAlpha(8)
                                              : Colors.black.withAlpha(4)),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          border: Border.all(
                                              color: isSelected
                                                  ? th.colorScheme.primary
                                                  .withAlpha(100)
                                                  : Colors.transparent),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 24,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: isDark
                                                        ? Colors.white
                                                        .withAlpha(20)
                                                        : Colors.black
                                                        .withAlpha(10),
                                                    width: 0.5),
                                              ),
                                              child: ClipRRect(
                                                borderRadius:
                                                BorderRadius.circular(12),
                                                child: u.profileImageUrl !=
                                                    null
                                                    ? Image.network(
                                                    u.profileImageUrl!,
                                                    fit: BoxFit.cover)
                                                    : Center(
                                                  child: Text(
                                                    u.username
                                                        .substring(
                                                        0,
                                                        min(
                                                            2,
                                                            u.username
                                                                .length))
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                        fontSize: 7,
                                                        fontWeight:
                                                        FontWeight
                                                            .bold,
                                                        color:
                                                        Colors.grey),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                MainAxisAlignment.center,
                                                children: [
                                                  Text(u.username,
                                                      style: const TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                          FontWeight.bold),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  Text(u.email ?? "",
                                                      style: const TextStyle(
                                                          fontSize: 7,
                                                          color: Colors.grey),
                                                      maxLines: 1,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 32),

                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16)),
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: th.colorScheme.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(16)),
                                    ),
                                    onPressed: _onCreateTask,
                                    child: const Text('Create task',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(
              sigmaX: 5 * anim1.value, sigmaY: 5 * anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(
                  CurvedAnimation(
                      parent: anim1, curve: Curves.easeOutCubic)),
              child: SlideTransition(
                position: Tween<Offset>(
                    begin: const Offset(0, 0.05), end: Offset.zero)
                    .animate(CurvedAnimation(
                    parent: anim1, curve: Curves.easeOutCubic)),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final tp = Provider.of<TaskProvider>(context);

    return RefreshIndicator(
      onRefresh: () async {
        await tp.fetchTasks();
      },
      child: Container(
        color: Colors.transparent,
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
                padding: const EdgeInsets.all(16.0),
                child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text('Workflow',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey)),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Task Board',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5)),
                  if (context.watch<AuthProvider>().user?['role'] ==
                      'admin')
                    ElevatedButton(
                      onPressed: _showCreateTaskPopup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: th.colorScheme.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text('Create task',
                          style:
                          TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withAlpha(10)
                      : Colors.black.withAlpha(5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isDark
                          ? Colors.white.withAlpha(5)
                          : Colors.black.withAlpha(5)),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText:
                    'Search by ID, title, or description...',
                    hintStyle: TextStyle(
                        color: Colors.grey[500], fontSize: 14),
                    prefixIcon: const Icon(LucideIcons.search,
                        size: 18, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Tab Bar
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _tabs.map((tab) {
                    final isSelected = _selectedTab == tab;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedTab = tab;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? th.colorScheme.primary
                                : (isDark
                                ? Colors.white.withAlpha(20)
                                : Colors.black.withAlpha(10)),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tab,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Colors.black
                                  : (isDark
                                  ? Colors.white70
                                  : Colors.black87),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 24),

              _buildTasksForSelectedTab(isDark, th),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTasksForSelectedTab(bool isDark, ThemeData th) {
    final tp = Provider.of<TaskProvider>(context);
    final statusMap = {
      'Pending': 'pending',
      'In Progress': 'in_progress',
      'Hold': 'hold',
      'Completed': 'completed',
    };

    final filteredTasks = tp.tasks.where((t) {
      final status = statusMap[_selectedTab];
      final isPct100 = t.progressPercent == 100;
      
      bool matchesStatus = false;
      if (_selectedTab == 'Completed') {
        // Show tasks explicitly marked 'completed' OR those with 100% progress
        matchesStatus = t.status == 'completed' || isPct100;
      } else if (_selectedTab == 'In Progress') {
        // Show tasks that are 'in_progress' AND not yet 100%
        matchesStatus = t.status == 'in_progress' && !isPct100;
      } else {
        // For Pending/Hold, just use the status
        matchesStatus = t.status == status;
      }
      
      if (!matchesStatus) return false;

      if (_searchQuery.isEmpty) return true;

      final q = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(q) ||
          t.id.toString().contains(q) ||
          t.assignees.any((a) => a.username.toLowerCase().contains(q));
    }).toList();

    if (filteredTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(64.0),
          child: Column(
            children: [
              Icon(LucideIcons.searchX,
                  size: 48, color: Colors.grey.withAlpha(50)),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isEmpty
                    ? 'No $_selectedTab tasks found.'
                    : 'No matches found.',
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: filteredTasks.map((t) => _buildTaskCard(context, t)).toList(),
    );
  }

  Widget _buildTaskCard(BuildContext context, Task task) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    final totalPoints = task.points.length;
    final donePoints = task.points.where((p) => p.isDone).length;
    final progressPct = totalPoints > 0 ? (donePoints / totalPoints) : 0.0;

    int? daysLeft;
    if (task.dueDate != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final due = DateTime(
          task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
      daysLeft = due.difference(today).inDays;
    }

    Color priorityColor;
    Color priorityBg;
    switch (task.priority.toLowerCase()) {
      case 'urgent':
        priorityColor = const Color(0xFFF87171);
        priorityBg = priorityColor.withAlpha(40);
        break;
      case 'high':
        priorityColor = const Color(0xFFFB923C);
        priorityBg = priorityColor.withAlpha(40);
        break;
      case 'medium':
        priorityColor = const Color(0xFF818CF8);
        priorityBg = priorityColor.withAlpha(40);
        break;
      default:
        priorityColor = const Color(0xFF6EE7B7);
        priorityBg = priorityColor.withAlpha(40);
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TaskDetailScreen(task: task),
          ),
        ).then((_) => context.read<TaskProvider>().fetchTasks());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(10) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isDark
                  ? Colors.white.withAlpha(10)
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Text('#${task.id}',
                            style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: Colors.grey.withAlpha(150),
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (task.assignees.isNotEmpty)
                          Expanded(
                            child: Text(
                              task.assignees.map((a) {
                                if (a.username.isEmpty) return "User";
                                return a.username[0].toUpperCase() +
                                    a.username.substring(1);
                              }).join(', '),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (task.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text(task.unreadCount.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold)),
                        ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: priorityColor.withAlpha(80)),
                        ),
                        child: Text(
                          task.priority.toUpperCase(),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(LucideIcons.gripVertical,
                          size: 14, color: Colors.grey),
                    ],
                  ),
                ],
              ),
            ),

            // Title
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                task.title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: -0.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Progress Bar
            if (totalPoints > 0)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPct,
                        backgroundColor: isDark
                            ? Colors.white.withAlpha(10)
                            : Colors.black.withAlpha(10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressPct == 1.0
                              ? Colors.green
                              : (daysLeft != null && daysLeft! < 0
                              ? Colors.red
                              : (daysLeft != null && daysLeft! <= 3
                              ? Colors.orange
                              : th.colorScheme.primary)),
                        ),
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('$donePoints/$totalPoints',
                            style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                color: Colors.grey)),
                        Text('${(progressPct * 100).round()}%',
                            style: const TextStyle(
                                fontSize: 9,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),

            // Days Remaining
            if (daysLeft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildDaysChip(daysLeft!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDaysChip(int days) {
    final bool isOverdue = days < 0;
    final bool isDueToday = days == 0;
    final bool isSoon = days <= 3 && days > 0;

    Color color;
    Color bg;
    String label;

    if (isOverdue) {
      color = Colors.red[400]!;
      bg = color.withAlpha(30);
      label = '${days.abs()}d overdue';
    } else if (isDueToday) {
      color = Colors.amber[500]!;
      bg = color.withAlpha(30);
      label = 'Due today';
    } else if (isSoon) {
      color = Colors.orange[400]!;
      bg = color.withAlpha(30);
      label = '$days d left';
    } else {
      color = Colors.grey;
      bg = color.withAlpha(20);
      label = '$days d left';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.clock, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}