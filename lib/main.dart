import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:time_scheduler_table/time_scheduler_table.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'ru';
  await initializeDateFormatting('ru');
  runApp(const ScheduleApp());
}

enum SearchTarget {
  group('group', 'Группы', Icons.groups_rounded),
  person('person', 'Преподаватели', Icons.school_rounded);

  const SearchTarget(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;
}

enum ScheduleView { list, table }

const Color _appBackground = Color(0xFFF4F7FC);
const Color _softSurface = Color(0xFFFFFFFF);
const Color _softBorder = Color(0xFFE5EAF3);
const Color _accent = Color(0xFF4A9CF6);
const Color _mutedText = Color(0xFF8E96A3);

class ScheduleApp extends StatelessWidget {
  const ScheduleApp({super.key});

  static final GoRouter _router = GoRouter(
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (BuildContext context, GoRouterState state) =>
            const SearchPage(),
        routes: <RouteBase>[
          GoRoute(
            path: 'schedule/:target/:id',
            builder: (BuildContext context, GoRouterState state) {
              final target = SearchTarget.values.firstWhere(
                (SearchTarget value) =>
                    value.apiValue == state.pathParameters['target'],
                orElse: () => SearchTarget.group,
              );
              return SchedulePage(
                id: state.pathParameters['id'] ?? '',
                target: target,
                title: state.queryParameters['title'] ?? 'Расписание',
                description: state.queryParameters['description'] ?? '',
              );
            },
          ),
        ],
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Расписание ФА',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const <Locale>[
        Locale('ru'),
        Locale('en'),
      ],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        scaffoldBackgroundColor: _appBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.light,
          surface: _softSurface,
          surfaceContainerHighest: const Color(0xFFF0F4FA),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: _appBackground,
          elevation: 0,
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            side: BorderSide(color: _softBorder),
          ),
          color: _softSurface,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: _softSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _softBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _softBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: _accent, width: 1.4),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final RuzApi _api = RuzApi();
  final TextEditingController _queryController = TextEditingController();

  SearchTarget _target = SearchTarget.group;
  Timer? _debounceTimer;
  List<SearchEntry> _results = <SearchEntry>[];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    setState(() {});
    _scheduleSearch();
  }

  void _scheduleSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 450), _search);
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 3) {
      setState(() {
        _results = <SearchEntry>[];
        _error = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await _api.search(target: _target, term: query);
      if (!mounted) {
        return;
      }
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _results = <SearchEntry>[];
        _error = readableError(error);
        _isLoading = false;
      });
    }
  }

  void _changeTarget(Set<SearchTarget> selected) {
    final nextTarget = selected.first;
    if (nextTarget == _target) {
      return;
    }
    setState(() {
      _target = nextTarget;
      _results = <SearchEntry>[];
      _error = null;
    });
    _scheduleSearch();
  }

  void _openSchedule(SearchEntry entry, {SearchTarget? target}) {
    final selectedTarget = target ?? _target;
    context.go(
      Uri(
        path: '/schedule/${selectedTarget.apiValue}/${entry.id}',
        queryParameters: <String, String>{
          'title': entry.label,
          if (entry.description.isNotEmpty) 'description': entry.description,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PageFrame(
        maxWidth: 640,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const SizedBox(height: 18),
            Text(
              'Расписание ФА',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Найдите группу или преподавателя и откройте неделю занятий.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black.withValues(alpha: 0.62),
                  ),
            ),
            const SizedBox(height: 24),
            SegmentedButton<SearchTarget>(
              segments: SearchTarget.values
                  .map(
                    (SearchTarget target) => ButtonSegment<SearchTarget>(
                      value: target,
                      icon: Icon(target.icon),
                      label: Text(target.label),
                    ),
                  )
                  .toList(),
              selected: <SearchTarget>{_target},
              onSelectionChanged: _changeTarget,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _queryController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _queryController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Очистить',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _queryController.clear,
                      ),
                labelText: _target == SearchTarget.group
                    ? 'Название группы'
                    : 'Фамилия преподавателя',
                hintText: _target == SearchTarget.group ? 'ПИ22-3' : 'Андропов',
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _isLoading
                  ? const LinearProgressIndicator()
                  : const SizedBox(height: 4),
            ),
            Expanded(
              child: _SearchResults(
                error: _error,
                query: _queryController.text.trim(),
                results: _results,
                target: _target,
                onRetry: _search,
                onOpenSchedule: _openSchedule,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.error,
    required this.query,
    required this.results,
    required this.target,
    required this.onRetry,
    required this.onOpenSchedule,
  });

  final String? error;
  final String query;
  final List<SearchEntry> results;
  final SearchTarget target;
  final VoidCallback onRetry;
  final ValueChanged<SearchEntry> onOpenSchedule;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return _MessageState(
        icon: Icons.cloud_off_rounded,
        title: 'Не удалось загрузить данные',
        text: error!,
        action: FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Повторить'),
        ),
      );
    }

    if (query.length < 3) {
      return const _EmptySearchState(
        icon: Icons.search_rounded,
        text: 'Пока ничего не найдено',
      );
    }

    if (results.isEmpty) {
      return const _EmptySearchState(
        icon: Icons.search_off_rounded,
        text: 'Пока ничего не найдено',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
      itemCount: results.length,
      itemBuilder: (BuildContext context, int index) {
        final entry = results[index];
        return _SearchResultTile(
          entry: entry,
          target: target,
          onTap: () => onOpenSchedule(entry),
        );
      },
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 72),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 42,
              color: _accent.withValues(alpha: 0.78),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({
    required this.entry,
    required this.target,
    required this.onTap,
  });

  final SearchEntry entry;
  final SearchTarget target;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _softSurface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: _softBorder),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFFD8E8FF),
                    foregroundColor: const Color(0xFF17202A),
                    child: Icon(target.icon, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          entry.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (entry.description.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            entry.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: _mutedText,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF3C4450),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.child,
    required this.maxWidth,
    this.topPadding = 18,
  });

  final Widget child;
  final double maxWidth;
  final double topPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: EdgeInsets.fromLTRB(18, topPadding, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({
    super.key,
    required this.id,
    required this.target,
    required this.title,
    required this.description,
  });

  final String id;
  final SearchTarget target;
  final String title;
  final String description;

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final RuzApi _api = RuzApi();

  late DateTime _weekStart;
  ScheduleView _view = ScheduleView.list;
  List<Lesson> _lessons = <Lesson>[];
  bool _isLoading = true;
  String? _error;
  String? _emptyNote;

  @override
  void initState() {
    super.initState();
    _weekStart = startOfWeek(DateTime.now());
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _emptyNote = null;
    });

    try {
      final lessons = await _api.schedule(
        target: widget.target,
        id: widget.id,
        start: _weekStart,
        finish: _weekStart.add(const Duration(days: 6)),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = <Lesson>[];
        _error = readableError(error);
        _isLoading = false;
      });
    }
  }

  void _moveWeek(int offset) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * offset));
    });
    _loadSchedule();
  }

  Future<void> _pickWeek() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2023),
      lastDate: DateTime(2028),
      locale: const Locale('ru'),
      helpText: 'Выберите дату недели',
      cancelText: 'Отмена',
      confirmText: 'Готово',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _weekStart = startOfWeek(picked);
    });
    _loadSchedule();
  }

  Future<void> _findNearestWeek() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _emptyNote = null;
    });

    const offsets = <int>[
      0,
      -1,
      1,
      -2,
      2,
      -3,
      3,
      -4,
      4,
      -5,
      5,
      -6,
      6,
      -7,
      7,
      -8,
      8
    ];
    try {
      for (final offset in offsets) {
        final candidateStart = _weekStart.add(Duration(days: offset * 7));
        final lessons = await _api.schedule(
          target: widget.target,
          id: widget.id,
          start: candidateStart,
          finish: candidateStart.add(const Duration(days: 6)),
        );
        if (!mounted) {
          return;
        }
        if (lessons.isNotEmpty) {
          setState(() {
            _weekStart = candidateStart;
            _lessons = lessons;
            _isLoading = false;
          });
          return;
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _lessons = <Lesson>[];
        _emptyNote = 'За ближайшие недели занятия не найдены.';
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = readableError(error);
        _isLoading = false;
      });
    }
  }

  void _selectView(Set<ScheduleView> selected) {
    setState(() {
      _view = selected.first;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final rangeText =
        '${DateFormat('d MMMM', 'ru').format(_weekStart)} - ${DateFormat('d MMMM', 'ru').format(weekEnd)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Расписание'),
      ),
      body: _PageFrame(
        maxWidth: _view == ScheduleView.table ? 1180 : 980,
        topPadding: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _ScheduleHeader(
              title: widget.title,
              description: widget.description,
              target: widget.target,
              lessonsCount: _lessons.length,
              rangeText: rangeText,
            ),
            const SizedBox(height: 14),
            _ScheduleToolbar(
              isLoading: _isLoading,
              rangeText: rangeText,
              view: _view,
              onMoveWeek: _moveWeek,
              onPickWeek: _pickWeek,
              onSelectView: _selectView,
            ),
            const SizedBox(height: 10),
            if (_isLoading) const LinearProgressIndicator(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Expanded(
                child: _MessageState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Расписание не загрузилось',
                  text: _error!,
                  action: FilledButton.icon(
                    onPressed: _loadSchedule,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Повторить'),
                  ),
                ),
              )
            else if (_lessons.isEmpty)
              Expanded(
                child: _MessageState(
                  icon: Icons.event_busy_rounded,
                  title: 'На этой неделе занятий нет',
                  text: _emptyNote ??
                      'Можно выбрать другую дату или найти ближайшую неделю с занятиями.',
                  action: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _findNearestWeek,
                        icon: const Icon(Icons.travel_explore_rounded),
                        label: const Text('Найти ближайшие'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickWeek,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: const Text('Выбрать дату'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_view == ScheduleView.list)
              Expanded(child: _LessonList(lessons: _lessons))
            else
              _ScheduleTable(lessons: _lessons),
          ],
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.title,
    required this.description,
    required this.target,
    required this.lessonsCount,
    required this.rangeText,
  });

  final String title;
  final String description;
  final SearchTarget target;
  final int lessonsCount;
  final String rangeText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _softSurface,
        border: Border.all(color: _softBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            CircleAvatar(
              radius: 24,
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(target.icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      target == SearchTarget.group ? 'Группа' : 'Преподаватель',
                      rangeText,
                      if (description.isNotEmpty) description,
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.62),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _CounterPill(count: lessonsCount),
          ],
        ),
      ),
    );
  }
}

