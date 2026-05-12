import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/transaction.dart';
import '../utils/constants.dart';

// ─── App State (บันทึก/โหลดข้อมูลจาก Backend) ─────────────────────

class AppState extends ChangeNotifier {
  final String _username;
  String get _baseUrl => ApiConfig.baseUrl;
  String get username => _username;

  List<Transaction> _transactions = [];
  bool _loaded = false;
  String? _errorMessage;
  double _budget = 0;
  
  // Grand Totals from Server
  double _serverIncome = 0;
  double _serverExpense = 0;
  double _serverBalance = 0;
  List<double> _serverTrend = [0, 0, 0, 0, 0, 0, 0];
  List<Map<String, dynamic>> _monthlyTrend = [];
  
  // Custom Categories
  List<String> _incomeCats = ['salary', 'freelance', 'bonus', 'investment', 'other'];
  List<String> _expenseCats = ['food', 'travel', 'shopping', 'bill', 'entertainment', 'health', 'other'];
  
  // Pagination & Filter State
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  String _searchQuery = '';
  String? _typeFilter; // 'income', 'expense', or null
  DateTimeRange? _dateRange;
  final int _limit = 50;

  IO.Socket? _socket;

  AppState(this._username) {
    _loadFromCache(); 
    _loadFromBackend(); 
    _loadBudget();
    _fetchCategories();
    _initSocket();
  }

