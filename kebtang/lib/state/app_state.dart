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
  IO.Socket? _socket;

  AppState(this._username) {
    _loadFromBackend();
    _initSocket();
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

  bool               get isLoaded     => _loaded;
  List<Transaction>  get transactions => List.unmodifiable(_transactions);

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
    _transactions.insert(0, transaction);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      await http.post(
        Uri.parse('$_baseUrl/transactions/$_username'),
        headers: headers,
        body: jsonEncode(transaction.toJson()),
      ).timeout(const Duration(seconds: 60));
    } catch (e) {
      // Error handled silently
    }
  }

  Future<void> removeTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      await http.delete(
        Uri.parse('$_baseUrl/transactions/$_username/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));
    } catch (e) {
      // Error handled
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('note_${transaction.id}', transaction.note);

    final idx = _transactions.indexWhere((t) => t.id == transaction.id);
    if (idx != -1) {
      _transactions[idx] = transaction;
      notifyListeners();
    }

    try {
      final headers = await ApiConfig.getHeaders();
      await http.put(
        Uri.parse('$_baseUrl/transactions/$_username/${transaction.id}'),
        headers: headers,
        body: jsonEncode(transaction.toJson()),
      ).timeout(const Duration(seconds: 60));
      
      await _loadFromBackend();
    } catch (e) {
      // Error handled
    }
  }

  Future<void> deleteTransaction(String id) async {
    _transactions.removeWhere((t) => t.id == id);
    notifyListeners();

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.delete(
        Uri.parse('$_baseUrl/transactions/$_username/$id'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        await _loadFromBackend();
      }
    } catch (e) {
      // Error handled
    }
  }
}
