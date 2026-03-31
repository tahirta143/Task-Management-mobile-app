import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../provider/admin_provider.dart';
import '../../../models/task_model.dart';
import '../../../models/user_model.dart';
import '../../../provider/task_provider.dart';
import '../../../widgets/custom_loader.dart';

class AdminTasksScreen extends StatefulWidget {
  const AdminTasksScreen({super.key});

  @override
  State<AdminTasksScreen> createState() => _AdminTasksScreenState();
}

class _AdminTasksScreenState extends State<AdminTasksScreen> {
  String _selectedTab = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().fetchTasks();
      context.read<AdminProvider>().fetchUsers();
      context.read<AdminProvider>().fetchCompanies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final tp = Provider.of<TaskProvider>(context);

    final filtered = tp.tasks.where((t) {
      // Tab filter
      bool matchesTab = _selectedTab == 'All';
      if (!matchesTab) {
        final String statusStr = t.status.toLowerCase().replaceAll('_', ' ');
        final String tabStr = _selectedTab.toLowerCase();
        matchesTab = statusStr == tabStr;
      }
      
      // Search filter
      bool matchesSearch = _searchQuery.isEmpty;
      if (!matchesSearch) {
        final q = _searchQuery.toLowerCase();
        matchesSearch = t.title.toLowerCase().contains(q) || (t.description ?? '').toLowerCase().contains(q) || t.id.toString().contains(q);
      }
      
      return matchesTab && matchesSearch;
    }).toList();