  // --- Caching Logic (Hive) ---
  void _loadFromCache() {
    try {
      final box = Hive.box('cache');
      final cachedJson = box.get('tx_$_username');
      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        _transactions = decoded.map((e) => Transaction.fromJson(e)).toList();
        
        _serverIncome = box.get('income_$_username') ?? 0.0;
        _serverExpense = box.get('expense_$_username') ?? 0.0;
        _serverBalance = box.get('balance_$_username') ?? 0.0;
        final trend = box.get('trend_$_username');
        if (trend != null) _serverTrend = List<double>.from(trend);
        
        final mTrend = box.get('mtrend_$_username');
        if (mTrend != null) _monthlyTrend = List<Map<String, dynamic>>.from(jsonDecode(mTrend));

        _loaded = true;
        notifyListeners();
      }
    } catch (e) { }
  }

  void _saveToCache() {
    try {
      final box = Hive.box('cache');
      final jsonStr = jsonEncode(_transactions.take(100).map((e) => e.toJson()).toList());
      box.put('tx_$_username', jsonStr);
      
      box.put('income_$_username', _serverIncome);
      box.put('expense_$_username', _serverExpense);
      box.put('balance_$_username', _serverBalance);
      box.put('trend_$_username', _serverTrend);
      box.put('mtrend_$_username', jsonEncode(_monthlyTrend));
    } catch (e) { }
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

  Future<void> _fetchCategories() async {
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.get(Uri.parse('$_baseUrl/user/categories'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _incomeCats = List<String>.from(data['income']);
        _expenseCats = List<String>.from(data['expense']);
        notifyListeners();
      }
    } catch (e) { }
  }

  Future<void> updateCategories({List<String>? income, List<String>? expense}) async {
    if (income != null) _incomeCats = income;
    if (expense != null) _expenseCats = expense;
    notifyListeners();
    try {
      final headers = await ApiConfig.getHeaders();
      await http.put(
        Uri.parse('$_baseUrl/user/categories'),
        headers: headers,
        body: jsonEncode({'income': _incomeCats, 'expense': _expenseCats}),
      );
    } catch (e) { }
  }

  void _initSocket() {
    _socket = IO.io(ApiConfig.socketUrl, IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    _socket?.connect();
    _socket?.on('data_changed', (_) { _loadFromBackend(); });
  }

  @override
  void dispose() {
    _socket?.disconnect(); _socket?.dispose(); super.dispose();
  }

  bool               get isLoaded       => _loaded;
  bool               get hasMore        => _hasMore;
  bool               get isFetchingMore => _isFetchingMore;
  List<Transaction>  get transactions   => List.unmodifiable(_transactions);
  String?            get errorMessage   => _errorMessage;
  double             get budget         => _budget;

  double get totalBalance => _serverBalance;
  double get totalIncome  => _serverIncome;
  double get totalExpense => _serverExpense;
  List<double> get weeklyExpenseData => _serverTrend;
  List<Map<String, dynamic>> get monthlyTrendData => _monthlyTrend;
  
  List<String> get incomeCategories => _incomeCats;
  List<String> get expenseCategories => _expenseCats;

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void setFilters({String? search, String? type, DateTimeRange? range}) {
    bool changed = false;
    if (search != null && _searchQuery != search) { _searchQuery = search; changed = true; }
    if (type != _typeFilter) { _typeFilter = type; changed = true; }
    if (range != _dateRange) { _dateRange = range; changed = true; }
    if (changed) _loadFromBackend();
  }

  Future<void> refreshData() async { await _loadFromBackend(); }

  Future<void> _loadFromBackend() async {
    _currentPage = 1; _hasMore = true;
    try {
      final headers = await ApiConfig.getHeaders();
      String url = '$_baseUrl/transactions/$_username?page=$_currentPage&limit=$_limit';
      if (_searchQuery.isNotEmpty) url += '&search=${Uri.encodeComponent(_searchQuery)}';
      if (_typeFilter == 'income') url += '&isIncome=true';
      if (_typeFilter == 'expense') url += '&isIncome=false';
      if (_dateRange != null) {
        url += '&startDate=${_dateRange!.start.toIso8601String()}&endDate=${_dateRange!.end.toIso8601String()}';
      }

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 60));
      if (ApiConfig.handleAuthError(response)) { _loaded = true; notifyListeners(); return; }

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> txList = data['transactions'];
        _transactions = txList.map((e) => Transaction.fromJson(e)).toList();
        _hasMore = data['metadata']['hasMore'] ?? false;
        
        final summary = data['metadata']['summary'];
        _serverIncome = (summary['income'] as num).toDouble();
        _serverExpense = (summary['expense'] as num).toDouble();
        _serverBalance = (summary['balance'] as num).toDouble();
        
        if (summary['trend'] != null) {
          _serverTrend = List<double>.from(summary['trend'].map((e) => (e as num).toDouble()));
        }
        
        if (summary['monthlyTrend'] != null) {
          _monthlyTrend = List<Map<String, dynamic>>.from(summary['monthlyTrend']);
        }

        if (_searchQuery.isEmpty && _typeFilter == null && _dateRange == null) _saveToCache(); 
      }
    } catch (e) { }
    _loaded = true;
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isFetchingMore) return;
    _isFetchingMore = true;
    notifyListeners();
    try {
      _currentPage++;
      final headers = await ApiConfig.getHeaders();
      String url = '$_baseUrl/transactions/$_username?page=$_currentPage&limit=$_limit';
      if (_searchQuery.isNotEmpty) url += '&search=${Uri.encodeComponent(_searchQuery)}';
      if (_typeFilter == 'income') url += '&isIncome=true';
      if (_typeFilter == 'expense') url += '&isIncome=false';
      if (_dateRange != null) {
        url += '&startDate=${_dateRange!.start.toIso8601String()}&endDate=${_dateRange!.end.toIso8601String()}';
      }
      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> txList = data['transactions'];
        _transactions.addAll(txList.map((e) => Transaction.fromJson(e)).toList());
        _hasMore = data['metadata']['hasMore'] ?? false;
      }
    } catch (e) { _hasMore = false; } finally { _isFetchingMore = false; notifyListeners(); }
  }

  // --- Actions ---
  Future<void> addTransaction(Transaction transaction) async {
    _errorMessage = null; _transactions.insert(0, transaction); notifyListeners();
    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.post(Uri.parse('$_baseUrl/transactions/$_username'), headers: headers, body: jsonEncode(transaction.toJson())).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200 || response.statusCode == 201) await _loadFromBackend();
      else { _errorMessage = 'error_network'; await _loadFromBackend(); }
    } catch (e) { _errorMessage = 'connection_error'; await _loadFromBackend(); }
  }

  Future<void> removeTransaction(String id) async {
    _errorMessage = null; final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final removed = _transactions[index]; _transactions.removeAt(index); notifyListeners();
    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.delete(Uri.parse('$_baseUrl/transactions/$_username/$id'), headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) await _loadFromBackend();
      else { _errorMessage = 'error_network'; _transactions.insert(index, removed); notifyListeners(); }
    } catch (e) { _errorMessage = 'connection_error'; _transactions.insert(index, removed); notifyListeners(); }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    _errorMessage = null; final idx = _transactions.indexWhere((t) => t.id == transaction.id);
    Transaction? old; if (idx != -1) { old = _transactions[idx]; _transactions[idx] = transaction; notifyListeners(); }
    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.put(Uri.parse('$_baseUrl/transactions/$_username/${transaction.id}'), headers: headers, body: jsonEncode(transaction.toJson())).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) await _loadFromBackend();
      else { _errorMessage = 'error_network'; if (idx != -1 && old != null) _transactions[idx] = old; notifyListeners(); }
    } catch (e) { _errorMessage = 'connection_error'; if (idx != -1 && old != null) _transactions[idx] = old; notifyListeners(); }
  }

  Future<void> deleteTransaction(String id) async {
    _errorMessage = null; final index = _transactions.indexWhere((t) => t.id == id);
    if (index == -1) return;
    final removed = _transactions[index]; _transactions.removeAt(index); notifyListeners();
    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.delete(Uri.parse('$_baseUrl/transactions/$_username/$id'), headers: headers).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) await _loadFromBackend();
      else { _errorMessage = 'error_network'; _transactions.insert(index, removed); notifyListeners(); }
    } catch (e) { _errorMessage = 'connection_error'; _transactions.insert(index, removed); notifyListeners(); }
  }
}
