import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../provider/task_provider.dart';
import '../../provider/auth_provider.dart';
import '../../models/task_model.dart';

class BoardScreen extends StatefulWidget {
  const BoardScreen({super.key});

  @override
  State<BoardScreen> createState() => _BoardScreenState();
}

class _BoardScreenState extends State<BoardScreen> {
  final List<String> _tabs = ['Pending', 'In Progress', 'Hold', 'Completed'];
  String _selectedTab = 'Pending';

  // Form Controllers
  final _titleController = TextEditingController();
  final _pointInputController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  
  String _status = 'pending';
  String _priority = 'medium';
  final List<String> _points = [];

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

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
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
          ? DateFormat('MMM dd, yyyy').parse(_startDateController.text).toIso8601String()
          : null,
      'dueDate': _endDateController.text.isNotEmpty
          ? DateFormat('MMM dd, yyyy').parse(_endDateController.text).toIso8601String()
          : null,
      'points': _points.map((p) => {'label': p}).toList(),
      'creatorId': auth.user?['id'],
    };

    try {
      await tp.createTask(payload);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void _showCreateTaskPopup() {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    // Reset controllers
    _titleController.clear();
    _pointInputController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _status = 'pending';
    _priority = 'medium';
    _points.clear();

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
                              const Text('Admin', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                              const Text('Create task', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                            ],
                          ),
                          IconButton(
                            icon: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black.withAlpha(10), shape: BoxShape.circle),
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
                                hintText: 'E.g. Prepare weekly operations report',
                                fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
                                      if (_pointInputController.text.isNotEmpty) {
                                        setModalState(() {
                                          _points.add(_pointInputController.text);
                                          _pointInputController.clear();
                                        });
                                      }
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Add a requirement...',
                                      fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                      filled: true,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    if (_pointInputController.text.isNotEmpty) {
                                      setModalState(() {
                                        _points.add(_pointInputController.text);
                                        _pointInputController.clear();
                                      });
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(color: th.colorScheme.primary, borderRadius: BorderRadius.circular(16)),
                                    child: const Icon(LucideIcons.plus, size: 20, color: Colors.black),
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
                                  children: _points.map((p) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: th.colorScheme.primary.withAlpha(30),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: th.colorScheme.primary.withAlpha(50)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: th.colorScheme.primary)),
                                        const SizedBox(width: 8),
                                        GestureDetector(
                                          onTap: () => setModalState(() => _points.remove(p)),
                                          child: Icon(LucideIcons.x, size: 14, color: th.colorScheme.primary),
                                        ),
                                      ],
                                    ),
                                  )).toList(),
                                ),
                              ),
                            const SizedBox(height: 20),
  
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Status'),
                                      DropdownButtonFormField<String>(
                                        value: _status,
                                        dropdownColor: th.scaffoldBackgroundColor,
                                        elevation: 8,
                                        decoration: InputDecoration(
                                          fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                        items: _statusOptions.map((opt) => DropdownMenuItem(
                                          value: opt['value'],
                                          child: Text(opt['label']!, style: const TextStyle(fontSize: 14)),
                                        )).toList(),
                                        onChanged: (val) => setModalState(() => _status = val!),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Priority'),
                                      DropdownButtonFormField<String>(
                                        value: _priority,
                                        dropdownColor: th.scaffoldBackgroundColor,
                                        decoration: InputDecoration(
                                          fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                        items: _priorityOptions.map((opt) => DropdownMenuItem(
                                          value: opt['value'],
                                          child: Text(opt['label']!, style: const TextStyle(fontSize: 14)),
                                        )).toList(),
                                        onChanged: (val) => setModalState(() => _priority = val!),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('Start date'),
                                      TextField(
                                        controller: _startDateController,
                                        readOnly: true,
                                        onTap: () => _selectDate(ctx, _startDateController),
                                        decoration: InputDecoration(
                                          hintText: 'Pick a date',
                                          prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                                          fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLabel('End date'),
                                      TextField(
                                        controller: _endDateController,
                                        readOnly: true,
                                        onTap: () => _selectDate(ctx, _endDateController),
                                        decoration: InputDecoration(
                                          hintText: 'Pick a date',
                                          prefixIcon: const Icon(LucideIcons.calendar, size: 18),
                                          fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                          filled: true,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            
                            _buildLabel('Assign users'),
                            TextField(
                              decoration: InputDecoration(
                                hintText: 'Search users...',
                                prefixIcon: const Icon(LucideIcons.search, size: 18),
                                fillColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                filled: true,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              ),
                            ),
                            const SizedBox(height: 32),
                            
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: th.colorScheme.primary,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    onPressed: _onCreateTask,
                                    child: const Text('Create task', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
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
          filter: ui.ImageFilter.blur(sigmaX: 5 * anim1.value, sigmaY: 5 * anim1.value),
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
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
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;

    return SingleChildScrollView(
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
                  child: child,
                ),
              );
            },
            child: const Text('Workspace', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey)),
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
                  child: child,
                ),
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Task Board', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5)),
                if (context.watch<AuthProvider>().user?['role'] == 'admin')
                  ElevatedButton.icon(
                    onPressed: _showCreateTaskPopup,
                    icon: const Icon(LucideIcons.plus, size: 16),
                    label: const Text('Create Task'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: th.colorScheme.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  )
              ],
            ),
          ),
          const SizedBox(height: 24),
          
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? th.colorScheme.primary : (isDark ? Colors.white.withAlpha(20) : Colors.black.withAlpha(10)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.black : (isDark ? Colors.white70 : Colors.black87),
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

    final filteredTasks = tp.tasks.where((t) => t.status == statusMap[_selectedTab]).toList();

    if (tp.isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator()));
    }

    if (filteredTasks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('No $_selectedTab tasks found.', style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(
      children: filteredTasks.map((t) => _buildTaskCard(
        isDark, 
        th, 
        t.title, 
        t.status, 
        t.priority, 
        DateFormat('MMM dd').format(t.updatedAt), 
        t.points.length, 
        0, 
        0
      )).toList(),
    );
  }

  Widget _buildTaskCard(bool isDark, ThemeData th, String title, String status, String priority, String date, int points, int index, int delayMs) {
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withAlpha(13) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isDark ? Colors.white.withAlpha(25) : Colors.black.withAlpha(13)),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withAlpha(8),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.moreHorizontal, size: 18, color: Colors.grey),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: th.colorScheme.primary.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: th.colorScheme.primary)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withAlpha(50)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(priority, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.listTodo, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$points points', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(date, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            )
          ],
        ),
      ),
    );
  }
}
