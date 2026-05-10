import 'package:flutter_test/flutter_test.dart';
import 'package:kebtang/models/transaction.dart';

void main() {
  group('Transaction Model Tests', () {
    test('Transaction.toJson() should return a valid Map', () {
      final date = DateTime(2023, 10, 27);
      final tx = Transaction(
        id: '123',
        title: 'Lunch',
        amount: 50.0,
        isIncome: false,
        date: date,
        category: 'food',
        note: 'Yummy',
      );

      final json = tx.toJson();

      expect(json['id'], '123');
      expect(json['title'], 'Lunch');
      expect(json['amount'], 50.0);
      expect(json['isIncome'], false);
      expect(json['date'], date.toIso8601String());
      expect(json['category'], 'food');
      expect(json['note'], 'Yummy');
    });

    test('Transaction.fromJson() should return a valid Transaction object', () {
      final json = {
        'id': '456',
        'title': 'Salary',
        'amount': 5000.0,
        'isIncome': true,
        'date': '2023-10-28T00:00:00.000',
        'category': 'salary',
        'note': 'Monthly pay',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.id, '456');
      expect(tx.title, 'Salary');
      expect(tx.amount, 5000.0);
      expect(tx.isIncome, true);
      expect(tx.date, DateTime(2023, 10, 28));
      expect(tx.category, 'salary');
      expect(tx.note, 'Monthly pay');
    });

    test('Transaction.fromJson() should handle missing note field', () {
      final json = {
        'id': '789',
        'title': 'Other',
        'amount': 10.0,
        'isIncome': true,
        'date': '2023-10-29T00:00:00.000',
        'category': 'other',
      };

      final tx = Transaction.fromJson(json);

      expect(tx.note, '');
    });
  });
}
