class Expense {
  const Expense({
    required this.id,
    required this.amount,
    required this.title,
    required this.date,
    required this.note,
  });

  final int id;
  final double amount;
  final String title;
  final DateTime date;
  final String note;

  factory Expense.fromMap(Map<String, Object?> map) {
    return Expense(
      id: map['id'] as int,
      amount: (map['amount'] as num).toDouble(),
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      note: (map['note'] as String?) ?? '',
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'amount': amount,
      'title': title,
      'date': date.toIso8601String(),
      'note': note,
    };
  }
}