import 'package:flutter/material.dart';

import '../models/loan.dart';
import '../state/app_controller.dart';
import '../utils/format.dart';
import 'loan_form_screen.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({
    super.key,
    required this.controller,
    required this.loanId,
  });

  final AppController controller;

  /// We pass the id, not the Loan object, so the screen always reads the
  /// latest version from the controller after any edit or toggle.
  final int loanId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final loan = controller.loans.firstWhere(
              (l) => l.id == loanId,
          orElse: () => throw StateError('Loan $loanId not found'),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(loan.title),
            actions: [
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenu(context, loan, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'all_paid',
                    child: Text('Mark all months paid'),
                  ),
                  const PopupMenuItem(
                    value: 'all_unpaid',
                    child: Text('Mark all months unpaid'),
                  ),
                  PopupMenuItem(
                    value: 'archive',
                    child:
                    Text(loan.paid ? 'Unarchive' : 'Archive loan'),
                  ),
                  const PopupMenuItem(
                      value: 'edit', child: Text('Edit')),
                  const PopupMenuItem(
                      value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _HeaderCard(loan: loan),
              const SizedBox(height: 16),
              _InfoSection(loan: loan),
              const SizedBox(height: 8),
              _SectionHeader(
                title: 'Installments (${loan.tenureMonths})',
                subtitle:
                '${loan.paidCount} paid • ${loan.unpaidCount} remaining',
              ),
              const SizedBox(height: 8),

              // The month list — this is a nested non-scrolling list of
              // lightweight rows. Because this whole screen was built once
              // when it opened, cost is a one-time hit; scrolling is smooth.
              for (int month = 1; month <= loan.tenureMonths; month++)
                _MonthRow(
                  key: ValueKey('month-${loan.id}-$month'),
                  loan: loan,
                  month: month,
                  controller: controller,
                ),

              const SizedBox(height: 24),
              _DangerZone(
                onDelete: () => _confirmDelete(context, loan),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleMenu(
      BuildContext context,
      Loan loan,
      String value,
      ) async {
    if (value == 'edit') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoanFormScreen(
            controller: controller,
            loan: loan,
          ),
        ),
      );
    } else if (value == 'delete') {
      await _confirmDelete(context, loan);
    } else if (value == 'all_paid') {
      await controller.markAllLoanMonthsPaid(loan, true);
    } else if (value == 'all_unpaid') {
      await controller.markAllLoanMonthsPaid(loan, false);
    } else if (value == 'archive') {
      await controller.toggleLoanPaid(loan);
      // Leave the detail screen if the loan is gone from the main list.
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(BuildContext context, Loan loan) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete loan?'),
        content: Text('Delete "${loan.title}" and its reminders?'),
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
      await controller.deleteLoan(loan);
      if (!context.mounted) return;
      Navigator.of(context).pop();
    }
  }
}

// ---------------------------------------------------------------------------
// Header card — big amount + progress
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final next = loan.nextUnpaidMonth;
    final isOverdue = next != null && loan.isMonthOverdue(next);

    final progress = loan.tenureMonths == 0
        ? 0.0
        : loan.paidCount / loan.tenureMonths;

    final statusText = loan.isFullyPaid
        ? 'All months paid'
        : next == null
        ? 'All months paid'
        : isOverdue
        ? 'Overdue: ${dueLabel(loan.dueDateForMonth(next))}'
        : 'Next due ${formatDate(loan.dueDateForMonth(next))}';

    final statusColor = loan.isFullyPaid
        ? Colors.green.shade700
        : isOverdue
        ? Colors.red
        : scheme.primary;

    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loan.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${loan.paidCount} of ${loan.tenureMonths} months paid',
              style: TextStyle(
                fontSize: 13,
                color:
                scheme.onPrimaryContainer.withValues(alpha: .75),
              ),
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor:
                scheme.onPrimaryContainer.withValues(alpha: .2),
                valueColor: AlwaysStoppedAnimation(
                  loan.isFullyPaid
                      ? Colors.green.shade400
                      : scheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(
                  loan.isFullyPaid
                      ? Icons.check_circle_outline
                      : isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.calendar_today_outlined,
                  size: 16,
                  color: statusColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info section — principal, total, interest, monthly
// ---------------------------------------------------------------------------

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.loan});

  final Loan loan;

  @override
  Widget build(BuildContext context) {
    final principal = loan.amount;
    final totalPayable = loan.totalScheduledAmount;
    final interest = totalPayable - principal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
              label: 'Principal (borrowed)',
              value: money(principal),
            ),
            _InfoRow(
              label: 'Total payable',
              value: money(totalPayable),
              bold: true,
            ),
            _InfoRow(
              label: 'Interest / fees',
              value: interest > 0 ? money(interest) : '—',
              valueColor:
              interest > 0 ? Colors.orange.shade700 : null,
              bold: interest > 0,
            ),
            _InfoRow(
              label: 'Monthly payment',
              value: loan.isCustom
                  ? '${money(loan.monthlyAmount)} avg'
                  : money(loan.monthlyAmount),
            ),
            _InfoRow(
              label: 'Start date',
              value: formatDate(loan.startDate),
            ),
            _InfoRow(
              label: 'Final due date',
              value: formatDate(loan.dueDate),
            ),
            if (loan.note.isNotEmpty) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes,
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      loan.note,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.outline,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Month row — lightweight custom row (no CheckboxListTile)
// ---------------------------------------------------------------------------

class _MonthRow extends StatelessWidget {
  const _MonthRow({
    super.key,
    required this.loan,
    required this.month,
    required this.controller,
  });

  final Loan loan;
  final int month;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final isPaid = loan.isMonthPaid(month);
    final amount = loan.amountForMonth(month);
    final due = loan.dueDateForMonth(month);
    final isOverdue = loan.isMonthOverdue(month);

    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: isPaid
          ? scheme.surfaceContainerHighest
          : isOverdue
          ? Colors.red.withValues(alpha: .08)
          : null,
      child: InkWell(
        onTap: () => controller.toggleLoanMonthPaid(loan, month),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: Row(
            children: [
              Checkbox(
                value: isPaid,
                onChanged: (_) =>
                    controller.toggleLoanMonthPaid(loan, month),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Month $month',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        decoration:
                        isPaid ? TextDecoration.lineThrough : null,
                        color: isPaid ? Colors.grey : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Due ${formatDate(due)}'
                          '${isOverdue ? ' • Overdue' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isOverdue
                            ? Colors.red
                            : scheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                money(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isPaid ? Colors.grey : null,
                  decoration:
                  isPaid ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Danger zone
// ---------------------------------------------------------------------------

class _DangerZone extends StatelessWidget {
  const _DangerZone({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onDelete,
      icon: const Icon(Icons.delete_outline, color: Colors.red),
      label: const Text(
        'Delete loan',
        style: TextStyle(color: Colors.red),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.red),
      ),
    );
  }
}