class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          '$count ${lessonCountWord(count)}',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

class _ScheduleToolbar extends StatelessWidget {
  const _ScheduleToolbar({
    required this.isLoading,
    required this.rangeText,
    required this.view,
    required this.onMoveWeek,
    required this.onPickWeek,
    required this.onSelectView,
  });

  final bool isLoading;
  final String rangeText;
  final ScheduleView view;
  final ValueChanged<int> onMoveWeek;
  final VoidCallback onPickWeek;
  final ValueChanged<Set<ScheduleView>> onSelectView;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 12,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: _softSurface,
            border: Border.all(color: _softBorder),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                IconButton(
                  tooltip: 'Предыдущая неделя',
                  onPressed: isLoading ? null : () => onMoveWeek(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                TextButton.icon(
                  onPressed: isLoading ? null : onPickWeek,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(rangeText),
                ),
                IconButton(
                  tooltip: 'Следующая неделя',
                  onPressed: isLoading ? null : () => onMoveWeek(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
        ),
        SegmentedButton<ScheduleView>(
          segments: const <ButtonSegment<ScheduleView>>[
            ButtonSegment<ScheduleView>(
              value: ScheduleView.list,
              icon: Icon(Icons.view_agenda_rounded),
              label: Text('Список'),
            ),
            ButtonSegment<ScheduleView>(
              value: ScheduleView.table,
              icon: Icon(Icons.calendar_view_week_rounded),
              label: Text('Таблица'),
            ),
          ],
          selected: <ScheduleView>{view},
          onSelectionChanged: onSelectView,
        ),
      ],
    );
  }
}

