import 'package:flutter/material.dart';

import 'package:common/api/api_client.dart';

class MyWellnessPlanPage extends StatefulWidget {
  const MyWellnessPlanPage({super.key});

  @override
  State<MyWellnessPlanPage> createState() => _MyWellnessPlanPageState();
}

class _MyWellnessPlanPageState extends State<MyWellnessPlanPage> {
  final ApiClient _api = ApiClient();
  final Set<int> _updatingTaskIds = <int>{};

  bool _loading = true;
  bool _refreshing = false;
  String? _errorMessage;
  WellnessTaskSummary _summary = const WellnessTaskSummary(total: 0, completed: 0);
  List<WellnessTaskItem> _dailyTasks = const [];
  List<WellnessTaskItem> _eveningTasks = const [];

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _refreshing = true;
        _errorMessage = null;
      });
    }

    try {
      final data = await _api.fetchWellnessTasks();
      if (!mounted) return;
      setState(() {
        _summary = data.summary;
        _dailyTasks = data.daily;
        _eveningTasks = data.evening;
        _loading = false;
        _refreshing = false;
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
        _refreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong. Please try again. ($error)';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Future<void> _handleRefresh() => _loadTasks(showLoader: false);

  Future<void> _toggleTask(WellnessTaskItem task) async {
    setState(() {
      _updatingTaskIds.add(task.id);
    });

    try {
      final updated =
          await _api.toggleWellnessTaskCompletion(task.id, !task.isCompleted);

      if (!mounted) return;
      setState(() {
        _replaceTask(updated);
        _updatingTaskIds.remove(task.id);
      });
    } on ApiClientException catch (error) {
      if (!mounted) return;
      setState(() {
        _updatingTaskIds.remove(task.id);
      });
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _updatingTaskIds.remove(task.id);
      });
      _showSnackBar('Unable to update task. Please try again. ($error)');
    }
  }

  Future<void> _promptAddTask(WellnessTaskCategory category) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${category.displayLabel} Item'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Describe your task',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }

    await _addTask(result, category);
  }

  Future<void> _addTask(String title, WellnessTaskCategory category) async {
    try {
      final created =
          await _api.createWellnessTask(title: title, category: category);

      if (!mounted) return;
      setState(() {
        switch (created.category) {
          case WellnessTaskCategory.daily:
            _dailyTasks = [..._dailyTasks, created];
            break;
          case WellnessTaskCategory.evening:
            _eveningTasks = [..._eveningTasks, created];
            break;
        }
        _recalculateSummary();
      });
      _showSnackBar('Task added');
    } on ApiClientException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Unable to add task. Please try again. ($error)');
    }
  }

  Future<void> _confirmDeleteTask(WellnessTaskItem task) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove task?'),
        content: Text(
          'Are you sure you want to delete "${task.title}" from your plan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _api.deleteWellnessTask(task.id);
      if (!mounted) return;
      setState(() {
        _removeTask(task);
        _recalculateSummary();
      });
      _showSnackBar('Task removed');
    } on ApiClientException catch (error) {
      if (!mounted) return;
      _showSnackBar(error.message);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar('Unable to delete task. Please try again. ($error)');
    }
  }

  void _replaceTask(WellnessTaskItem updated) {
    final list = updated.category == WellnessTaskCategory.daily
        ? _dailyTasks
        : _eveningTasks;

    final index = list.indexWhere((task) => task.id == updated.id);
    if (index == -1) {
      _loadTasks();
      return;
    }

    if (updated.category == WellnessTaskCategory.daily) {
      _dailyTasks = [
        for (var i = 0; i < _dailyTasks.length; i++)
          if (_dailyTasks[i].id == updated.id) updated else _dailyTasks[i],
      ];
    } else {
      _eveningTasks = [
        for (var i = 0; i < _eveningTasks.length; i++)
          if (_eveningTasks[i].id == updated.id) updated else _eveningTasks[i],
      ];
    }

    _recalculateSummary();
  }

  void _removeTask(WellnessTaskItem task) {
    if (task.category == WellnessTaskCategory.daily) {
      _dailyTasks = _dailyTasks.where((item) => item.id != task.id).toList();
    } else {
      _eveningTasks =
          _eveningTasks.where((item) => item.id != task.id).toList();
    }
  }

  void _recalculateSummary() {
    final tasks = [..._dailyTasks, ..._eveningTasks];
    _summary = WellnessTaskSummary(
      total: tasks.length,
      completed: tasks.where((task) => task.isCompleted).length,
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Wellness Plan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF8B5FBF),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            tooltip: 'Refresh',
            onPressed: _loading ? null : () => _loadTasks(),
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && !_refreshing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _loadTasks(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                const SizedBox(height: 24),
                _buildTaskSection(
                  category: WellnessTaskCategory.daily,
                  tasks: _dailyTasks,
                ),
                const SizedBox(height: 32),
                _buildTaskSection(
                  category: WellnessTaskCategory.evening,
                  tasks: _eveningTasks,
                ),
                const SizedBox(height: 40),
                _buildQuote(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5FBF),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: const Text(
        'Your personalized daily mental-wellness roadmap.',
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    final completionPercent = (_summary.completionRatio * 100).round();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Overview',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You have completed $completionPercent% of your tasks (${_summary.completed}/${_summary.total}).',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF555555),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: _summary.completionRatio,
              backgroundColor: const Color(0xFFF5E9FF),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5FBF)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskSection({
    required WellnessTaskCategory category,
    required List<WellnessTaskItem> tasks,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          category.displayLabel,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 16),
        if (tasks.isEmpty)
          _buildEmptyState(category)
        else
          ...tasks.map(_buildTaskCard),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
            onPressed: () => _promptAddTask(category),
          ),
        ),
      ],
    );
  }

  Widget _buildTaskCard(WellnessTaskItem task) {
    final isUpdating = _updatingTaskIds.contains(task.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  task.title,
                  style: TextStyle(
                    fontSize: 16,
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null,
                    color:
                        task.isCompleted ? Colors.grey : Colors.black.withOpacity(0.87),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isUpdating)
                const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: task.isCompleted
                        ? Colors.grey[300]
                        : const Color(0xFF8B5FBF),
                    foregroundColor:
                        task.isCompleted ? Colors.black54 : Colors.white,
                  ),
                  onPressed: () => _toggleTask(task),
                  child: Text(task.isCompleted ? 'Completed' : 'Mark Done'),
                ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete') {
                    _confirmDeleteTask(task);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete'),
                  ),
                ],
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(WellnessTaskCategory category) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2D8F5)),
      ),
      child: Text(
        'No tasks yet. Tap “Add Task” to start building your ${category == WellnessTaskCategory.daily ? 'daily routine' : 'evening reflection'}',
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF666666),
        ),
      ),
    );
  }

  Widget _buildQuote() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: const Text(
        '"Consistency builds calm."',
        style: TextStyle(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: Color(0xFF666666),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}


