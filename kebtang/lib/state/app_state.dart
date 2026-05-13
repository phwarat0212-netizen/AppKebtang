import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

// ─── App State (บันทึก/โหลดข้อมูลจาก Backend) ─────────────────────

class AppState extends ChangeNotifier {
  final String _username;
  String get _baseUrl => ApiConfig.baseUrl;

  List<Transaction> _transactions = [];
  bool _loaded = false;
  String? _errorMessage;
  double _budget = 0;
  IO.Socket? _socket;

  List<String> _incomeCategories = ['salary', 'freelance', 'bonus', 'investment', 'other'];
  List<String> _expenseCategories = ['food', 'travel', 'shopping', 'bill', 'entertainment', 'health', 'other'];

  AppState(this._username) {
    _loadFromBackend();
    _loadBudget();
    _loadCategories();
    _initSocket();
  }

  Future<void> _loadBudget() async {
    final prefs = await SharedPreferences.getInstance();
    _budget = prefs.getDouble('budget_$_username') ?? 0;
    notifyListeners();
  }

  Future<void> updateBudget(double amount) async {
    _budget = amount;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('budget_$_username', amount);
    notifyListeners();
  }

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final inc = prefs.getStringList('inc_cats_$_username');
    final exp = prefs.getStringList('exp_cats_$_username');
    if (inc != null) _incomeCategories = inc;
    if (exp != null) _expenseCategories = exp;
    notifyListeners();
  }

  Future<void> updateCategories({required List<String> income, required List<String> expense}) async {
    _incomeCategories = income;
    _expenseCategories = expense;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('inc_cats_$_username', income);
    await prefs.setStringList('exp_cats_$_username', expense);
    notifyListeners();
  }

  void _initSocket() {
    _socket = IO.io(ApiConfig.socketUrl, IO.OptionBuilder()
      .setTransports(['websocket'])
      .disableAutoConnect()
      .build()
    );

    _socket?.connect();

    _socket?.on('data_changed', (_) {
      _loadFromBackend();
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    super.dispose();
  }

  bool               get isLoaded          => _loaded;
  List<Transaction>  get transactions      => List.unmodifiable(_transactions);
  String?            get errorMessage      => _errorMessage;
  double             get budget            => _budget;
  List<String>       get incomeCategories  => _incomeCategories;
  List<String>       get expenseCategories => _expenseCategories;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  double get totalBalance => _transactions.fold(
    0, (sum, t) => t.isIncome ? sum + t.amount : sum - t.amount,
  );
  double get totalIncome  => _transactions.where((t) =>  t.isIncome).fold(0, (s, t) => s + t.amount);
  double get totalExpense => _transactions.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

  // Filtered totals
  List<Transaction> get transactionsToday {
    final now = DateTime.now();
    return _transactions.where((t) => 
      t.date.year == now.year && t.date.month == now.month && t.date.day == now.day
    ).toList();
  }

  List<Transaction> get transactionsThisWeek {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    return _transactions.where((t) => 
      t.date.isAfter(monday.subtract(const Duration(seconds: 1)))
    ).toList();
  }

  List<Transaction> get transactionsThisMonth {
    final now = DateTime.now();
    return _transactions.where((t) => 
      t.date.year == now.year && t.date.month == now.month
    ).toList();
  }

  double getIncomeOf(List<Transaction> list) => list.where((t) => t.isIncome).fold(0, (s, t) => s + t.amount);
  double getExpenseOf(List<Transaction> list) => list.where((t) => !t.isIncome).fold(0, (s, t) => s + t.amount);

  Future<void> refreshData() async {
    await _loadFromBackend();
  }

  // ── Load ──────────────────────────────────────────────────────
  Future<void> _loadFromBackend() async {
    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.get(
        Uri.parse('$_baseUrl/transactions/$_username'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      if (ApiConfig.handleAuthError(response)) {
        _loaded = true;
        notifyListeners();
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> decoded = jsonDecode(response.body);
        final backendTransactions = decoded.map((e) => Transaction.fromJson(e)).toList();
        
        final prefs = await SharedPreferences.getInstance();
        _transactions = backendTransactions.map((tx) {
          final localNote = prefs.getString('note_${tx.id}');
          if ((tx.note.isEmpty || tx.note == '-') && localNote != null && localNote.isNotEmpty) {
            return Transaction(
              id: tx.id, title: tx.title, amount: tx.amount,
              isIncome: tx.isIncome, date: tx.date, category: tx.category,
              note: localNote,
            );
          }
          return tx;
        }).toList();
      }
    } catch (e) {
      // Error handled silently for better UX
      _transactions = [];
    }
    _loaded = true;
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────
  Future<void> addTransaction(Transaction transaction) async {
    _errorMessage = null;
    _transactions.insert(0, transaction);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.post(
        Uri.parse('$_baseUrl/transactions/$_username'),
        headers: headers,
        body: jsonEncode(transaction.toJson()),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 201) {
        _errorMessage = 'error_network';
        await _loadFromBackend(); // Rollback/Sync
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'connection_error';
      await _loadFromBackend();
      notifyListeners();
    }
  }

  Future<void> removeTransaction(String id) async {
    _errorMessage = null;
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removedItem = _transactions[index];
    _transactions.removeAt(index);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/transactions/$_username/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        _errorMessage = 'error_network';
        _transactions.insert(index, removedItem); // Rollback
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'connection_error';
      _transactions.insert(index, removedItem); // Rollback
      notifyListeners();
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    _errorMessage = null;
    final prefs = await SharedPreferences.getInstance();
    final oldNote = prefs.getString('note_${transaction.id}');
    await prefs.setString('note_${transaction.id}', transaction.note);

    final idx = _transactions.indexWhere((t) => t.id == transaction.id);
    Transaction? oldTransaction;
    if (idx != -1) {
      oldTransaction = _transactions[idx];
      _transactions[idx] = transaction;
      notifyListeners();
    }

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/transactions/$_username/${transaction.id}'),
        headers: headers,
        body: jsonEncode(transaction.toJson()),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        await _loadFromBackend();
      } else {
        _errorMessage = 'error_network';
        if (idx != -1 && oldTransaction != null) {
          _transactions[idx] = oldTransaction;
        }
        if (oldNote != null) {
          await prefs.setString('note_${transaction.id}', oldNote);
        } else {
          await prefs.remove('note_${transaction.id}');
        }
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'connection_error';
      if (idx != -1 && oldTransaction != null) {
        _transactions[idx] = oldTransaction;
      }
      if (oldNote != null) {
        await prefs.setString('note_${transaction.id}', oldNote);
      } else {
        await prefs.remove('note_${transaction.id}');
      }
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String id) async {
    _errorMessage = null;
    final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final removedItem = _transactions[index];
    _transactions.removeAt(index);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/transactions/$_username/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        await _loadFromBackend();
      } else {
        _errorMessage = 'error_network';
        _transactions.insert(index, removedItem); // Rollback
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = 'connection_error';
      _transactions.insert(index, removedItem); // Rollback
      notifyListeners();
    }
  }
}
