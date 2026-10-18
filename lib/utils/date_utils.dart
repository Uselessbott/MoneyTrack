/// Adds [months] to [date], clamping to the last valid day of the target
/// month. e.g. Jan 31 + 1 month => Feb 28/29.
DateTime addMonths(DateTime date, int months) {
  final targetMonth = date.month + months;
  final year = date.year + ((targetMonth - 1) ~/ 12);
  final month = ((targetMonth - 1) % 12) + 1;

  final lastDay = DateTime(year, month + 1, 0).day;
  final day = date.day > lastDay ? lastDay : date.day;

  return DateTime(year, month, day);
}

DateTime dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);