import 'package:flutter/foundation.dart';

import '../data/database.dart';
import '../models/credit.dart';
import '../models/expense.dart';
import '../models/loan.dart';
import '../services/notification_service.dart';
import '../utils/date_utils.dart';

class AppController extends ChangeNotifier {
  AppController({
    required this.database,
    required this.notifications,
  });

  final AppDatabase database;
  final NotificationService notifications;

  List<Expense> expenses = [];
  List<Credit> credits = [];
  List<Loan> loans = [];

  bool loading = true;

  Future<void> initialize() async {
    // Just load the data. Notifications are already scheduled by the OS
    // from when the loans were created/edited. Nothing to do here.
    await reload();
  }

  Future<void> reload() async {
    loading = true;
    notifyListeners();

    expenses = await database.getExpenses();
    credits = await database.getCredits();
    loans = await database.getLoans();

    loading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // TOTALS
  // ---------------------------------------------------------------------------

  double get totalSpent =>
      expenses.fold<double>(0, (sum, e) => sum + e.amount);

  double get totalCredits =>
      credits.fold<double>(0, (sum, c) => sum + c.amount);

  double get netSpent => totalSpent - totalCredits;

  double get totalLoanAmount => loans
      .where((loan) => !loan.isFullyPaid)
      .fold<double>(0, (sum, loan) => sum + loan.amount);

  double get totalMonthlyDue => loans
      .where((loan) => !loan.isFullyPaid)
      .fold<double>(0, (sum, loan) => sum + loan.monthlyAmount);

  List<Loan> get unpaidLoans =>
      loans.where((loan) => !loan.isFullyPaid).toList();

  List<Loan> get overdueLoans {
    final today = dateOnly(DateTime.now());
    return unpaidLoans.where((loan) {
      final next = loan.nextUnpaidMonth;
      if (next == null) return false;
      return dateOnly(loan.dueDateForMonth(next)).isBefore(today);
    }).toList();
  }

  List<Loan> get upcomingLoans {
    final today = dateOnly(DateTime.now());
    return unpaidLoans.where((loan) {
      final next = loan.nextUnpaidMonth;
      if (next == null) return false;
      return !dateOnly(loan.dueDateForMonth(next)).isBefore(today);
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------------------------

  Future<void> addExpense({
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    await database.insertExpense(
      amount: amount,
      title: title,
      date: date,
      note: note,
    );
    await reload();
  }

  Future<void> updateExpense({
    required Expense expense,
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    await database.updateExpense(
      id: expense.id,
      amount: amount,
      title: title,
      date: date,
      note: note,
    );
    await reload();
  }

  Future<void> deleteExpense(Expense expense) async {
    await database.deleteExpense(expense.id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // CREDITS
  // ---------------------------------------------------------------------------

  Future<void> addCredit({
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    await database.insertCredit(
      amount: amount,
      title: title,
      date: date,
      note: note,
    );
    await reload();
  }

  Future<void> updateCredit({
    required Credit credit,
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    await database.updateCredit(
      id: credit.id,
      amount: amount,
      title: title,
      date: date,
      note: note,
    );
    await reload();
  }

  Future<void> deleteCredit(Credit credit) async {
    await database.deleteCredit(credit.id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // LOANS
  // ---------------------------------------------------------------------------

  Future<void> addLoan({
    required String title,
    required double amount,
    required DateTime startDate,
    required DateTime dueDate,
    required int tenureMonths,
    required double monthlyAmount,
    required String note,
    String paymentMode = 'fixed',
    List<double> customMonthlyAmounts = const [],
  }) async {
    final id = await database.insertLoan(
      title: title,
      amount: amount,
      startDate: startDate,
      dueDate: dueDate,
      tenureMonths: tenureMonths,
      monthlyAmount: monthlyAmount,
      note: note,
      paymentMode: paymentMode,
      customMonthlyAmounts: customMonthlyAmounts,
    );

    await reload();

    final loan = loans.firstWhere((item) => item.id == id);
    // Schedule reminders ONCE, here.
    await _safe(() => notifications.scheduleLoan(loan));
  }

  Future<void> updateLoan({
    required Loan loan,
    required String title,
    required double amount,
    required DateTime startDate,
    required DateTime dueDate,
    required int tenureMonths,
    required double monthlyAmount,
    required String note,
    String paymentMode = 'fixed',
    List<double> customMonthlyAmounts = const [],
  }) async {
    // Cancel existing, then reschedule. Only place we ever do this.
    await _safe(
          () => notifications.cancelLoan(
        loan.id,
        tenure: loan.tenureMonths,
      ),
    );

    final keptPaidMonths =
    loan.paidMonths.where((m) => m >= 1 && m <= tenureMonths).toList()
      ..sort();

    await database.updateLoan(
      id: loan.id,
      title: title,
      amount: amount,
      startDate: startDate,
      dueDate: dueDate,
      tenureMonths: tenureMonths,
      monthlyAmount: monthlyAmount,
      note: note,
      paymentMode: paymentMode,
      customMonthlyAmounts: customMonthlyAmounts,
      paidMonths: keptPaidMonths,
    );

    await reload();

    final updated = loans.firstWhere((item) => item.id == loan.id);
    await _safe(() => notifications.scheduleLoan(updated));
  }

  Future<void> toggleLoanMonthPaid(Loan loan, int month) async {
    final currentlyPaid = loan.isMonthPaid(month);

    if (currentlyPaid) {
      // Unmark: delete the linked expense, then re-schedule this month's reminders.
      final expenseId = loan.expenseIdForMonth(month);
      if (expenseId != null) {
        await database.deleteExpense(expenseId);
        await database.setPaidMonthExpense(loan.id, month, null);
      }
      await database.setLoanMonthPaid(loan.id, month, false);

      await reload();

      final updated = loans.firstWhere((item) => item.id == loan.id);
      await _safe(() => notifications.scheduleMonth(updated, month));
    } else {
      // Mark paid: create the expense, cancel just this month's reminders.
      final amount = loan.amountForMonth(month);
      final dueDate = loan.dueDateForMonth(month);

      final expenseId = await database.insertExpense(
        amount: amount,
        title: '${loan.title} — Month $month of ${loan.tenureMonths}',
        date: dueDate,
        note: 'Loan payment (auto-added)',
      );

      await database.setPaidMonthExpense(loan.id, month, expenseId);
      await database.setLoanMonthPaid(loan.id, month, true);

      await _safe(() => notifications.cancelMonth(loan.id, month));

      await reload();
    }
  }

  Future<void> markAllLoanMonthsPaid(Loan loan, bool paid) async {
    if (paid) {
      for (int m = 1; m <= loan.tenureMonths; m++) {
        if (loan.isMonthPaid(m)) continue;
        final amount = loan.amountForMonth(m);
        final dueDate = loan.dueDateForMonth(m);
        final expenseId = await database.insertExpense(
          amount: amount,
          title: '${loan.title} — Month $m of ${loan.tenureMonths}',
          date: dueDate,
          note: 'Loan payment (auto-added)',
        );
        await database.setPaidMonthExpense(loan.id, m, expenseId);
      }
      for (int m = 1; m <= loan.tenureMonths; m++) {
        await database.setLoanMonthPaid(loan.id, m, true);
      }
      await _safe(
            () => notifications.cancelLoan(
          loan.id,
          tenure: loan.tenureMonths,
        ),
      );
    } else {
      for (int m = 1; m <= loan.tenureMonths; m++) {
        final expenseId = loan.expenseIdForMonth(m);
        if (expenseId != null) {
          await database.deleteExpense(expenseId);
        }
        await database.setPaidMonthExpense(loan.id, m, null);
      }
      await database.setLoanPaidMonths(loan.id, []);

      await reload();

      final updated = loans.firstWhere((item) => item.id == loan.id);
      await _safe(() => notifications.scheduleLoan(updated));
    }

    await reload();
  }

  Future<void> toggleLoanPaid(Loan loan) async {
    final newPaid = !loan.paid;

    if (newPaid) {
      // Archiving: cancel everything.
      await _safe(
            () => notifications.cancelLoan(
          loan.id,
          tenure: loan.tenureMonths,
        ),
      );
    }

    await database.setLoanPaid(loan.id, newPaid);
    await reload();

    if (!newPaid) {
      // Unarchiving: reschedule.
      final updated = loans.firstWhere((item) => item.id == loan.id);
      await _safe(() => notifications.scheduleLoan(updated));
    }
  }

  Future<void> deleteLoan(Loan loan) async {
    // Delete auto-created expenses.
    for (int m = 1; m <= loan.tenureMonths; m++) {
      final expenseId = loan.expenseIdForMonth(m);
      if (expenseId != null) {
        await database.deleteExpense(expenseId);
      }
    }

    await _safe(
          () => notifications.cancelLoan(
        loan.id,
        tenure: loan.tenureMonths,
      ),
    );

    await database.deleteLoan(loan.id);
    await reload();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e, st) {
      debugPrint('[controller] notification error: $e\n$st');
    }
  }
}