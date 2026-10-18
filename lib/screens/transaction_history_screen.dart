import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import '../utils/format.dart';

class TransactionHistoryScreen extends StatelessWidget {
  const TransactionHistoryScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final entries = _combine(controller);

          if (entries.isEmpty) {
            return const Center(
              child: Text('No transactions yet.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length + 1,
            separatorBuilder: (_, i) =>
            i == 0 ? const SizedBox.shrink() : const Divider(height: 1),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SummaryCard(controller: controller),
                );
              }
              final entry = entries[i - 1];
              return _TransactionTile(entry: entry);
            },
          );
        },
      ),
    );
  }

  List<_Entry> _combine(AppController controller) {
    final list = <_Entry>[];

    for (final e in controller.expenses) {
      list.add(_Entry(
        title: e.title,
        amount: e.amount,
        date: e.date,
        note: e.note,
        isCredit: false,
      ));
    }

    for (final c in controller.credits) {
      list.add(_Entry(
        title: c.title,
        amount: c.amount,
        date: c.date,
        note: c.note,
        isCredit: true,
      ));
    }

    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}

class _Entry {
  const _Entry({
    required this.title,
    required this.amount,
    required this.date,
    required this.note,
    required this.isCredit,
  });

  final String title;
  final double amount;
  final DateTime date;
  final String note;
  final bool isCredit;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row(context, 'Total expenses', money(controller.totalSpent),
                Colors.red),
            const SizedBox(height: 8),
            _row(context, 'Total credits', money(controller.totalCredits),
                Colors.green),
            const Divider(height: 24),
            _row(
              context,
              'Net',
              money(controller.netSpent),
              controller.netSpent >= 0 ? Colors.red : Colors.green,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
      BuildContext context,
      String label,
      String value,
      Color color, {
        bool bold = false,
      }) {
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
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.entry});

  final _Entry entry;

  @override
  Widget build(BuildContext context) {
    final color = entry.isCredit ? Colors.green : Colors.red;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: .15),
        child: Icon(
          entry.isCredit ? Icons.arrow_downward : Icons.arrow_upward,
          color: color,
        ),
      ),
      title: Text(
        entry.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${formatDate(entry.date)}'
            '${entry.note.isEmpty ? '' : ' • ${entry.note}'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${entry.isCredit ? '+' : '-'}${money(entry.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}