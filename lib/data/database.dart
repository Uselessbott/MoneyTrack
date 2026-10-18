import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/credit.dart';
import '../models/expense.dart';
import '../models/loan.dart';

class AppDatabase {
  static const String _databaseName = 'money_tracker.db';
  static const int _databaseVersion = 5;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _openDatabase();
    return _database!;
  }

  Future<void> open() async {
    await database;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return openDatabase(
      path,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE expenses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE credits (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            amount REAL NOT NULL,
            title TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE loans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            amount REAL NOT NULL,
            start_date TEXT NOT NULL,
            due_date TEXT NOT NULL,
            tenure_months INTEGER NOT NULL,
            monthly_amount REAL NOT NULL,
            note TEXT NOT NULL,
            paid INTEGER NOT NULL DEFAULT 0,
            payment_mode TEXT NOT NULL DEFAULT 'fixed',
            custom_monthly_amounts TEXT NOT NULL DEFAULT '',
            paid_months TEXT NOT NULL DEFAULT '',
            paid_month_expenses TEXT NOT NULL DEFAULT ''
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            ALTER TABLE loans
            ADD COLUMN payment_mode TEXT NOT NULL DEFAULT 'fixed'
          ''');
          await db.execute('''
            ALTER TABLE loans
            ADD COLUMN custom_monthly_amounts TEXT NOT NULL DEFAULT ''
          ''');
        }
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE credits (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              amount REAL NOT NULL,
              title TEXT NOT NULL,
              date TEXT NOT NULL,
              note TEXT NOT NULL
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('''
            ALTER TABLE loans
            ADD COLUMN paid_months TEXT NOT NULL DEFAULT ''
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            ALTER TABLE loans
            ADD COLUMN paid_month_expenses TEXT NOT NULL DEFAULT ''
          ''');
        }
      },
    );
  }

  // ---------------------------------------------------------------------------
  // EXPENSES
  // ---------------------------------------------------------------------------

  Future<List<Expense>> getExpenses() async {
    final db = await database;
    final rows = await db.query('expenses', orderBy: 'date DESC, id DESC');
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> insertExpense({
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    final db = await database;
    return db.insert('expenses', {
      'amount': amount,
      'title': title,
      'date': date.toIso8601String(),
      'note': note,
    });
  }

  Future<void> updateExpense({
    required int id,
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    final db = await database;
    await db.update(
      'expenses',
      {
        'amount': amount,
        'title': title,
        'date': date.toIso8601String(),
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteExpense(int id) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // CREDITS
  // ---------------------------------------------------------------------------

  Future<List<Credit>> getCredits() async {
    final db = await database;
    final rows = await db.query('credits', orderBy: 'date DESC, id DESC');
    return rows.map(Credit.fromMap).toList();
  }

  Future<int> insertCredit({
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    final db = await database;
    return db.insert('credits', {
      'amount': amount,
      'title': title,
      'date': date.toIso8601String(),
      'note': note,
    });
  }

  Future<void> updateCredit({
    required int id,
    required double amount,
    required String title,
    required DateTime date,
    required String note,
  }) async {
    final db = await database;
    await db.update(
      'credits',
      {
        'amount': amount,
        'title': title,
        'date': date.toIso8601String(),
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteCredit(int id) async {
    final db = await database;
    await db.delete('credits', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------------------------------------------------------------------
  // LOANS
  // ---------------------------------------------------------------------------

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final rows = await db.query('loans', orderBy: 'due_date ASC, id DESC');
    return rows.map(Loan.fromMap).toList();
  }

  Future<int> insertLoan({
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
    final db = await database;
    return db.insert('loans', {
      'title': title,
      'amount': amount,
      'start_date': startDate.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'tenure_months': tenureMonths,
      'monthly_amount': monthlyAmount,
      'note': note,
      'paid': 0,
      'payment_mode': paymentMode,
      'custom_monthly_amounts': customMonthlyAmounts.join(','),
      'paid_months': '',
      'paid_month_expenses': '',
    });
  }

  Future<void> updateLoan({
    required int id,
    required String title,
    required double amount,
    required DateTime startDate,
    required DateTime dueDate,
    required int tenureMonths,
    required double monthlyAmount,
    required String note,
    String paymentMode = 'fixed',
    List<double> customMonthlyAmounts = const [],
    List<int> paidMonths = const [],
  }) async {
    final db = await database;
    await db.update(
      'loans',
      {
        'title': title,
        'amount': amount,
        'start_date': startDate.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'tenure_months': tenureMonths,
        'monthly_amount': monthlyAmount,
        'note': note,
        'payment_mode': paymentMode,
        'custom_monthly_amounts': customMonthlyAmounts.join(','),
        'paid_months': paidMonths.join(','),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setLoanPaid(int id, bool paid) async {
    final db = await database;
    await db.update(
      'loans',
      {'paid': paid ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setLoanPaidMonths(int id, List<int> months) async {
    final db = await database;
    await db.update(
      'loans',
      {'paid_months': months.join(',')},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setLoanMonthPaid(int id, int month, bool paid) async {
    final db = await database;
    final rows = await db.query(
      'loans',
      columns: ['paid_months'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return;

    final raw = (rows.first['paid_months'] as String?) ?? '';
    final set = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .toSet();

    if (paid) {
      set.add(month);
    } else {
      set.remove(month);
    }

    final sorted = set.toList()..sort();
    await setLoanPaidMonths(id, sorted);
  }

  /// Associates (or clears) an auto-created expense id with a loan month.
  Future<void> setPaidMonthExpense(
      int loanId,
      int month,
      int? expenseId,
      ) async {
    final db = await database;
    final rows = await db.query(
      'loans',
      columns: ['paid_month_expenses'],
      where: 'id = ?',
      whereArgs: [loanId],
      limit: 1,
    );
    if (rows.isEmpty) return;

    final raw = (rows.first['paid_month_expenses'] as String?) ?? '';
    final map = <int, int>{};
    for (final pair in raw.split(',')) {
      final parts = pair.split(':');
      if (parts.length != 2) continue;
      final m = int.tryParse(parts[0].trim());
      final e = int.tryParse(parts[1].trim());
      if (m != null && e != null) map[m] = e;
    }

    if (expenseId == null) {
      map.remove(month);
    } else {
      map[month] = expenseId;
    }

    final encoded =
    map.entries.map((e) => '${e.key}:${e.value}').join(',');
    await db.update(
      'loans',
      {'paid_month_expenses': encoded},
      where: 'id = ?',
      whereArgs: [loanId],
    );
  }

  Future<void> deleteLoan(int id) async {
    final db = await database;
    await db.delete('loans', where: 'id = ?', whereArgs: [id]);
  }
}