import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/loan.dart';
import '../state/app_controller.dart';
import '../utils/date_utils.dart';
import '../utils/decimal_input_formatter.dart';
import '../utils/format.dart';

class LoanFormScreen extends StatefulWidget {
  const LoanFormScreen({
    super.key,
    required this.controller,
    this.loan,
  });

  final AppController controller;
  final Loan? loan;

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController titleController;
  late final TextEditingController amountController;
  late final TextEditingController monthlyController;
  late final TextEditingController noteController;
  late final TextEditingController tenureController;

  late DateTime startDate;
  late DateTime dueDate;
  late int tenure;

  String paymentMode = 'fixed';

  List<TextEditingController> customAmountControllers = [];

  bool saving = false;

  bool get editing => widget.loan != null;

  @override
  void initState() {
    super.initState();

    final loan = widget.loan;

    titleController = TextEditingController(text: loan?.title ?? '');
    amountController = TextEditingController(
      text: loan == null ? '' : loan.amount.toStringAsFixed(2),
    );
    monthlyController = TextEditingController(
      text: loan == null ? '' : loan.monthlyAmount.toStringAsFixed(2),
    );
    noteController = TextEditingController(text: loan?.note ?? '');

    startDate = loan?.startDate ?? DateTime.now();
    dueDate = loan?.dueDate ?? addMonths(startDate, 1);
    tenure = loan?.tenureMonths ?? 1;

    if (tenure < 1) tenure = 1;

    tenureController = TextEditingController(text: tenure.toString());

    paymentMode = loan?.paymentMode ?? 'fixed';

    _buildCustomControllers(
      existing: loan?.customMonthlyAmounts ?? [],
    );
  }

  void _buildCustomControllers({List<double> existing = const []}) {
    for (final controller in customAmountControllers) {
      controller.dispose();
    }

    customAmountControllers = List.generate(
      tenure,
          (index) {
        final value = index < existing.length ? existing[index] : 0;
        return TextEditingController(
          text: value > 0 ? value.toStringAsFixed(2) : '',
        );
      },
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    amountController.dispose();
    monthlyController.dispose();
    noteController.dispose();
    tenureController.dispose();
    for (final controller in customAmountControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  double get customTotal {
    return customAmountControllers.fold<double>(0, (sum, controller) {
      return sum + (double.tryParse(controller.text.trim()) ?? 0);
    });
  }

  double get customAverage {
    if (tenure <= 0) return 0;
    return customTotal / tenure;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit loan' : 'Add loan'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Loan / payment name',
                hintText: 'Laptop EMI, Phone loan...',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Enter a name.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Total amount',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount.';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Payment type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'fixed',
                  icon: Icon(Icons.payments_outlined),
                  label: Text('Fixed'),
                ),
                ButtonSegment<String>(
                  value: 'custom',
                  icon: Icon(Icons.edit_calendar_outlined),
                  label: Text('Custom'),
                ),
              ],
              selected: {paymentMode},
              onSelectionChanged: (selection) {
                setState(() {
                  paymentMode = selection.first;
                  if (paymentMode == 'custom') {
                    final existing = customAmountControllers
                        .map((c) => double.tryParse(c.text.trim()) ?? 0)
                        .toList();
                    _buildCustomControllers(existing: existing);
                  }
                });
              },
            ),
            const SizedBox(height: 20),

            // ---- Tenure: free-form number input ----
            TextFormField(
              controller: tenureController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: const InputDecoration(
                labelText: 'Tenure (months)',
                hintText: '1 – 240',
                suffixText: 'months',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final raw = (value ?? '').trim();
                if (raw.isEmpty) return 'Enter tenure in months.';
                final n = int.tryParse(raw);
                if (n == null || n < 1) {
                  return 'Tenure must be at least 1 month.';
                }
                if (n > 240) {
                  return 'That is too long. Keep it under 240 months.';
                }
                return null;
              },
              onChanged: (value) {
                final n = int.tryParse(value.trim());
                if (n == null || n < 1 || n > 240) return;
                setState(() {
                  tenure = n;
                  dueDate = addMonths(startDate, tenure);
                  if (paymentMode == 'custom') {
                    final oldValues = customAmountControllers
                        .map((c) => double.tryParse(c.text.trim()) ?? 0)
                        .toList();
                    _buildCustomControllers(existing: oldValues);
                  }
                });
              },
            ),

            const SizedBox(height: 16),
            if (paymentMode == 'fixed')
              _buildFixedPayment()
            else
              _buildCustomPayments(),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start date'),
              subtitle: Text(formatDate(startDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickStartDate,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Final due date'),
              subtitle: Text(formatDate(dueDate)),
              trailing: const Icon(Icons.event),
              onTap: _pickDueDate,
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: noteController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note / description',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saving...' : 'Save loan'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedPayment() {
    return TextFormField(
      controller: monthlyController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [DecimalInputFormatter()],
      decoration: const InputDecoration(
        labelText: 'Monthly payment',
        prefixText: '₹ ',
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        final amount = double.tryParse(value?.trim() ?? '');
        if (amount == null || amount <= 0) {
          return 'Enter a valid monthly amount.';
        }
        return null;
      },
    );
  }

  Widget _buildCustomPayments() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Monthly payments',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Enter a different amount for each month.',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        ...List.generate(tenure, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              controller: customAmountControllers[index],
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [DecimalInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Month ${index + 1}',
                prefixText: '₹ ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final amount = double.tryParse(value?.trim() ?? '');
                if (amount == null || amount <= 0) {
                  return 'Enter an amount.';
                }
                return null;
              },
            ),
          );
        }),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Scheduled total'),
                    Text(
                      money(customTotal),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Average monthly'),
                    Text(money(customAverage)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    setState(() {
      startDate = date;
      dueDate = addMonths(startDate, tenure);
    });
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: dueDate,
      firstDate: startDate,
      lastDate: DateTime(2100),
    );

    if (date == null) return;
    setState(() => dueDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (dueDate.isBefore(startDate)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date cannot be before start date.'),
        ),
      );
      return;
    }

    final totalAmount = double.tryParse(amountController.text.trim());
    if (totalAmount == null || totalAmount <= 0) return;

    List<double> customAmounts = [];
    double monthlyAmount;

    if (paymentMode == 'custom') {
      customAmounts = customAmountControllers
          .map((c) => double.tryParse(c.text.trim()) ?? 0)
          .toList();

      if (customAmounts.length != tenure) return;

      if (customAmounts.any((amount) => amount <= 0)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter an amount for every month.'),
          ),
        );
        return;
      }

      monthlyAmount =
          customAmounts.fold<double>(0, (sum, a) => sum + a) / tenure;
    } else {
      monthlyAmount = double.parse(monthlyController.text.trim());
    }

    setState(() => saving = true);

    try {
      final title = titleController.text.trim();
      final note = noteController.text.trim();

      if (editing) {
        await widget.controller.updateLoan(
          loan: widget.loan!,
          title: title,
          amount: totalAmount,
          startDate: startDate,
          dueDate: dueDate,
          tenureMonths: tenure,
          monthlyAmount: monthlyAmount,
          note: note,
          paymentMode: paymentMode,
          customMonthlyAmounts: customAmounts,
        );
      } else {
        await widget.controller.addLoan(
          title: title,
          amount: totalAmount,
          startDate: startDate,
          dueDate: dueDate,
          tenureMonths: tenure,
          monthlyAmount: monthlyAmount,
          note: note,
          paymentMode: paymentMode,
          customMonthlyAmounts: customAmounts,
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save loan: $e')),
      );
    }
  }
}