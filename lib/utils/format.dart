import 'package:intl/intl.dart';

import 'date_utils.dart';

final _dateFormat = DateFormat('dd MMM yyyy');
final _monthFormat = DateFormat('MMMM yyyy');
final _moneyFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹ ',
  decimalDigits: 2,
);
final _moneyCompactFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹ ',
  decimalDigits: 0,
);

String money(double amount) => _moneyFormat.format(amount);

/// Drops trailing `.00` for whole amounts.
String moneyShort(double amount) {
  if (amount == amount.roundToDouble()) {
    return _moneyCompactFormat.format(amount);
  }
  return _moneyFormat.format(amount);
}

String formatDate(DateTime date) => _dateFormat.format(date);

String formatMonth(DateTime date) => _monthFormat.format(date);

int daysUntil(DateTime date) {
  final today = dateOnly(DateTime.now());
  final target = dateOnly(date);
  return target.difference(today).inDays;
}

String dueLabel(DateTime date) {
  final days = daysUntil(date);

  if (days < 0) return '${-days} day${days == -1 ? '' : 's'} overdue';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}