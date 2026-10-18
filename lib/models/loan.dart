import '../utils/date_utils.dart';

class Loan {
  const Loan({
    required this.id,
    required this.title,
    required this.amount,
    required this.startDate,
    required this.dueDate,
    required this.tenureMonths,
    required this.monthlyAmount,
    required this.note,
    required this.paid,
    required this.paymentMode,
    required this.customMonthlyAmounts,
    this.paidMonths = const [],
    this.paidMonthExpenses = const {},
  });

  final int id;
  final String title;
  final double amount;
  final DateTime startDate;
  final DateTime dueDate;
  final int tenureMonths;

  /// For fixed loans this is the fixed monthly payment.
  /// For custom loans this is the average monthly payment.
  final double monthlyAmount;

  final String note;

  /// Whole-loan "archived" flag.
  final bool paid;

  /// Either "fixed" or "custom".
  final String paymentMode;

  /// One amount per installment (only meaningful in custom mode).
  final List<double> customMonthlyAmounts;

  /// Which months (1-based) are paid.
  final List<int> paidMonths;

  /// Month -> expense id (auto-created expense for a paid month).
  final Map<int, int> paidMonthExpenses;

  bool get isCustom => paymentMode == 'custom';

  bool isMonthPaid(int month) => paidMonths.contains(month);

  int? expenseIdForMonth(int month) => paidMonthExpenses[month];

  bool get isFullyPaid => paidMonths.length >= tenureMonths;

  int get paidCount =>
      paidMonths.where((m) => m >= 1 && m <= tenureMonths).length;

  int get unpaidCount => tenureMonths - paidCount;

  int? get nextUnpaidMonth {
    for (int m = 1; m <= tenureMonths; m++) {
      if (!paidMonths.contains(m)) return m;
    }
    return null;
  }

  bool isMonthOverdue(int month) {
    if (paidMonths.contains(month)) return false;
    final due = addMonths(startDate, month);
    return dateOnly(due).isBefore(dateOnly(DateTime.now()));
  }

  DateTime dueDateForMonth(int month) => addMonths(startDate, month);

  double get totalScheduledAmount {
    if (isCustom && customMonthlyAmounts.isNotEmpty) {
      return customMonthlyAmounts.fold<double>(0, (sum, a) => sum + a);
    }
    return monthlyAmount * tenureMonths;
  }

  double amountForMonth(int month) {
    if (month < 1 || month > tenureMonths) {
      return monthlyAmount;
    }
    if (isCustom && customMonthlyAmounts.length >= month) {
      return customMonthlyAmounts[month - 1];
    }
    return monthlyAmount;
  }

  factory Loan.fromMap(Map<String, dynamic> map) {
    final rawCustomAmounts =
        map['custom_monthly_amounts']?.toString() ?? '';
    final rawPaidMonths = map['paid_months']?.toString() ?? '';
    final rawPaidExpenses = map['paid_month_expenses']?.toString() ?? '';

    final customAmounts = rawCustomAmounts
        .split(',')
        .map((value) => double.tryParse(value.trim()))
        .whereType<double>()
        .toList();

    final paidMonths = rawPaidMonths
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();

    final paidExpenseMap = <int, int>{};
    for (final pair in rawPaidExpenses.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final m = int.tryParse(parts[0].trim());
      final e = int.tryParse(parts[1].trim());
      if (m != null && e != null) paidExpenseMap[m] = e;
    }

    return Loan(
      id: map['id'] as int,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      startDate: DateTime.parse(map['start_date'] as String),
      dueDate: DateTime.parse(map['due_date'] as String),
      tenureMonths: (map['tenure_months'] as num).toInt(),
      monthlyAmount: (map['monthly_amount'] as num).toDouble(),
      note: map['note']?.toString() ?? '',
      paid: (map['paid'] as num? ?? 0) == 1,
      paymentMode: map['payment_mode']?.toString() ?? 'fixed',
      customMonthlyAmounts: customAmounts,
      paidMonths: paidMonths,
      paidMonthExpenses: paidExpenseMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'tenure_months': tenureMonths,
      'monthly_amount': monthlyAmount,
      'note': note,
      'paid': paid ? 1 : 0,
      'payment_mode': paymentMode,
      'custom_monthly_amounts': customMonthlyAmounts.join(','),
      'paid_months': paidMonths.join(','),
      'paid_month_expenses': paidMonthExpenses.entries
          .map((e) => '${e.key}:${e.value}')
          .join(','),
    };
  }
}