class _LessonList extends StatelessWidget {
  const _LessonList({required this.lessons});

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    final grouped = <DateTime, List<Lesson>>{};
    for (final lesson in lessons) {
      final date =
          DateTime(lesson.date.year, lesson.date.month, lesson.date.day);
      grouped.putIfAbsent(date, () => <Lesson>[]).add(lesson);
    }

    final days = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final children = <Widget>[];

    for (final day in days) {
      final dayLessons = day.value;
      children.add(_DayHeader(date: day.key, isFirst: children.isEmpty));
      for (int index = 0; index < dayLessons.length; index++) {
        children.add(
          _LessonTimelineItem(
            lesson: dayLessons[index],
            isFirst: index == 0,
            isLast: index == dayLessons.length - 1,
            isFeatured: false,
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 22),
      children: children,
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date, required this.isFirst});

  final DateTime date;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final dayName = capitalizeFirst(DateFormat('EEEE', 'ru').format(date));
    final dateText = DateFormat('d MMMM', 'ru').format(date);

    return Padding(
      padding: EdgeInsets.fromLTRB(122, isFirst ? 6 : 24, 0, 8),
      child: Row(
        children: <Widget>[
          Text(
            dayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF20242A),
                ),
          ),
          const SizedBox(width: 10),
          Text(
            dateText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _LessonTimelineItem extends StatelessWidget {
  const _LessonTimelineItem({
    required this.lesson,
    required this.isFirst,
    required this.isLast,
    required this.isFeatured,
  });

  final Lesson lesson;
  final bool isFirst;
  final bool isLast;
  final bool isFeatured;

  @override
  Widget build(BuildContext context) {
    final eventColor = isFeatured ? _accent : const Color(0xFFF7F9FD);
    final textColor = isFeatured ? Colors.white : const Color(0xFF20242A);
    final secondaryText =
        isFeatured ? Colors.white.withValues(alpha: 0.82) : _mutedText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 70,
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Text(
                  lesson.beginLesson,
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isFeatured ? _accent : _mutedText,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            _TimelineMarker(
              isFirst: isFirst,
              isLast: isLast,
              active: isFeatured,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: eventColor,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isFeatured
                      ? <BoxShadow>[
                          BoxShadow(
                            color: _accent.withValues(alpha: 0.22),
                            blurRadius: 20,
                            offset: const Offset(0, 12),
                          ),
                        ]
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              lesson.discipline,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            lesson.endLesson,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson.kindOfWork.isEmpty
                            ? DateFormat('EEEE, d MMMM', 'ru')
                                .format(lesson.date)
                            : lesson.kindOfWork,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: secondaryText,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: <Widget>[
                          if (lesson.auditoriumText.isNotEmpty)
                            _InfoChip(
                              icon: Icons.meeting_room_rounded,
                              text: lesson.auditoriumText,
                              inverted: isFeatured,
                            ),
                          if (lesson.group.isNotEmpty)
                            _InfoChip(
                              icon: Icons.groups_rounded,
                              text: lesson.group,
                              inverted: isFeatured,
                            ),
                          if (lesson.lecturer.isNotEmpty)
                            _InfoChip(
                              icon: Icons.school_rounded,
                              text: lesson.lecturer,
                              inverted: isFeatured,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineMarker extends StatelessWidget {
  const _TimelineMarker({
    required this.isFirst,
    required this.isLast,
    required this.active,
  });

  final bool isFirst;
  final bool isLast;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      child: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              width: 2,
              color: isFirst
                  ? Colors.transparent
                  : _accent.withValues(alpha: 0.55),
            ),
          ),
          Container(
            width: active ? 22 : 12,
            height: active ? 22 : 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? _appBackground : _softSurface,
              border: Border.all(
                color: _accent,
                width: active ? 4 : 2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: 2,
              color:
                  isLast ? Colors.transparent : _accent.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    this.inverted = false,
  });

  final IconData icon;
  final String text;
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: inverted
            ? Colors.white.withValues(alpha: 0.18)
            : const Color(0xFFEFF4FB),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon,
              size: 16,
              color: inverted ? Colors.white : _mutedText,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: inverted ? Colors.white : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({required this.lessons});

  static const List<String> _rowLabels = <String>[
    '08:30 - 10:00',
    '10:10 - 11:40',
    '11:50 - 13:20',
    '14:00 - 15:30',
    '15:40 - 17:10',
    '17:20 - 18:50',
    '18:55 - 20:25',
    '20:30 - 22:00',
  ];

  final List<Lesson> lessons;

  @override
  Widget build(BuildContext context) {
    return TimeSchedulerTable(
      eventList: lessons.map(_toEvent).toList(),
      cellHeight: 74,
      cellWidth: 132,
      currentColumnTitleIndex: DateTime.now().weekday - 1,
      columnLabels: const <String>['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'],
      rowLabels: _rowLabels,
      scrollColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
      scrollTrackingColor:
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
      eventAlert: EventAlert(
        addOnPressed: (_) {},
        deleteOnPressed: (_) {},
        updateOnPressed: (_) {},
      ),
    );
  }

  Event _toEvent(Lesson lesson) {
    final title = lesson.discipline.length > 34
        ? '${lesson.discipline.substring(0, 34)}...'
        : lesson.discipline;
    return Event(
      title: title,
      time: lesson.auditoriumText.isEmpty
          ? '${lesson.beginLesson} - ${lesson.endLesson}'
          : '${lesson.beginLesson} - ${lesson.endLesson}\n${lesson.auditoriumText}',
      color: colorForLesson(lesson),
      columnIndex: lesson.date.weekday - 1,
      rowIndex: rowIndexForTime(lesson.beginLesson),
    );
  }
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              if (action != null) ...<Widget>[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class RuzApi {
  RuzApi()
      : _dio = Dio(
          BaseOptions(
            baseUrl: const bool.fromEnvironment('USE_PROXY')
                ? 'http://localhost:3000'
                : 'https://ruz.fa.ru/api',
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
          ),
        );

  final Dio _dio;

  Future<List<SearchEntry>> search({
    required SearchTarget target,
    required String term,
  }) async {
    final response = await _dio.get<dynamic>(
      '/search',
      queryParameters: <String, String>{
        'type': target.apiValue,
        'term': term,
      },
    );

    final data = response.data;
    if (data is Map && data['message'] != null) {
      throw Exception(stringValue(data['message']));
    }
    if (data is! List) {
      return <SearchEntry>[];
    }

    final entries = data
        .whereType<Map>()
        .map(
            (Map item) => SearchEntry.fromJson(Map<String, dynamic>.from(item)))
        .where((SearchEntry entry) => entry.id.isNotEmpty)
        .toList();
    return refineSearchEntries(
      entries: entries,
      target: target,
      term: term,
    );
  }

  Future<List<Lesson>> schedule({
    required SearchTarget target,
    required String id,
    required DateTime start,
    required DateTime finish,
  }) async {
    final response = await _dio.get<dynamic>(
      '/schedule/${target.apiValue}/$id',
      queryParameters: <String, String>{
        'start': DateFormat('yyyy.MM.dd').format(start),
        'finish': DateFormat('yyyy.MM.dd').format(finish),
      },
    );

    final data = response.data;
    if (data is Map && data['message'] != null) {
      throw Exception(stringValue(data['message']));
    }
    if (data is! List) {
      return <Lesson>[];
    }

    final lessons = data
        .whereType<Map>()
        .map((Map item) => Lesson.fromJson(Map<String, dynamic>.from(item)))
        .toList()
      ..sort((Lesson a, Lesson b) {
        final dateCompare = a.date.compareTo(b.date);
        if (dateCompare != 0) {
          return dateCompare;
        }
        return a.beginLesson.compareTo(b.beginLesson);
      });
    return lessons;
  }
}

class SearchEntry {
  const SearchEntry({
    required this.id,
    required this.label,
    required this.description,
  });

  factory SearchEntry.fromJson(Map<String, dynamic> json) {
    return SearchEntry(
      id: stringValue(json['id']),
      label: stringValue(json['label']),
      description: stringValue(json['description']),
    );
  }

  final String id;
  final String label;
  final String description;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.discipline,
    required this.kindOfWork,
    required this.lecturer,
    required this.auditorium,
    required this.building,
    required this.group,
    required this.beginLesson,
    required this.endLesson,
    required this.date,
  });

  factory Lesson.fromJson(Map<String, dynamic> json) {
    return Lesson(
      id: stringValue(json['lessonOid'] ?? json['id']),
      discipline: stringValue(json['discipline'], fallback: 'Занятие'),
      kindOfWork: stringValue(json['kindOfWork']),
      lecturer: stringValue(json['lecturer']),
      auditorium: stringValue(json['auditorium']),
      building: stringValue(json['building']),
      group: stringValue(json['group']),
      beginLesson: stringValue(json['beginLesson']),
      endLesson: stringValue(json['endLesson']),
      date: parseRuzDate(stringValue(json['date'])),
    );
  }

  final String id;
  final String discipline;
  final String kindOfWork;
  final String lecturer;
  final String auditorium;
  final String building;
  final String group;
  final String beginLesson;
  final String endLesson;
  final DateTime date;

  String get auditoriumText {
    if (auditorium.isEmpty) {
      return building;
    }
    if (building.isEmpty) {
      return auditorium;
    }
    return '$auditorium, $building';
  }
}

String stringValue(Object? value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

List<SearchEntry> refineSearchEntries({
  required List<SearchEntry> entries,
  required SearchTarget target,
  required String term,
}) {
  final unique = uniqueSearchEntries(entries);
  if (target != SearchTarget.group) {
    return unique;
  }

  final query = normalizeSearchLabel(term);
  final hasExactMatch = unique
      .any((SearchEntry entry) => normalizeSearchLabel(entry.label) == query);
  if (!hasExactMatch) {
    return unique;
  }

  return unique.where((SearchEntry entry) {
    final label = normalizeSearchLabel(entry.label);
    if (label == query) {
      return true;
    }
    final parts = label
        .split(';')
        .map((String part) => normalizeSearchLabel(part))
        .where((String part) => part.isNotEmpty)
        .toSet();
    return !parts.contains(query);
  }).toList();
}

List<SearchEntry> uniqueSearchEntries(List<SearchEntry> entries) {
  final seen = <String>{};
  final unique = <SearchEntry>[];
  for (final entry in entries) {
    final key = normalizeSearchLabel(entry.label);
    if (key.isEmpty || seen.contains(key)) {
      continue;
    }
    seen.add(key);
    unique.add(entry);
  }
  return unique;
}

String normalizeSearchLabel(String value) {
  return value.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
}

String capitalizeFirst(String value) {
  if (value.isEmpty) {
    return value;
  }
  return '${value[0].toUpperCase()}${value.substring(1)}';
}

DateTime parseRuzDate(String value) {
  for (final pattern in <String>['yyyy.MM.dd', 'yyyy-MM-dd']) {
    try {
      return DateFormat(pattern).parseStrict(value);
    } catch (_) {
      // Try the next known RUZ date format.
    }
  }
  return DateTime.now();
}

DateTime startOfWeek(DateTime value) {
  final date = DateTime(value.year, value.month, value.day);
  return date.subtract(Duration(days: date.weekday - 1));
}

String lessonCountWord(int count) {
  final lastTwo = count % 100;
  if (lastTwo >= 11 && lastTwo <= 14) {
    return 'пар';
  }
  return switch (count % 10) {
    1 => 'пара',
    2 || 3 || 4 => 'пары',
    _ => 'пар',
  };
}

int rowIndexForTime(String time) {
  const starts = <String>[
    '08:30',
    '10:10',
    '11:50',
    '14:00',
    '15:40',
    '17:20',
    '18:55',
    '20:30',
  ];

  final exact = starts.indexOf(time);
  if (exact >= 0) {
    return exact;
  }

  final parsed = DateFormat('HH:mm').tryParse(time);
  if (parsed == null) {
    return 0;
  }

  final minutes = parsed.hour * 60 + parsed.minute;
  final distances = starts.map((String slot) {
    final slotTime = DateFormat('HH:mm').parse(slot);
    return (slotTime.hour * 60 + slotTime.minute - minutes).abs();
  }).toList();
  final minDistance = distances.reduce((int a, int b) => a < b ? a : b);
  return distances.indexOf(minDistance);
}

Color colorForLesson(Lesson lesson) {
  final source =
      lesson.kindOfWork.isEmpty ? lesson.discipline : lesson.kindOfWork;
  final hash = source.codeUnits.fold<int>(0, (int sum, int code) => sum + code);
  const colors = <Color>[
    Color(0xFF2E7D32),
    Color(0xFF1565C0),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFAD5B00),
  ];
  return colors[hash % colors.length];
}

String readableError(Object error) {
  if (error is DioException) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Сервер ruz.fa.ru долго не отвечает. Попробуйте повторить запрос.';
    }
    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'Сервер вернул ошибку $statusCode.';
    }
    return 'Нет соединения с ruz.fa.ru. Если запускаете в Chrome и API блокируется, включите локальный proxy из README.';
  }
  if (error is Exception) {
    return error.toString().replaceFirst('Exception: ', '');
  }
  return error.toString();
}
