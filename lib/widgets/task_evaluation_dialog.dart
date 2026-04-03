import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/evaluation_model.dart';
import '../provider/task_provider.dart';
import '../provider/auth_provider.dart';
import '../services/socket_service.dart';

class TaskEvaluationDialog extends StatefulWidget {
  final Task task;

  const TaskEvaluationDialog({super.key, required this.task});

  @override
  State<TaskEvaluationDialog> createState() => _TaskEvaluationDialogState();
}

class _TaskEvaluationDialogState extends State<TaskEvaluationDialog> {
  bool _loading = true;
  List<Evaluation> _evaluations = [];
  Map<int, double> _ratings = {};
  Map<int, TextEditingController> _controllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final evals = await context.read<TaskProvider>().fetchEvaluations(widget.task.id);
      setState(() {
        _evaluations = evals;
        for (var assignee in widget.task.assignees) {
          final existing = evals.where((e) => e.userId == assignee.id).toList();
          if (existing.isNotEmpty) {
            _ratings[assignee.id] = existing.first.rating;
            _controllers[assignee.id] = TextEditingController(text: existing.first.remarks);
          } else {
            _ratings[assignee.id] = 0.0;
            _controllers[assignee.id] = TextEditingController();
          }
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(int userId) async {
    setState(() => _saving = true);
    try {
      final data = {
        'userId': userId,
        'rating': _ratings[userId] ?? 0.0,
        'remarks': _controllers[userId]?.text ?? '',
      };
      final updated = await context.read<TaskProvider>().saveEvaluation(widget.task.id, data);
      setState(() {
        _evaluations = updated;
        _saving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evaluation saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final isDark = th.brightness == Brightness.dark;
    final isAdmin = context.watch<AuthProvider>().user?['role'] == 'admin';

    // Calculate Points Progress
    final totalPoints = widget.task.points.length;
    final completedPoints = widget.task.points.where((p) => p.isDone).length;
    final progress = totalPoints > 0 ? completedPoints / totalPoints : 0.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: th.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(isDark ? 50 : 20),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                   Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.withAlpha(30),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.star_rounded, color: Colors.amber),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Task Evaluation', style: th.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        Text(widget.task.title, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                      ],
                    ),
                  ),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),

            const Divider(height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Task Summary Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Points Completion', style: TextStyle(fontWeight: FontWeight.w600)),
                              Text('$completedPoints/$totalPoints', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: Colors.blue.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                            minHeight: 8,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Assignee Evaluations', style: th.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    const SizedBox(height: 12),

                    if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
                    else if (widget.task.assignees.isEmpty)
                      const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No assignees to evaluate')))
                    else
                      ...widget.task.assignees.map((assignee) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.withAlpha(40)),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isDark ? Colors.white10 : Colors.black.withAlpha(5),
                                      backgroundImage: assignee.profileImageUrl != null
                                          ? NetworkImage(assignee.profileImageUrl!)
                                          : null,
                                      child: assignee.profileImageUrl == null
                                          ? Text(assignee.username[0].toUpperCase(), 
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(assignee.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                                          Text(assignee.role ?? 'Assignee', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                        ],
                                      ),
                                    ),
                                    if (isAdmin)
                                      TextButton(
                                        onPressed: _saving ? null : () => _submit(assignee.id),
                                        child: Text(_saving ? 'Saving...' : 'Update'),
                                      )
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                // Stars
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(5, (index) {
                                    final val = index + 1.0;
                                    final isSelected = (_ratings[assignee.id] ?? 0.0) >= val;
                                    return IconButton(
                                      onPressed: isAdmin ? () {
                                        setState(() => _ratings[assignee.id] = val);
                                      } : null,
                                      icon: Icon(
                                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                                        color: isSelected ? Colors.amber : Colors.grey[400],
                                        size: 32,
                                      ),
                                    );
                                  }),
                                ),

                                const SizedBox(height: 8),

                                // Remarks
                                TextField(
                                  controller: _controllers[assignee.id],
                                  enabled: isAdmin,
                                  style: const TextStyle(fontSize: 14),
                                  maxLines: 2,
                                  decoration: InputDecoration(
                                    hintText: 'Add remarks...',
                                    hintStyle: TextStyle(color: Colors.grey[400]),
                                    contentPadding: const EdgeInsets.all(12),
                                    filled: true,
                                    fillColor: isDark ? Colors.white.withAlpha(5) : Colors.black.withAlpha(5),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: th.primaryColor,
                  foregroundColor: Colors.white,
                  // minimumSize: const Offset(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
