import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/loan.dart';
import '../utils/date_utils.dart';

class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'loan_due_reminders';
  static const String _channelName = 'Loan Due Reminders';
  static const String _channelDescription =
      'Notifications for upcoming and overdue loans.';

  /// Days before the due date to send reminders.
  static const List<int> _daysBefore = [3, 1];

  /// Fire reminders at this hour (local time).
  static const int _hour = 9;

  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // INIT
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;

    tzdata.initializeTimeZones();

    tz.Location? resolved;
    for (final name in const ['Asia/Kolkata', 'Asia/Calcutta', 'UTC']) {
      try {
        resolved = tz.getLocation(name);
        break;
      } catch (e) {
        debugPrint('[notif] timezone "$name" unavailable: $e');
      }
    }
    if (resolved == null) {
      throw StateError('Could not resolve any timezone.');
    }
    tz.setLocalLocation(resolved);
    debugPrint('[notif] using timezone: ${resolved.name}');

    const androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // v18: positional.
    final ok = await _plugin.initialize(settings);
    debugPrint('[notif] initialize() -> $ok');

    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission();
    debugPrint('[notif] notifications permission: $granted');
    final exact = await android?.requestExactAlarmsPermission();
    debugPrint('[notif] exact alarm permission: $exact');
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        enableVibration: true,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );
  }

  // ---------------------------------------------------------------------------
  // SCHEDULE — only called when a loan is added or edited.
  // ---------------------------------------------------------------------------

  Future<void> scheduleLoan(Loan loan) async {
    if (loan.paid || loan.isFullyPaid) return;

    final details = _details();
    final now = DateTime.now();

    for (int month = 1; month <= loan.tenureMonths; month++) {
      if (loan.isMonthPaid(month)) continue;

      final amount = loan.amountForMonth(month);
      final due = addMonths(loan.startDate, month);

      for (final daysBefore in _daysBefore) {
        final target = due.subtract(Duration(days: daysBefore));
        if (target.isBefore(now)) continue;

        await _schedule(
          id: _id(loan.id, month, 100 + daysBefore),
          title: 'Loan payment in $daysBefore day(s)',
          body: '${loan.title} • Month $month • '
              '₹${_formatAmount(amount)} due on ${_formatDate(due)}.',
          date: target,
          details: details,
        );
      }

      if (!due.isBefore(now)) {
        await _schedule(
          id: _id(loan.id, month, 0),
          title: 'Loan payment due today',
          body: '${loan.title} • Month $month • '
              '₹${_formatAmount(amount)} is due today.',
          date: due,
          details: details,
        );
      }
    }
  }

  /// Schedules reminders for ONE month. Called when unmarking a paid month.
  Future<void> scheduleMonth(Loan loan, int month) async {
    if (loan.paid || loan.isMonthPaid(month)) return;

    final details = _details();
    final now = DateTime.now();
    final amount = loan.amountForMonth(month);
    final due = addMonths(loan.startDate, month);

    for (final daysBefore in _daysBefore) {
      final target = due.subtract(Duration(days: daysBefore));
      if (target.isBefore(now)) continue;

      await _schedule(
        id: _id(loan.id, month, 100 + daysBefore),
        title: 'Loan payment in $daysBefore day(s)',
        body: '${loan.title} • Month $month • '
            '₹${_formatAmount(amount)} due on ${_formatDate(due)}.',
        date: target,
        details: details,
      );
    }

    if (!due.isBefore(now)) {
      await _schedule(
        id: _id(loan.id, month, 0),
        title: 'Loan payment due today',
        body: '${loan.title} • Month $month • '
            '₹${_formatAmount(amount)} is due today.',
        date: due,
        details: details,
      );
    }
  }

  Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required NotificationDetails details,
  }) async {
    final scheduled = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      _hour,
      0,
    );
    final now = tz.TZDateTime.now(tz.local);
    if (!scheduled.isAfter(now)) return;

    try {
      // v18: first 5 positional, rest named.
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (e, st) {
      debugPrint('[notif] failed id=$id: $e\n$st');
    }
  }

  // ---------------------------------------------------------------------------
  // CANCEL
  // ---------------------------------------------------------------------------

  /// Cancels ALL reminders for a loan.
  Future<void> cancelLoan(int loanId, {required int tenure}) async {
    for (int month = 1; month <= tenure; month++) {
      await _cancelMonth(loanId, month);
    }
  }

  /// Cancels reminders for ONE month. Called when marking a month paid.
  Future<void> cancelMonth(int loanId, int month) async {
    await _cancelMonth(loanId, month);
  }

  Future<void> _cancelMonth(int loanId, int month) async {
    for (final daysBefore in _daysBefore) {
      // v18: positional.
      await _plugin.cancel(_id(loanId, month, 100 + daysBefore));
    }
    // Clean up IDs from older schemes, in case any are lingering.
    for (final stale in const [101, 102, 103, 104, 105]) {
      if (_daysBefore.contains(stale - 100)) continue;
      await _plugin.cancel(_id(loanId, month, stale));
    }
    await _plugin.cancel(_id(loanId, month, 0));
  }

  // ---------------------------------------------------------------------------
  // IDS
  // ---------------------------------------------------------------------------

  int _id(int loanId, int month, int stage) {
    return loanId * 100000 + month * 1000 + stage;
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }
}