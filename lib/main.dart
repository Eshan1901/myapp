import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color _lightPrimary = Color(0xFF0F766E);
const Color _lightAccent = Color(0xFFEA580C);
const Color _darkPrimary = Color(0xFF2DD4BF);
const Color _darkAccent = Color(0xFFFB923C);

LinearGradient _backgroundGradient(bool isDarkMode) {
  if (isDarkMode) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF062A27), Color(0xFF0F172A), Color(0xFF1E293B)],
      stops: [0, 0.55, 1],
    );
  }
  return const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE6FFFA), Color(0xFFF5F3FF), Color(0xFFFFF7ED)],
    stops: [0, 0.5, 1],
  );
}

ThemeData _buildTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;
  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: isDark ? _darkPrimary : _lightPrimary,
        brightness: brightness,
      ).copyWith(
        primary: isDark ? _darkPrimary : _lightPrimary,
        secondary: isDark ? _darkAccent : _lightAccent,
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: Colors.transparent,
    textTheme: ThemeData(brightness: brightness).textTheme.copyWith(
      headlineSmall: const TextStyle(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
      ),
      titleLarge: const TextStyle(fontWeight: FontWeight.w700),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600),
      bodyMedium: const TextStyle(height: 1.35),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.white.withValues(alpha: 0.78),
      margin: EdgeInsets.zero,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      backgroundColor: isDark
          ? const Color(0xCC0B1324)
          : const Color(0xE6FFFFFF),
      indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white.withValues(alpha: 0.75),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SmartDashboardApp());
}

class SmartDashboardApp extends StatefulWidget {
  const SmartDashboardApp({super.key});

  @override
  State<SmartDashboardApp> createState() => _SmartDashboardAppState();
}

class _SmartDashboardAppState extends State<SmartDashboardApp> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Personal Dashboard',
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: _buildTheme(brightness: Brightness.light),
      darkTheme: _buildTheme(brightness: Brightness.dark),
      home: DashboardHost(
        isDarkMode: _isDarkMode,
        onToggleDarkMode: () {
          setState(() {
            _isDarkMode = !_isDarkMode;
          });
        },
      ),
    );
  }
}

