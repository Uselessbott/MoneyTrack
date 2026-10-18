import 'package:flutter/material.dart';

import '../models/credit.dart';
import '../state/app_controller.dart';
import '../utils/format.dart';
import '../widgets/stat_card.dart';
import 'credit_form_screen.dart';
import 'transaction_history_screen.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credits'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_credit_fab',
        onPressed: () => _openAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Credit'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final recent = controller.credits.take(20).toList();

          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatCard(
                        label: 'Total credits',
                        value: money(controller.totalCredits),
                        icon: Icons.savings_outlined,
                        onTap: () => _openHistory(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatCard(
                        label: 'Entries',
                        value: '${controller.credits.length}',
                        icon: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Recent credits',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (recent.isEmpty)
                  const _EmptyCredits()
                else
                  ...recent.map(
                        (credit) => _CreditTile(
                      credit: credit,
                      onEdit: () => _openEdit(context, credit),
                      onDelete: () => _delete(context, credit),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionHistoryScreen(controller: controller),
      ),
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditFormScreen(controller: controller),
      ),
    );
  }

  Future<void> _openEdit(BuildContext context, Credit credit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreditFormScreen(
          controller: controller,
          credit: credit,
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, Credit credit) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete credit?'),
        content: Text('Delete "${credit.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await controller.deleteCredit(credit);
    }
  }
}

class _CreditTile extends StatelessWidget {
  const _CreditTile({
    required this.credit,
    required this.onEdit,
    required this.onDelete,
  });

  final Credit credit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: .15),
          child: const Icon(Icons.arrow_downward, color: Colors.green),
        ),
        title: Text(
          credit.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${formatDate(credit.date)}'
              '${credit.note.isEmpty ? '' : ' • ${credit.note}'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          '+${money(credit.amount)}',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.green,
          ),
        ),
      ),
    );
  }
}

class _EmptyCredits extends StatelessWidget {
  const _EmptyCredits();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No credits yet.'),
          const SizedBox(height: 4),
          const Text(
            'Add money you received here.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}