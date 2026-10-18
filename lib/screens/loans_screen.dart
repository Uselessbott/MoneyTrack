import 'package:flutter/material.dart';

import '../models/loan.dart';
import '../state/app_controller.dart';
import '../utils/format.dart';
import '../widgets/stat_card.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

class LoansScreen extends StatelessWidget {
  const LoansScreen({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loans'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: controller.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add_loan_fab',
        onPressed: () => _openAdd(context),
        icon: const Icon(Icons.add),
        label: const Text('Loan'),
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          if (controller.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final entries = <_ListEntry>[];
          entries.add(const _ListEntry.stats());

          if (controller.overdueLoans.isNotEmpty) {
            entries.add(_ListEntry.section(
              'Overdue',
              controller.overdueLoans.length,
            ));
            for (final loan in controller.overdueLoans) {
              entries.add(_ListEntry.loan(loan));
            }
          }

          entries.add(_ListEntry.section(
            'Upcoming',
            controller.upcomingLoans.length,
          ));

          if (controller.upcomingLoans.isEmpty) {
            entries.add(const _ListEntry.empty());
          } else {
            for (final loan in controller.upcomingLoans) {
              entries.add(_ListEntry.loan(loan));
            }
          }

          final archived =
          controller.loans.where((l) => l.paid).toList();
          if (archived.isNotEmpty) {
            entries.add(const _ListEntry.spacer());
            entries.add(_ListEntry.section('Archived', archived.length));
            for (final loan in archived) {
              entries.add(_ListEntry.loan(loan));
            }
          }

          return RefreshIndicator(
            onRefresh: controller.reload,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              itemCount: entries.length,
              addAutomaticKeepAlives: false,
              addRepaintBoundaries: true,
              itemBuilder: (context, i) {
                final e = entries[i];
                switch (e.type) {
                  case _EntryType.stats:
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              label: 'Outstanding',
                              value: money(controller.totalLoanAmount),
                              icon: Icons.account_balance_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              label: 'Monthly due',
                              value: money(controller.totalMonthlyDue),
                              icon: Icons.calendar_month_outlined,
                            ),
                          ),
                        ],
                      ),
                    );
                  case _EntryType.section:
                    return _SectionTitle(
                      title: e.text!,
                      count: e.count,
                    );
                  case _EntryType.loan:
                    final loan = e.loan!;
                    return _LoanRow(
                      key: ValueKey('loan-${loan.id}'),
                      loan: loan,
                      onTap: () => _openDetail(context, loan),
                    );
                  case _EntryType.empty:
                    return const _EmptyLoans();
                  case _EntryType.spacer:
                    return const SizedBox(height: 20);
                }
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _openAdd(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanFormScreen(controller: controller),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, Loan loan) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoanDetailScreen(
          controller: controller,
          loanId: loan.id,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flat-list entry model
// ---------------------------------------------------------------------------

enum _EntryType { stats, section, loan, empty, spacer }

class _ListEntry {
  const _ListEntry._(this.type, {this.text, this.count, this.loan});

  const _ListEntry.stats() : this._(_EntryType.stats);
  const _ListEntry.empty() : this._(_EntryType.empty);
  const _ListEntry.spacer() : this._(_EntryType.spacer);
  const _ListEntry.section(String title, int count)
      : this._(_EntryType.section, text: title, count: count);
  const _ListEntry.loan(Loan loan) : this._(_EntryType.loan, loan: loan);

  final _EntryType type;
  final String? text;
  final int? count;
  final Loan? loan;
}

// ---------------------------------------------------------------------------
// Section title
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.count});

  final String title;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Chip(
              label: Text('$count'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Loan row — compact, tappable, shows next due amount
// ---------------------------------------------------------------------------

class _LoanRow extends StatelessWidget {
  const _LoanRow({
    super.key,
    required this.loan,
    required this.onTap,
  });

  final Loan loan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final next = loan.nextUnpaidMonth;
    final isOverdue = next != null && loan.isMonthOverdue(next);

    final progressText = '${loan.paidCount}/${loan.tenureMonths} paid';

    // Amount due for the next unpaid month (or 0 if fully paid).
    final nextDueAmount =
    next != null ? loan.amountForMonth(next) : 0.0;

    final middleText = loan.isFullyPaid
        ? progressText
        : 'Due ${money(nextDueAmount)} • $progressText';

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: loan.isFullyPaid
                    ? Colors.green.withValues(alpha: .15)
                    : isOverdue
                    ? Colors.red.withValues(alpha: .15)
                    : null,
                child: Icon(
                  loan.isFullyPaid
                      ? Icons.check
                      : isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loan.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      middleText,
                      style: const TextStyle(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loan.isFullyPaid
                          ? 'All months paid'
                          : 'Next: ${formatDate(loan.dueDateForMonth(next!))} '
                          '• ${dueLabel(loan.dueDateForMonth(next))}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: loan.isFullyPaid
                            ? Colors.green.shade700
                            : isOverdue
                            ? Colors.red
                            : Colors.green.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyLoans extends StatelessWidget {
  const _EmptyLoans();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Column(
        children: [
          Icon(
            Icons.event_note_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text('No upcoming loans.'),
        ],
      ),
    );
  }
}