class DashboardHost extends StatefulWidget {
  const DashboardHost({
    super.key,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  @override
  State<DashboardHost> createState() => _DashboardHostState();
}

class _DashboardHostState extends State<DashboardHost> {
  final DataStore _store = DataStore();
  final List<DashboardTask> _tasks = [];
  final List<String> _notes = [];
  final List<String> _favoriteQuotes = [];
  final Set<String> _remindedTaskIds = <String>{};
  int _selectedIndex = 0;
  int _quoteIndex = 0;
  bool _loading = true;
  Timer? _reminderTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _reminderTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkReminders(),
    );
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final snapshot = await _store.load();
    setState(() {
      _tasks
        ..clear()
        ..addAll(snapshot.tasks);
      _notes
        ..clear()
        ..addAll(snapshot.notes);
      _favoriteQuotes
        ..clear()
        ..addAll(snapshot.favoriteQuotes);
      _quoteIndex = snapshot.quoteIndex;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _store.save(
      tasks: _tasks,
      notes: _notes,
      favoriteQuotes: _favoriteQuotes,
      quoteIndex: _quoteIndex,
    );
  }

  int get _completedTasks => _tasks.where((task) => task.isCompleted).length;

  void _addTask(String title, {DateTime? reminderAt}) {
    setState(() {
      _tasks.add(
        DashboardTask(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          title: title,
          isCompleted: false,
          reminderAt: reminderAt,
        ),
      );
    });
    _persist();
  }

  void _updateTask(String taskId, String title, DateTime? reminderAt) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return;
    setState(() {
      _tasks[index] = _tasks[index].copyWith(
        title: title,
        reminderAt: reminderAt,
      );
    });
    _persist();
  }

  void _toggleTask(String taskId) {
    final index = _tasks.indexWhere((task) => task.id == taskId);
    if (index == -1) return;
    setState(() {
      _tasks[index] = _tasks[index].copyWith(
        isCompleted: !_tasks[index].isCompleted,
      );
    });
    _persist();
  }

  void _deleteTask(String taskId) {
    setState(() {
      _tasks.removeWhere((task) => task.id == taskId);
      _remindedTaskIds.remove(taskId);
    });
    _persist();
  }

  void _addNote(String note) {
    setState(() {
      _notes.insert(0, note);
    });
    _persist();
  }

  void _deleteNote(int index) {
    if (index < 0 || index >= _notes.length) return;
    setState(() {
      _notes.removeAt(index);
    });
    _persist();
  }

  String get _currentQuote =>
      motivationalQuotes[_quoteIndex % motivationalQuotes.length];

  void _nextQuote() {
    setState(() {
      _quoteIndex = (_quoteIndex + 1) % motivationalQuotes.length;
    });
    _persist();
  }

  void _toggleFavoriteQuote(String quote) {
    setState(() {
      if (_favoriteQuotes.contains(quote)) {
        _favoriteQuotes.remove(quote);
      } else {
        _favoriteQuotes.add(quote);
      }
    });
    _persist();
  }

  void _checkReminders() {
    if (!mounted) return;
    final now = DateTime.now();
    for (final task in _tasks) {
      if (task.isCompleted || task.reminderAt == null) continue;
      if (_remindedTaskIds.contains(task.id)) continue;
      if (task.reminderAt!.isAfter(now)) continue;

      _remindedTaskIds.add(task.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Reminder: ${task.title}')));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = <Widget>[
      HomeDashboardScreen(
        tasks: _tasks,
        completedTasks: _completedTasks,
        currentQuote: _currentQuote,
        favoriteQuotes: _favoriteQuotes,
        onToggleDarkMode: widget.onToggleDarkMode,
        isDarkMode: widget.isDarkMode,
      ),
      TasksScreen(
        tasks: _tasks,
        onAddTask: _addTask,
        onUpdateTask: _updateTask,
        onToggleTask: _toggleTask,
        onDeleteTask: _deleteTask,
      ),
      NotesScreen(
        notes: _notes,
        onAddNote: _addNote,
        onDeleteNote: _deleteNote,
      ),
      QuotesScreen(
        currentQuote: _currentQuote,
        favoriteQuotes: _favoriteQuotes,
        onNextQuote: _nextQuote,
        onToggleFavoriteQuote: _toggleFavoriteQuote,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: _backgroundGradient(widget.isDarkMode),
      ),
      child: Scaffold(
        extendBody: true,
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(
            key: ValueKey<int>(_selectedIndex),
            child: screens[_selectedIndex],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_outlined),
                  selectedIcon: Icon(Icons.checklist),
                  label: 'Tasks',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Notes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.format_quote_outlined),
                  selectedIcon: Icon(Icons.format_quote),
                  label: 'Quotes',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({
    super.key,
    required this.tasks,
    required this.completedTasks,
    required this.currentQuote,
    required this.favoriteQuotes,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final List<DashboardTask> tasks;
  final int completedTasks;
  final String currentQuote;
  final List<String> favoriteQuotes;
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  late DateTime _now;
  Timer? _clockTimer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.tasks.where((task) => !task.isCompleted).toList();
    final progress = widget.tasks.isEmpty
        ? 0.0
        : widget.completedTasks / widget.tasks.length;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 98),
        children: [
          _TopHeaderBar(
            date: _now,
            isDarkMode: widget.isDarkMode,
            onToggleDarkMode: widget.onToggleDarkMode,
          ),
          const SizedBox(height: 16),
          Text('My Task', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TaskFeatureCard(
                  title: 'Sketch',
                  subtitle: '${pending.length} Pending',
                  icon: Icons.draw_outlined,
                  colors: const [Color(0xFFFF7D46), Color(0xFFFF6A52)],
                  isDarkMode: widget.isDarkMode,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TaskFeatureCard(
                  title: 'UI/UX',
                  subtitle: '${widget.completedTasks} Done',
                  icon: Icons.wb_sunny_outlined,
                  colors: const [Color(0xFF7A6EF8), Color(0xFF6D63EC)],
                  isDarkMode: widget.isDarkMode,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SectionHeader(
            title: 'Pending',
            actionLabel: '${pending.length} tasks',
          ),
          const SizedBox(height: 10),
          if (pending.isEmpty)
            _SoftListCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Nothing pending right now. Add a new task in the Tasks tab.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            )
          else
            ...pending.take(3).toList().asMap().entries.map((entry) {
              final index = entry.key;
              final task = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PendingTaskCard(
                  task: task,
                  index: index,
                  progressLabel: task.reminderAt == null
                      ? 'No reminder'
                      : formatDateTime(task.reminderAt!).split('•').last.trim(),
                ),
              );
            }),
          const SizedBox(height: 8),
          _SoftListCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Quote of the Day',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.currentQuote,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      minHeight: 7,
                      value: progress,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({
    super.key,
    required this.tasks,
    required this.onAddTask,
    required this.onUpdateTask,
    required this.onToggleTask,
    required this.onDeleteTask,
  });

  final List<DashboardTask> tasks;
  final void Function(String title, {DateTime? reminderAt}) onAddTask;
  final void Function(String taskId, String title, DateTime? reminderAt)
  onUpdateTask;
  final void Function(String taskId) onToggleTask;
  final void Function(String taskId) onDeleteTask;

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  int _selectedDay = 2;

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(
      5,
      (index) => DateTime.now().add(Duration(days: index - 2)),
    );
    final sortedTasks = [...widget.tasks]
      ..sort((a, b) {
        final aTime = a.reminderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.reminderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aTime.compareTo(bTime);
      });
    final completed = widget.tasks.where((task) => task.isCompleted).length;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.chevron_left),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Schedule',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      _showTaskEditor(context, onSave: widget.onAddTask),
                  icon: const Icon(Icons.add),
                  label: const Text('Task'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${_monthShort(days[_selectedDay])} ${days[_selectedDay].day}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 86,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final day = days[index];
                return _DayPill(
                  dayNumber: day.day,
                  dayName: _dayShort(day),
                  selected: _selectedDay == index,
                  onTap: () {
                    setState(() {
                      _selectedDay = index;
                    });
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SoftListCard(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$completed/${widget.tasks.length} completed',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      widget.tasks.isEmpty
                          ? '0%'
                          : '${((completed / widget.tasks.length) * 100).round()}%',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: sortedTasks.isEmpty
                ? const Center(
                    child: Text(
                      'No tasks yet. Tap Task to add your first one.',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: sortedTasks.length,
                    itemBuilder: (context, index) {
                      final task = sortedTasks[index];
                      final selected =
                          index == _selectedDay % sortedTasks.length;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ScheduleTaskTile(
                          task: task,
                          selected: selected,
                          onToggle: () => widget.onToggleTask(task.id),
                          onEdit: () => _showTaskEditor(
                            context,
                            initialTitle: task.title,
                            initialReminder: task.reminderAt,
                            onSave: (title, {DateTime? reminderAt}) {
                              widget.onUpdateTask(task.id, title, reminderAt);
                            },
                          ),
                          onDelete: () => widget.onDeleteTask(task.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showTaskEditor(
    BuildContext context, {
    String initialTitle = '',
    DateTime? initialReminder,
    required void Function(String title, {DateTime? reminderAt}) onSave,
  }) async {
    var title = initialTitle;
    DateTime? reminder = initialReminder;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    initialValue: initialTitle,
                    onChanged: (value) {
                      title = value;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Task title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                        initialDate: reminder ?? DateTime.now(),
                      );
                      if (!context.mounted || date == null) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: reminder == null
                            ? TimeOfDay.now()
                            : TimeOfDay.fromDateTime(reminder!),
                      );
                      if (!context.mounted || time == null) return;
                      setModalState(() {
                        reminder = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    },
                    icon: const Icon(Icons.notifications_active_outlined),
                    label: Text(
                      reminder == null
                          ? 'Set reminder'
                          : 'Reminder: ${formatDateTime(reminder!)}',
                    ),
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    onPressed: () {
                      final trimmedTitle = title.trim();
                      if (trimmedTitle.isEmpty) return;
                      onSave(trimmedTitle, reminderAt: reminder);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Save Task'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class NotesScreen extends StatelessWidget {
  const NotesScreen({
    super.key,
    required this.notes,
    required this.onAddNote,
    required this.onDeleteNote,
  });

  final List<String> notes;
  final void Function(String note) onAddNote;
  final void Function(int index) onDeleteNote;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Notes / Journal',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _showNoteDialog(context),
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Write'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SoftListCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                'Capture ideas, lessons, and random sparks while they are still fresh.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (notes.isEmpty)
            const _SoftListCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No notes yet. Save your first thought.'),
              ),
            )
          else
            ...notes.asMap().entries.map((entry) {
              final index = entry.key;
              final note = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftListCard(
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.sticky_note_2_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(note),
                    subtitle: Text('Entry #${index + 1}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDeleteNote(index),
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showNoteDialog(BuildContext context) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New note'),
          content: TextField(
            controller: controller,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Write your thoughts...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) return;
                onAddNote(text);
                Navigator.of(context).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();
  }
}

class QuotesScreen extends StatelessWidget {
  const QuotesScreen({
    super.key,
    required this.currentQuote,
    required this.favoriteQuotes,
    required this.onNextQuote,
    required this.onToggleFavoriteQuote,
  });

  final String currentQuote;
  final List<String> favoriteQuotes;
  final VoidCallback onNextQuote;
  final void Function(String quote) onToggleFavoriteQuote;

  @override
  Widget build(BuildContext context) {
    final isFavorite = favoriteQuotes.contains(currentQuote);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Quotes',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton.filledTonal(
                onPressed: onNextQuote,
                icon: const Icon(Icons.shuffle),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SoftListCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentQuote,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: onNextQuote,
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('Inspire Me'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () => onToggleFavoriteQuote(currentQuote),
                        icon: Icon(
                          isFavorite ? Icons.favorite : Icons.favorite_border,
                        ),
                        label: Text(isFavorite ? 'Saved' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SectionHeader(
            title: 'Favorite Quotes',
            actionLabel: '${favoriteQuotes.length} saved',
          ),
          const SizedBox(height: 8),
          if (favoriteQuotes.isEmpty)
            const _SoftListCard(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No favorite quotes yet.'),
              ),
            )
          else
            ...favoriteQuotes.map(
              (quote) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SoftListCard(
                  child: ListTile(
                    leading: const Icon(Icons.favorite, color: Colors.pink),
                    title: Text(quote),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopHeaderBar extends StatelessWidget {
  const _TopHeaderBar({
    required this.date,
    required this.isDarkMode,
    required this.onToggleDarkMode,
  });

  final DateTime date;
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.grid_view_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${_monthShort(date)} ${date.day}, ${date.year}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        IconButton.filledTonal(
          onPressed: onToggleDarkMode,
          icon: Icon(
            isDarkMode ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
          ),
        ),
      ],
    );
  }
}

class _TaskFeatureCard extends StatelessWidget {
  const _TaskFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.isDarkMode,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDarkMode
              ? [
                  colors.first.withValues(alpha: 0.6),
                  colors.last.withValues(alpha: 0.58),
                ]
              : colors,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.88),
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: Color(0xFF5C5E72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingTaskCard extends StatelessWidget {
  const _PendingTaskCard({
    required this.task,
    required this.index,
    required this.progressLabel,
  });

  final DashboardTask task;
  final int index;
  final String progressLabel;

  @override
  Widget build(BuildContext context) {
    const iconColors = [
      Color(0xFF7D67FF),
      Color(0xFFFF824D),
      Color(0xFF24B8B0),
    ];
    final color = iconColors[index % iconColors.length];

    return _SoftListCard(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.task_alt, color: color),
        ),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(child: Text(progressLabel)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Running',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTaskTile extends StatelessWidget {
  const _ScheduleTaskTile({
    required this.task,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final DashboardTask task;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tile = selected
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF7D46), Color(0xFFFF6A52)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x55FF7D46),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: _ScheduleTileContent(
              task: task,
              selected: true,
              onToggle: onToggle,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          )
        : _SoftListCard(
            child: _ScheduleTileContent(
              task: task,
              selected: false,
              onToggle: onToggle,
              onEdit: onEdit,
              onDelete: onDelete,
            ),
          );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 64,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              _taskTimeLabel(task),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(child: tile),
      ],
    );
  }
}

class _ScheduleTileContent extends StatelessWidget {
  const _ScheduleTileContent({
    required this.task,
    required this.selected,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final DashboardTask task;
  final bool selected;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    final subColor = selected
        ? Colors.white.withValues(alpha: 0.9)
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      onTap: onToggle,
      leading: Checkbox(
        value: task.isCompleted,
        onChanged: (_) => onToggle(),
        side: BorderSide(
          color: selected
              ? Colors.white
              : Theme.of(context).colorScheme.outline,
        ),
      ),
      title: Text(
        task.title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: textColor,
          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        task.reminderAt == null
            ? 'Any time today'
            : formatDateTime(task.reminderAt!).split('•').last.trim(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: subColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_outlined, color: textColor),
          ),
          IconButton(
            onPressed: onDelete,
            icon: Icon(Icons.delete_outline, color: textColor),
          ),
        ],
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({
    required this.dayNumber,
    required this.dayName,
    required this.selected,
    required this.onTap,
  });

  final int dayNumber;
  final String dayName;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF7A6EF8), Color(0xFF6D63EC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              : null,
          color: selected
              ? null
              : Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x447A6EF8),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$dayNumber',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              dayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: selected
                    ? Colors.white.withValues(alpha: 0.88)
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel});

  final String title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(
          actionLabel,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _SoftListCard extends StatelessWidget {
  const _SoftListCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF20283F).withValues(alpha: 0.86),
                  const Color(0xFF161D31).withValues(alpha: 0.92),
                ]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  const Color(0xFFFDFBFF).withValues(alpha: 0.96),
                ],
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.84),
        ),
      ),
      child: child,
    );
  }
}

String _dayShort(DateTime dateTime) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return days[dateTime.weekday - 1];
}

String _monthShort(DateTime dateTime) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[dateTime.month - 1];
}

String _taskTimeLabel(DashboardTask task) {
  final dateTime = task.reminderAt;
  if (dateTime == null) return 'Any';
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour $period';
}

class DashboardTask {
  DashboardTask({
    required this.id,
    required this.title,
    required this.isCompleted,
    this.reminderAt,
  });

  final String id;
  final String title;
  final bool isCompleted;
  final DateTime? reminderAt;

  DashboardTask copyWith({
    String? id,
    String? title,
    bool? isCompleted,
    Object? reminderAt = _noReminderValue,
  }) {
    return DashboardTask(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      reminderAt: reminderAt == _noReminderValue
          ? this.reminderAt
          : reminderAt as DateTime?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted,
      'reminderAt': reminderAt?.toIso8601String(),
    };
  }

  factory DashboardTask.fromJson(Map<String, dynamic> json) {
    return DashboardTask(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      isCompleted: json['isCompleted'] == true,
      reminderAt: json['reminderAt'] == null
          ? null
          : DateTime.tryParse(json['reminderAt'].toString()),
    );
  }
}

const Object _noReminderValue = Object();

class AppSnapshot {
  const AppSnapshot({
    required this.tasks,
    required this.notes,
    required this.favoriteQuotes,
    required this.quoteIndex,
  });

  final List<DashboardTask> tasks;
  final List<String> notes;
  final List<String> favoriteQuotes;
  final int quoteIndex;
}

class DataStore {
  static const String _tasksKey = 'dashboard_tasks';
  static const String _notesKey = 'dashboard_notes';
  static const String _favoritesKey = 'dashboard_favorite_quotes';
  static const String _quoteIndexKey = 'dashboard_quote_index';

  Future<AppSnapshot> load() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksJson = prefs.getString(_tasksKey);
    final notes = prefs.getStringList(_notesKey) ?? <String>[];
    final favorites = prefs.getStringList(_favoritesKey) ?? <String>[];
    final quoteIndex = prefs.getInt(_quoteIndexKey) ?? 0;

    final tasks = <DashboardTask>[];
    if (tasksJson != null && tasksJson.isNotEmpty) {
      final decoded = jsonDecode(tasksJson);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            tasks.add(DashboardTask.fromJson(item.cast<String, dynamic>()));
          }
        }
      }
    }

    return AppSnapshot(
      tasks: tasks,
      notes: notes,
      favoriteQuotes: favorites,
      quoteIndex: quoteIndex,
    );
  }

  Future<void> save({
    required List<DashboardTask> tasks,
    required List<String> notes,
    required List<String> favoriteQuotes,
    required int quoteIndex,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _tasksKey,
      jsonEncode(tasks.map((task) => task.toJson()).toList()),
    );
    await prefs.setStringList(_notesKey, notes);
    await prefs.setStringList(_favoritesKey, favoriteQuotes);
    await prefs.setInt(_quoteIndexKey, quoteIndex);
  }
}

String formatDateTime(DateTime dateTime) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final weekday = weekdays[dateTime.weekday - 1];
  final month = months[dateTime.month - 1];
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$weekday, ${dateTime.day} $month ${dateTime.year} • $hour:$minute $period';
}

const List<String> motivationalQuotes = [
  'Small steps every day lead to big changes.',
  'Discipline beats motivation when motivation fades.',
  'Progress, not perfection.',
  'Your future is built by what you do today.',
  'You can do hard things.',
  'Consistency is your superpower.',
  'Stay focused and never stop learning.',
];
