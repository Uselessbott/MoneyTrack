import 'package:flutter/material.dart';

import '../models/credit.dart';
import '../state/app_controller.dart';
import '../utils/format.dart';

class CreditFormScreen extends StatefulWidget {
  const CreditFormScreen({
    super.key,
    required this.controller,
    this.credit,
    this.initialDate,
  });

  final AppController controller;
  final Credit? credit;

  /// Only used when creating a new credit (not editing).
  final DateTime? initialDate;

  @override
  State<CreditFormScreen> createState() => _CreditFormScreenState();
}

class _CreditFormScreenState extends State<CreditFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController amountController;
  late final TextEditingController titleController;
  late final TextEditingController noteController;

  late DateTime selectedDate;
  bool saving = false;

  bool get editing => widget.credit != null;

  @override
  void initState() {
    super.initState();
    final credit = widget.credit;

    amountController = TextEditingController(
      text: credit == null ? '' : credit.amount.toStringAsFixed(2),
    );
    titleController = TextEditingController(text: credit?.title ?? '');
    noteController = TextEditingController(text: credit?.note ?? '');
    selectedDate = credit?.date ?? widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    amountController.dispose();
    titleController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit credit' : 'Add credit'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: amountController,
              keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount received',
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
            const SizedBox(height: 16),
            TextFormField(
              controller: titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Source',
                hintText: 'Salary, refund, gift...',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Enter a source.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(formatDate(selectedDate)),
              trailing: const Icon(Icons.calendar_month),
              onTap: _pickDate,
            ),
            const Divider(),
            const SizedBox(height: 8),
            TextFormField(
              controller: noteController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note',
                hintText: 'Optional',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving ? null : _save,
              child: Text(saving ? 'Saving...' : 'Save credit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (date != null) {
      setState(() => selectedDate = date);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => saving = true);

    final amount = double.parse(amountController.text.trim());
    final title = titleController.text.trim();
    final note = noteController.text.trim();

    if (editing) {
      await widget.controller.updateCredit(
        credit: widget.credit!,
        amount: amount,
        title: title,
        date: selectedDate,
        note: note,
      );
    } else {
      await widget.controller.addCredit(
        amount: amount,
        title: title,
        date: selectedDate,
        note: note,
      );
    }

    if (mounted) Navigator.pop(context);
  }
}