    return Container(
      color: Colors.transparent,
      child: tp.isLoading
          ? const CustomLoader()
          : RefreshIndicator(
        onRefresh: () async {
          await tp.fetchTasks();
          await context.read<AdminProvider>().fetchUsers();
          await context.read<AdminProvider>().fetchCompanies();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADMIN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: th.colorScheme.primary, letterSpacing: 1.5)),
                    const Text('Task Manager', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
                Text('${filtered.length} items', style: TextStyle(fontSize: 12, color: th.colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildAnimatedBlock(200, TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
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
    ));
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
    // Local controllers and state for editing
    final titleController = TextEditingController(text: t.title);
    final pointInputController = TextEditingController();
    
    // Convert TaskPoint to editable Map format or use them directly
    List<Map<String, dynamic>> points = t.points.map((p) => {'label': p.label, 'isDone': p.isDone}).toList();
    List<int> assigneeIds = t.assignees.map((a) => a.id).toList();
    
    String status = t.status;
    String priority = t.priority;
    int? companyId = t.companyId;
    DateTime? startDate = t.startDate;
    DateTime? dueDate = t.dueDate;
    TimeOfDay? dueTime = t.dueDate != null ? TimeOfDay.fromDateTime(t.dueDate!) : const TimeOfDay(hour: 12, minute: 0);
    
    String searchAssignee = '';
    bool isSaving = false;
    bool isDeleting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final tp = context.watch<TaskProvider>();
            final ap = context.watch<AdminProvider>();
            final double width = MediaQuery.of(context).size.width;
            final double modalWidth = min(width * 0.95, 540);

            final filteredUsers = ap.users.where((u) {
              if (u.role == 'admin') return false;
              if (searchAssignee.isEmpty) return true;
              final q = searchAssignee.toLowerCase();
              return u.username.toLowerCase().contains(q) || (u.email ?? '').toLowerCase().contains(q);
            }).toList();

            Future<void> onSave() async {
              setModalState(() => isSaving = true);
              try {
                // Merge date and time
                DateTime? finalDueDate;
                if (dueDate != null) {
                  finalDueDate = DateTime(dueDate!.year, dueDate!.month, dueDate!.day, dueTime!.hour, dueTime!.minute);
                }

                final patch = {
                  'title': titleController.text.trim(),
                  'status': status,
                  'priority': priority,
                  'companyId': companyId,
                  'startDate': startDate?.toIso8601String(),
                  'dueDate': finalDueDate?.toIso8601String(),
                  'points': points,
                };

                await tp.updateTask(t.id, patch);
                await tp.replaceTaskAssignees(t.id, assigneeIds);
                
                if (mounted) Navigator.pop(ctx);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              } finally {
                setModalState(() => isSaving = false);
              }
            }

            Future<void> onDelete() async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  title: const Text('Delete Task'),
                  content: const Text('Are you sure you want to remove this task?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, false), child: const Text('Cancel')),
                    TextButton(onPressed: () => Navigator.pop(dialogCtx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('Delete')),
                  ],
                ),
              );

              if (confirm == true) {
                setModalState(() => isDeleting = true);
                try {
                  await tp.deleteTask(t.id);
                  if (mounted) Navigator.pop(ctx);
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                } finally {
                  setModalState(() => isDeleting = false);
                }
              }
            }

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
                        width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.grey.withAlpha(100), borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Edit Task', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text('#${t.id}', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(LucideIcons.trash2, color: Colors.red.withAlpha(150), size: 18),
                              onPressed: isSaving || isDeleting ? null : onDelete,
                            ),
                            IconButton(icon: const Icon(LucideIcons.x), onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: 32),
                        children: [
                          _buildLabel('Title'),
                          TextField(
                            controller: titleController,
                            decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                          ),
                          const SizedBox(height: 16),

                          _buildLabel('Points (Checklist)'),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: pointInputController,
                                  decoration: const InputDecoration(hintText: 'Add a point...', border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                                  onSubmitted: (_) {
                                    if (pointInputController.text.trim().isNotEmpty) {
                                      setModalState(() {
                                        points.add({'label': pointInputController.text.trim(), 'isDone': false});
                                        pointInputController.clear();
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filled(
                                style: IconButton.styleFrom(backgroundColor: th.colorScheme.primary, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                icon: const Icon(LucideIcons.plus, size: 20),
                                onPressed: () {
                                  if (pointInputController.text.trim().isNotEmpty) {
                                    setModalState(() {
                                      points.add({'label': pointInputController.text.trim(), 'isDone': false});
                                      pointInputController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          if (points.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: points.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final p = entry.value;
                                return Chip(
                                  label: Text(p['label'], style: const TextStyle(fontSize: 11)),
                                  avatar: Icon(p['isDone'] ? LucideIcons.check : LucideIcons.circle, size: 12, color: p['isDone'] ? Colors.green : Colors.grey),
                                  onDeleted: () => setModalState(() => points.removeAt(idx)),
                                  deleteIcon: const Icon(LucideIcons.x, size: 14),
                                  backgroundColor: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(5),
                                );
                              }).toList(),
                            )
                          ],
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Status'),
                                    DropdownButtonFormField<String>(
                                      value: status,
                                      decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                                      items: ['pending', 'in_progress', 'hold', 'completed'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                      onChanged: (val) => setModalState(() => status = val!),
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
                                      value: priority,
                                      decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                                      items: ['low', 'medium', 'high', 'urgent'].map((p) => DropdownMenuItem(value: p, child: Text(p.toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
                                      onChanged: (val) => setModalState(() => priority = val!),
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
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildLabel('Start Date'),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(context: context, initialDate: startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                                        if (d != null) setModalState(() => startDate = d);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withAlpha(100)), borderRadius: BorderRadius.circular(12)),
                                        child: Row(children: [const Icon(LucideIcons.calendar, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(startDate == null ? 'None' : DateFormat('dd MMM yyyy').format(startDate!), style: const TextStyle(fontSize: 13))]),
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
                                    _buildLabel('Due Date'),
                                    InkWell(
                                      onTap: () async {
                                        final d = await showDatePicker(context: context, initialDate: dueDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
                                        if (d != null) setModalState(() => dueDate = d);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.withAlpha(100)), borderRadius: BorderRadius.circular(12)),
                                        child: Row(children: [const Icon(LucideIcons.calendar, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(dueDate == null ? 'None' : DateFormat('dd MMM yyyy').format(dueDate!), style: const TextStyle(fontSize: 13))]),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          _buildLabel('Due Time'),
                          InkWell(
                            onTap: () async {
                              final t = await showTimePicker(context: context, initialTime: dueTime ?? TimeOfDay.now());
                              if (t != null) setModalState(() => dueTime = t);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                              decoration: BoxDecoration(border: Border.all(color: Colors.grey.withAlpha(100)), borderRadius: BorderRadius.circular(12)),
                              child: Row(children: [const Icon(LucideIcons.clock, size: 16, color: Colors.grey), const SizedBox(width: 8), Text(dueTime == null ? 'None' : dueTime!.format(context), style: const TextStyle(fontSize: 13))]),
                            ),
                          ),
                          const SizedBox(height: 16),

                          _buildLabel('Company (Optional)'),
                          DropdownButtonFormField<int?>(
                            value: ap.companies.any((c) => c.id == companyId) ? companyId : null,
                            decoration: const InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)))),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('No company', style: TextStyle(fontSize: 12))),
                              ...ap.companies.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 12)))),
                            ],
                            onChanged: (val) => setModalState(() => companyId = val),
                          ),
                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildLabel('Assignees'),
                              Text('${assigneeIds.length} selected', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                          TextField(
                            decoration: InputDecoration(hintText: 'Search staff...', prefixIcon: const Icon(LucideIcons.search, size: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                            onChanged: (val) => setModalState(() => searchAssignee = val),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3),
                            itemCount: filteredUsers.length,
                            itemBuilder: (context, index) {
                              final u = filteredUsers[index];
                              final isSelected = assigneeIds.contains(u.id);
                              return InkWell(
                                onTap: () => setModalState(() => isSelected ? assigneeIds.remove(u.id) : assigneeIds.add(u.id)),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? th.colorScheme.primary.withAlpha(20) : (isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5)),
                                    border: Border.all(color: isSelected ? th.colorScheme.primary : (isDark ? Colors.white10 : Colors.black12)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(radius: 12, backgroundImage: u.profileImageUrl != null ? NetworkImage(u.profileImageUrl!) : null, child: u.profileImageUrl == null ? Text(u.username[0].toUpperCase(), style: const TextStyle(fontSize: 8)) : null),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(u.username, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      if (isSelected) Icon(LucideIcons.check, size: 14, color: th.colorScheme.primary),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: th.colorScheme.primary,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: isSaving || isDeleting ? null : onSave,
                              child: Text(isSaving ? 'Saving...' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
    );
  }
}
