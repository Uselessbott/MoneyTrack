import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/credit.dart';
import '../models/expense.dart';
import '../state/app_controller.dart';
import '../utils/format.dart';
import 'credit_form_screen.dart';
import 'expense_form_screen.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({
    super.key,
    required this.controller,
    required this.date,
  });

  final AppController controller;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('d MMM yyyy').format(date)),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final expenses = controller.expenses
              .where((e) => _sameDay(e.date, date))
              .toList();
          final credits = controller.credits
              .where((c) => _sameDay(c.date, date))
              .toList();

          final totalExpenses =
          expenses.fold<double>(0, (s, e) => s + e.amount);
          final totalCredits =
          credits.fold<double>(0, (s, c) => s + c.amount);
          final net = totalExpenses - totalCredits;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
            children: [
              // ---- Summary ----
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Total spent', money(totalExpenses), Colors.red),
                      const SizedBox(height: 6),
                      _row('Total received', money(totalCredits),
                          Colors.green),
                      const Divider(height: 20),
                      _row(
                        'Net',
                        money(net),
                        net >= 0 ? Colors.red : Colors.green,
                        bold: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---- Expenses ----
              if (expenses.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Expenses (${expenses.length})',
                  color: Colors.red,
                  icon: Icons.arrow_upward,
                ),
                const SizedBox(height: 4),
                ...expenses.map(
                      (e) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        Colors.red.withValues(alpha: .15),
                        child:
                        const Icon(Icons.arrow_upward, color: Colors.red),
                      ),
                      title: Text(e.title),
                      subtitle:
                      e.note.isEmpty ? null : Text(e.note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '-${money(e.amount)}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) => _handleExpense(context, v, e),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ---- Credits ----
              if (credits.isNotEmpty) ...[
                _SectionHeader(
                  title: 'Credits (${credits.length})',
                  color: Colors.green,
                  icon: Icons.arrow_downward,
                ),
                const SizedBox(height: 4),
                ...credits.map(
                      (c) => Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                        Colors.green.withValues(alpha: .15),
                        child: const Icon(Icons.arrow_downward,
                            color: Colors.green),
                      ),
                      title: Text(c.title),
                      subtitle:
                      c.note.isEmpty ? null : Text(c.note),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+${money(c.amount)}',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) => _handleCredit(context, v, c),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (expenses.isEmpty && credits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_busy_outlined,
                        size: 56,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions on this day.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              // ---- Add buttons ----
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addExpense(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add expense'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _addCredit(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add credit'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool bold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Future<void> _addExpense(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(
          controller: controller,
          // Pre-fill date
          initialDate: date,
        ),
      ),
    );
  }

  Future<void> _addCredit(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditFormScreen(
          controller: controller,
          initialDate: date,
        ),
      ),
    );
  }

  Future<void> _handleExpense(
      BuildContext context, String value, Expense e) async {
    if (value == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(
            controller: controller,
            expense: e,
          ),
        ),
      );
    } else if (value == 'delete') {
      await controller.deleteExpense(e);
    }
  }

  Future<void> _handleCredit(
      BuildContext context, String value, Credit c) async {
    if (value == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreditFormScreen(
            controller: controller,
            credit: c,
          ),
        ),
      );
    } else if (value == 'delete') {
      await controller.deleteCredit(c);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.color,
    required this.icon,
  });

  final String title;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}