import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../state/app_controller.dart';
import '../utils/format.dart';
import 'day_detail_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  AppController get controller => widget.controller;

  void _prevMonth() {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _visibleMonth =
          DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Today',
            onPressed: _goToToday,
            icon: const Icon(Icons.today_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final monthMap = _buildMonthMap(controller);

          return Column(
            children: [
              _MonthHeader(
                month: _visibleMonth,
                onPrev: _prevMonth,
                onNext: _nextMonth,
              ),
              const _WeekdayHeader(),
              _CalendarGrid(
                visibleMonth: _visibleMonth,
                selectedDate: _selectedDate,
                activityMap: monthMap,
                onDayTap: _onDayTap,
              ),
              const Divider(height: 1),
              Expanded(
                child: _SelectedDaySummary(
                  date: _selectedDate,
                  controller: controller,
                  onOpen: () => _openDayDetail(_selectedDate),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _onDayTap(DateTime day) {
    setState(() => _selectedDate = day);
  }

  Future<void> _openDayDetail(DateTime day) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDetailScreen(
          controller: controller,
          date: day,
        ),
      ),
    );
  }

  Map<int, _DayActivity> _buildMonthMap(AppController controller) {
    final map = <int, _DayActivity>{};

    bool sameMonth(DateTime d) =>
        d.year == _visibleMonth.year && d.month == _visibleMonth.month;

    void ensure(int day) {
      map[day] ??= const _DayActivity();
    }

    for (final e in controller.expenses) {
      if (!sameMonth(e.date)) continue;
      ensure(e.date.day);
      map[e.date.day] = map[e.date.day]!.copyWith(
        expenses: map[e.date.day]!.expenses + 1,
      );
    }

    for (final c in controller.credits) {
      if (!sameMonth(c.date)) continue;
      ensure(c.date.day);
      map[c.date.day] = map[c.date.day]!.copyWith(
        credits: map[c.date.day]!.credits + 1,
      );
    }

    for (final loan in controller.loans) {
      if (loan.paid) continue;
      for (int m = 1; m <= loan.tenureMonths; m++) {
        if (loan.isMonthPaid(m)) continue;
        final due = loan.dueDateForMonth(m);
        if (!sameMonth(due)) continue;
        ensure(due.day);
        map[due.day] = map[due.day]!.copyWith(
          loans: map[due.day]!.loans + 1,
        );
      }
    }

    return map;
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Text(
                DateFormat('MMMM yyyy').format(month),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final d in days)
            Expanded(
              child: Center(
                child: Text(
                  d,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.activityMap,
    required this.onDayTap,
  });

  final DateTime visibleMonth;
  final DateTime selectedDate;
  final Map<int, _DayActivity> activityMap;
  final void Function(DateTime) onDayTap;

  @override
  Widget build(BuildContext context) {
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth =
        DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;

    final leadingBlanks = firstOfMonth.weekday % 7;

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, d);
      final isSelected = _sameDay(date, selectedDate);
      final isToday = _sameDay(date, DateTime.now());
      final activity = activityMap[d];

      cells.add(
        _DayCell(
          day: d,
          isSelected: isSelected,
          isToday: isToday,
          activity: activity,
          onTap: () => onDayTap(date),
        ),
      );
    }

    while (cells.length % 7 != 0) {
      cells.add(const SizedBox.shrink());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: GridView.count(
        crossAxisCount: 7,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 0.85,
        children: cells,
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.isSelected,
    required this.isToday,
    required this.activity,
    required this.onTap,
  });

  final int day;
  final bool isSelected;
  final bool isToday;
  final _DayActivity? activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final bgColor = isSelected
        ? scheme.primary
        : isToday
        ? scheme.primaryContainer
        : null;

    final textColor = isSelected
        ? scheme.onPrimary
        : isToday
        ? scheme.onPrimaryContainer
        : null;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Material(
        color: bgColor ?? Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected || isToday
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 6,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildDots(activity),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildDots(_DayActivity? a) {
    final dots = <Widget>[];
    if ((a?.expenses ?? 0) > 0) dots.add(_dot(Colors.red));
    if ((a?.credits ?? 0) > 0) dots.add(_dot(Colors.green));
    if ((a?.loans ?? 0) > 0) dots.add(_dot(Colors.blue));

    final out = <Widget>[];
    for (int i = 0; i < dots.length; i++) {
      if (i > 0) out.add(const SizedBox(width: 3));
      out.add(dots[i]);
    }
    return out;
  }

  Widget _dot(Color color) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SelectedDaySummary extends StatelessWidget {
  const _SelectedDaySummary({
    required this.date,
    required this.controller,
    required this.onOpen,
  });

  final DateTime date;
  final AppController controller;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final expenses =
    controller.expenses.where((e) => _sameDay(e.date, date)).toList();
    final credits =
    controller.credits.where((c) => _sameDay(c.date, date)).toList();

    final loanDues = <({dynamic loan, int month})>[];
    for (final loan in controller.loans) {
      if (loan.paid) continue;
      for (int m = 1; m <= loan.tenureMonths; m++) {
        if (loan.isMonthPaid(m)) continue;
        final due = loan.dueDateForMonth(m);
        if (!_sameDay(due, date)) continue;
        loanDues.add((loan: loan, month: m));
      }
    }

    final totalExpenses = expenses.fold<double>(0, (s, e) => s + e.amount);
    final totalCredits = credits.fold<double>(0, (s, c) => s + c.amount);
    final net = totalExpenses - totalCredits;

    final empty =
        expenses.isEmpty && credits.isEmpty && loanDues.isEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMM yyyy').format(date),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onOpen,
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (empty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              child: Text(
                'Nothing recorded on this day.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Spent',
                    value: money(totalExpenses),
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Received',
                    value: money(totalCredits),
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MiniStat(
                    label: 'Net',
                    value: money(net),
                    color: net >= 0 ? Colors.red : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...expenses.map(
                  (e) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.arrow_upward, color: Colors.red),
                title: Text(e.title),
                subtitle: e.note.isEmpty ? null : Text(e.note),
                trailing: Text(
                  '-${money(e.amount)}',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ...credits.map(
                  (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading:
                const Icon(Icons.arrow_downward, color: Colors.green),
                title: Text(c.title),
                subtitle: c.note.isEmpty ? null : Text(c.note),
                trailing: Text(
                  '+${money(c.amount)}',
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            ...loanDues.map(
                  (due) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.event_available, color: Colors.blue),
                title: Text('${due.loan.title} — Month ${due.month}'),
                subtitle: const Text('Loan payment due'),
                trailing: Text(
                  money(due.loan.amountForMonth(due.month)),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayActivity {
  const _DayActivity({
    this.expenses = 0,
    this.credits = 0,
    this.loans = 0,
  });

  final int expenses;
  final int credits;
  final int loans;

  _DayActivity copyWith({int? expenses, int? credits, int? loans}) {
    return _DayActivity(
      expenses: expenses ?? this.expenses,
      credits: credits ?? this.credits,
      loans: loans ?? this.loans,
    );
  }
}