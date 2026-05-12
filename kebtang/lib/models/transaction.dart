// ─── Transaction Model ────────────────────────────────────────────

class Transaction {
  final String   id;
  final String   title;
  final double   amount;
  final bool     isIncome;
  final DateTime date;
  final String   category;
  final String   note;

  Transaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.category,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'id'      : id,
    'title'   : title,
    'amount'  : amount,
    'isIncome': isIncome,
    'date'    : date.toIso8601String(),
    'category': category,
    'note'    : note,
  };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
    id      : j['id'],
    title   : j['title'],
    amount  : (j['amount'] as num).toDouble(),
    isIncome: j['isIncome'],
    date    : DateTime.parse(j['date']),
    category: j['category'],
    note    : j['note'] ?? '',
  );
}
