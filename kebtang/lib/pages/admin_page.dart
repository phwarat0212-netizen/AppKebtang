import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../models/transaction.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/pdf_helper.dart';
import 'settings_page.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> with SingleTickerProviderStateMixin {
  String get _baseUrl => ApiConfig.baseUrl;
  bool _isLoading = true;
  List<dynamic> _transactions = [];
  List<dynamic> _users = [];
  Map<String, dynamic>? _globalStats;
  String? _error;
  int _selectedStatFilter = 3; 
  int _selectedTransFilter = 3; 

  final _searchUserCtrl = TextEditingController();
  String _searchUserQuery = '';
  final _searchTransCtrl = TextEditingController();
  String _searchTransQuery = '';
  Timer? _searchUserDebounce;
  Timer? _searchTransDebounce;
  
  int _transPage = 1;
  bool _transHasMore = true;
  bool _transIsFetchingMore = false;
  final _transScrollCtrl = ScrollController();

  int _userPage = 1;
  bool _userHasMore = true;
  bool _userIsFetchingMore = false;
  final _userScrollCtrl = ScrollController();

  late TabController _tabController;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); 
    _fetchAdminData();
    _initSocket();
    _searchUserCtrl.addListener(_onSearchUserChanged);
    _searchTransCtrl.addListener(_onSearchTransChanged);
    _transScrollCtrl.addListener(() {
      if (_transScrollCtrl.position.pixels >= _transScrollCtrl.position.maxScrollExtent - 200) {
        if (_transHasMore && !_transIsFetchingMore && _selectedTransFilter == 3) _fetchMoreTransactions();
      }
    });
    _userScrollCtrl.addListener(() {
      if (_userScrollCtrl.position.pixels >= _userScrollCtrl.position.maxScrollExtent - 200) {
        if (_userHasMore && !_userIsFetchingMore) _fetchMoreUsers();
      }
    });
  }

  void _onSearchUserChanged() {
    if (_searchUserDebounce?.isActive ?? false) _searchUserDebounce?.cancel();
    _searchUserDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchUserCtrl.text.trim().toLowerCase();
      if (_searchUserQuery != query) {
        setState(() => _searchUserQuery = query);
        _fetchInitialUsers();
      }
    });
  }

  void _onSearchTransChanged() {
    if (_searchTransDebounce?.isActive ?? false) _searchTransDebounce?.cancel();
    _searchTransDebounce = Timer(const Duration(milliseconds: 500), () {
      final query = _searchTransCtrl.text.trim().toLowerCase();
      if (_searchTransQuery != query) {
        setState(() => _searchTransQuery = query);
        _fetchAdminData();
      }
    });
  }

  void _initSocket() {
    _socket = io.io(ApiConfig.socketUrl, io.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());
    _socket?.connect();
    _socket?.on('data_changed', (_) { if (mounted) _fetchAdminData(); });
  }

  @override
  void dispose() {
    _socket?.disconnect(); _socket?.dispose(); _tabController.dispose();
    _searchUserCtrl.dispose(); _searchTransCtrl.dispose(); _transScrollCtrl.dispose(); _userScrollCtrl.dispose();
    _searchUserDebounce?.cancel(); _searchTransDebounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAdminData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; _transPage = 1; _transHasMore = true; _userPage = 1; _userHasMore = true; });
    try {
      final headers = await ApiConfig.getHeaders();
      final urlTrans = '$_baseUrl/admin/transactions?page=1&limit=100&search=${Uri.encodeComponent(_searchTransQuery)}';
      final urlUsers = '$_baseUrl/admin/users?page=1&limit=50&search=${Uri.encodeComponent(_searchUserQuery)}';
      final urlStats = '$_baseUrl/admin/stats';

      final transRes = await http.get(Uri.parse(urlTrans), headers: headers);
      final usersRes = await http.get(Uri.parse(urlUsers), headers: headers);
      final statsRes = await http.get(Uri.parse(urlStats), headers: headers);

      if (ApiConfig.handleAuthError(transRes) || ApiConfig.handleAuthError(usersRes)) {
        if (mounted) setState(() => _isLoading = false); return;
      }

      if (transRes.statusCode == 200 && usersRes.statusCode == 200) {
        final transData = jsonDecode(transRes.body);
        final usersData = jsonDecode(usersRes.body);
        
        Map<String, dynamic>? statsData;
        if (statsRes.statusCode == 200) {
          statsData = jsonDecode(statsRes.body);
        }

        if (mounted) {
          setState(() { 
            _transactions = transData['transactions']; 
            _transHasMore = transData['metadata']['hasMore'] ?? false; 
            _users = usersData['users']; 
            _userHasMore = usersData['metadata']['hasMore'] ?? false; 
            _globalStats = statsData;
            _isLoading = false; 
          });
        }
      } else { if (mounted) setState(() => _isLoading = false); }
    } catch (e) { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _fetchInitialUsers() async {
    setState(() { _userPage = 1; _userHasMore = true; });
    try {
      final headers = await ApiConfig.getHeaders();
      final url = '$_baseUrl/admin/users?page=1&limit=50&search=${Uri.encodeComponent(_searchUserQuery)}';
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _users = data['users']; _userHasMore = data['metadata']['hasMore'] ?? false; });
      }
    } catch (e) { }
  }

  Future<void> _fetchMoreUsers() async {
    if (_userIsFetchingMore || !_userHasMore) return;
    setState(() => _userIsFetchingMore = true);
    try {
      _userPage++;
      final headers = await ApiConfig.getHeaders();
      final url = '$_baseUrl/admin/users?page=$_userPage&limit=50&search=${Uri.encodeComponent(_searchUserQuery)}';
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() { _users.addAll(data['users']); _userHasMore = data['metadata']['hasMore'] ?? false; });
      }
    } catch (e) { _userHasMore = false; } finally { setState(() => _userIsFetchingMore = false); }
  }

  Future<void> _fetchMoreTransactions() async {
    if (_transIsFetchingMore || !_transHasMore) return;
    setState(() => _transIsFetchingMore = true);
    try {
      _transPage++;
      final headers = await ApiConfig.getHeaders();
      final url = '$_baseUrl/admin/transactions?page=$_transPage&limit=100&search=${Uri.encodeComponent(_searchTransQuery)}';
      final res = await http.get(Uri.parse(url), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() { _transactions.addAll(data['transactions']); _transHasMore = data['metadata']['hasMore'] ?? false; });
      }
    } catch (e) { _transHasMore = false; } finally { if (mounted) setState(() => _transIsFetchingMore = false); }
  }

  Future<void> _updateUserRole(String username, String role) async {
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.put(Uri.parse('$_baseUrl/admin/users/$username/role'), headers: headers, body: jsonEncode({'role': role}));
      if (res.statusCode == 200) {
        _fetchInitialUsers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Provider.of<LanguageState>(context, listen: false).t('save_success')), backgroundColor: kAccentGreen));
      }
    } catch (e) { }
  }

  void _showExportOptions(BuildContext context, List<dynamic> data, LanguageState lang) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(lang.t('export'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20), ListTile(leading: const Icon(Icons.table_chart_rounded, color: kAccentGreen), title: Text(lang.t('export_csv')), onTap: () { Navigator.pop(ctx); _exportCSV(context, data, lang); }), ListTile(leading: const Icon(Icons.picture_as_pdf_rounded, color: kAccentRed), title: Text(lang.t('export_pdf')), onTap: () { Navigator.pop(ctx); _exportPDF(context, data, lang); }), const SizedBox(height: 16)])));
  }

  Future<void> _exportCSV(BuildContext context, List<dynamic> data, LanguageState lang) async {
    if (data.isEmpty) return;
    try {
      final csv = generateCsv(data, lang);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/kebtang_admin_report.csv';
      await File(path).writeAsString(csv);
      await Share.shareXFiles([XFile(path)], text: lang.t('export_csv'));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Error: $e'), backgroundColor: kAccentRed)); }
  }

  Future<void> _exportPDF(BuildContext context, List<dynamic> data, LanguageState lang) async {
    if (data.isEmpty) return;
    try {
      final models = data.map((t) => Transaction(id: t['id'], title: t['title'], amount: (t['amount'] as num).toDouble(), isIncome: t['isIncome'] == true, date: DateTime.tryParse(t['date'] ?? '') ?? DateTime.now(), category: t['category'] ?? '', note: t['note'] ?? '')).toList();
      final pdfBytes = await PdfHelper.generateTransactionReport(models, lang, 'Admin', []);
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/kebtang_admin_report.pdf';
      await File(path).writeAsBytes(pdfBytes);
      await Share.shareXFiles([XFile(path)], text: lang.t('export_pdf'));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export Error: $e'), backgroundColor: kAccentRed)); }
  }

  Future<void> _deleteUser(String username) async {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final target = _users.firstWhere((u) => u['username'] == username, orElse: () => <String, dynamic>{});
    if (target['role'] == 'admin') return;
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCard, title: Text(langState.t('confirm_delete'), style: const TextStyle(color: kTextPrimary)), content: Text('${langState.t('delete_question')} ($username)', style: const TextStyle(color: kTextSecondary)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(langState.t('cancel'), style: const TextStyle(color: kTextSecondary))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(langState.t('delete_item'), style: const TextStyle(color: kAccentRed)))]));
    if (confirm != true) return;
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.delete(Uri.parse('$_baseUrl/admin/users/$username'), headers: headers);
      if (res.statusCode == 200) _fetchAdminData();
    } catch (e) { }
  }

  Future<void> _deleteTransaction(String id) async {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCard, title: Text(langState.t('confirm_delete'), style: const TextStyle(color: kTextPrimary)), content: Text(langState.t('delete_question'), style: const TextStyle(color: kTextSecondary)), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(langState.t('cancel'), style: const TextStyle(color: kTextSecondary))), TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(langState.t('delete_item'), style: const TextStyle(color: kAccentRed)))]));
    if (confirm != true) return;
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.delete(Uri.parse('$_baseUrl/admin/transactions/$id'), headers: headers);
      if (res.statusCode == 200) _fetchAdminData();
    } catch (e) { }
  }

  void _editTransaction(dynamic t) {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final titleCtrl = TextEditingController(text: t['title']);
    final amountCtrl = TextEditingController(text: t['amount'].toString());
    final categoryCtrl = TextEditingController(text: t['category'] ?? '');
    bool isIncome = t['isIncome'] == true;
    String selectedDateStr = t['date'];
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (context, setStateDialog) => AlertDialog(backgroundColor: kCard, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), title: Row(children: [const Icon(Icons.edit_attributes_rounded, color: kAccentBlue), const SizedBox(width: 10), Text(langState.t('edit'), style: const TextStyle(color: kTextPrimary))]), content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [_buildAdminTextField(titleCtrl, langState.t('desc_label'), Icons.edit_note_rounded), _buildAdminTextField(amountCtrl, langState.t('amount_label'), Icons.payments_rounded, isNumber: true), _buildAdminTextField(categoryCtrl, langState.t('category'), Icons.category_rounded), const SizedBox(height: 16), InkWell(onTap: () async { final picked = await showDatePicker(context: context, initialDate: DateTime.tryParse(selectedDateStr) ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setStateDialog(() => selectedDateStr = picked.toIso8601String()); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: kCardLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: Row(children: [const Icon(Icons.calendar_today_rounded, size: 18, color: kTextSecondary), const SizedBox(width: 12), Text('${langState.t('today')}: ${selectedDateStr.split('T')[0]}', style: const TextStyle(color: kTextPrimary))]))), const SizedBox(height: 16), Row(children: [Expanded(child: _AdminTypeChip(label: langState.t('income'), selected: isIncome, color: kAccentGreen, onTap: () => setStateDialog(() => isIncome = true))), const SizedBox(width: 10), Expanded(child: _AdminTypeChip(label: langState.t('expense'), selected: !isIncome, color: kAccentRed, onTap: () => setStateDialog(() => isIncome = false)))])])), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langState.t('cancel'), style: const TextStyle(color: kTextSecondary))), ElevatedButton(onPressed: () async { try { final headers = await ApiConfig.getHeaders(); final res = await http.put(Uri.parse('$_baseUrl/admin/transactions/${t['id']}'), headers: headers, body: jsonEncode({'title': titleCtrl.text.trim(), 'amount': double.tryParse(amountCtrl.text) ?? 0, 'date': selectedDateStr, 'isIncome': isIncome, 'category': categoryCtrl.text.trim()})); if (res.statusCode == 200) { Navigator.pop(ctx); _fetchAdminData(); } } catch (e) {} }, style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(langState.t('save')))])));
  }

  Widget _buildAdminTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, maxLines: maxLines, keyboardType: isNumber ? TextInputType.number : TextInputType.text, style: const TextStyle(color: kTextPrimary, fontSize: 14), decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13), prefixIcon: Icon(icon, size: 18, color: kTextSecondary), filled: true, fillColor: kCardLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12))));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Scaffold(backgroundColor: isDark ? kBg : const Color(0xFFEDF2F7), appBar: AppBar(backgroundColor: isDark ? kCard : Colors.white, elevation: 0, title: Text(langState.t('admin_panel'), style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontWeight: FontWeight.bold)), iconTheme: IconThemeData(color: isDark ? kTextPrimary : const Color(0xFF1A202C)), actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _fetchAdminData)], bottom: TabBar(controller: _tabController, labelColor: kAccentBlue, unselectedLabelColor: isDark ? kTextSecondary : const Color(0xFF718096), indicatorColor: kAccentBlue, indicatorWeight: 3, tabs: [Tab(icon: const Icon(Icons.people_alt_rounded), text: langState.t('users')), Tab(icon: const Icon(Icons.receipt_long_rounded), text: langState.t('history')), Tab(icon: const Icon(Icons.analytics_rounded), text: langState.t('stats')), Tab(icon: const Icon(Icons.settings_rounded), text: langState.t('settings'))])), body: _isLoading ? const Center(child: CircularProgressIndicator(color: kAccentGreen)) : RefreshIndicator(onRefresh: _fetchAdminData, color: kAccentGreen, child: TabBarView(controller: _tabController, children: [_buildUsersTab(), _buildTransactionsTab(), _buildStatsTab(), const SettingsPage(showAppBar: false)])));
  }

  Widget _buildUsersTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Column(children: [Padding(padding: const EdgeInsets.all(16), child: TextField(controller: _searchUserCtrl, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87), decoration: InputDecoration(hintText: langState.t('search_hint'), prefixIcon: const Icon(Icons.search_rounded), filled: true, fillColor: isDark ? kCard : Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)))), Expanded(child: _users.isEmpty ? Center(child: Text(langState.t('no_data'), style: const TextStyle(color: kTextSecondary))) : ListView.builder(controller: _userScrollCtrl, itemCount: _users.length + (_userHasMore ? 1 : 0), itemBuilder: (context, i) {
      if (i == _users.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      final u = _users[i]; final isAd = u['role'] == 'admin';
      return ListTile(
        leading: CircleAvatar(backgroundColor: (isAd ? kAccentBlue : (isDark ? kTextSecondary : Colors.grey[300]))!.withValues(alpha: 0.1), child: Icon(isAd ? Icons.admin_panel_settings : Icons.person, color: isAd ? kAccentBlue : (isDark ? kTextSecondary : Colors.grey[600]))),
        title: Text(u['username'], style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontWeight: FontWeight.bold)),
        subtitle: Text('${langState.t('role')}: ${u['role']}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (u['username'] != 'admin') IconButton(icon: Icon(isAd ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: kAccentBlue), onPressed: () => _updateUserRole(u['username'], isAd ? 'user' : 'admin'), tooltip: isAd ? langState.t('demote') : langState.t('promote')),
          if (!isAd) IconButton(icon: const Icon(Icons.delete_outline, color: kAccentRed), onPressed: () => _deleteUser(u['username'])),
        ]),
      );
    }))]);
  }

  Widget _buildTransactionsTab() {
    final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final monday = today.subtract(Duration(days: now.weekday - 1)); final firstOfMonth = DateTime(now.year, now.month, 1);
    final langState = Provider.of<LanguageState>(context);
    var filtered = _transactions.where((t) {
      final tDate = DateTime.tryParse(t['date']) ?? DateTime.now(); final compareDate = DateTime(tDate.year, tDate.month, tDate.day);
      if (_selectedTransFilter == 0) return compareDate.isAtSameMomentAs(today);
      if (_selectedTransFilter == 1) return compareDate.isAfter(monday.subtract(const Duration(seconds: 1)));
      if (_selectedTransFilter == 2) return compareDate.isAfter(firstOfMonth.subtract(const Duration(seconds: 1)));
      return true;
    }).toList();
    final income = filtered.where((t) => t['isIncome'] == true).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    final expense = filtered.where((t) => t['isIncome'] == false).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    return Column(children: [_buildTransFilterRow(), Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), child: Row(children: [Expanded(child: TextField(controller: _searchTransCtrl, style: const TextStyle(color: kTextPrimary, fontSize: 14), decoration: InputDecoration(hintText: langState.t('search_hint'), prefixIcon: const Icon(Icons.search_rounded, size: 20), filled: true, fillColor: kCard, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(vertical: 8)))), const SizedBox(width: 12), Container(decoration: BoxDecoration(color: kAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: IconButton(icon: const Icon(Icons.ios_share_rounded, color: kAccentBlue, size: 20), onPressed: () => _showExportOptions(context, filtered, langState), tooltip: langState.t('export')))])), _buildSummaryCards(income, expense), Expanded(child: filtered.isEmpty ? Center(child: Text(langState.t('no_data'), style: const TextStyle(color: kTextSecondary))) : ListView.builder(controller: _transScrollCtrl, padding: const EdgeInsets.only(bottom: 24), itemCount: filtered.length + (_transHasMore ? 1 : 0), itemBuilder: (context, index) {
      if (index == filtered.length) return const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
      final t = filtered[index]; final isIncome = t['isIncome'] == true; final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: (isIncome ? kAccentGreen : kAccentRed).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(CategoryIcons.getIcon(t['category'] ?? ''), color: isIncome ? kAccentGreen : kAccentRed)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t['title'] ?? '', style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontSize: 16, fontWeight: FontWeight.bold)), Text('${isIncome ? '+' : '-'}${t['amount']}', style: TextStyle(color: isIncome ? kAccentGreen : kAccentRed, fontSize: 16, fontWeight: FontWeight.bold))]), const SizedBox(height: 4), Row(children: [Icon(Icons.person_outline_rounded, size: 12, color: kAccentBlue.withValues(alpha: 0.7)), const SizedBox(width: 4), Text('${t['username']}', style: const TextStyle(color: kAccentBlue, fontSize: 12)), const SizedBox(width: 12), Icon(Icons.category_outlined, size: 12, color: kTextSecondary.withValues(alpha: 0.7)), const SizedBox(width: 4), Text(langState.t((t['category'] ?? 'other').toString().toLowerCase()), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12))]), if (t['note'] != null && t['note'].toString().isNotEmpty) ...[const SizedBox(height: 8), Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(8)), child: Text('${t['note']}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic)))], const SizedBox(height: 12), Row(children: [Text(formatDate(DateTime.tryParse(t['date']) ?? DateTime.now()), style: const TextStyle(color: kTextSecondary, fontSize: 11)), const Spacer(), _AdminActionButton(icon: Icons.edit_rounded, label: langState.t('edit'), color: kAccentBlue, onTap: () => _editTransaction(t)), const SizedBox(width: 8), _AdminActionButton(icon: Icons.delete_outline_rounded, label: langState.t('delete_item'), color: kAccentRed, onTap: () => _deleteTransaction(t['id']))])]))]));
    }))]);
  }

  Widget _buildTransFilterRow() { final isDark = Theme.of(context).brightness == Brightness.dark; final langState = Provider.of<LanguageState>(context); return Padding(padding: const EdgeInsets.fromLTRB(20, 16, 20, 0), child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: [_buildTransFilterChip(0, langState.t('today')), _buildTransFilterChip(1, langState.t('week')), _buildTransFilterChip(2, langState.t('month')), _buildTransFilterChip(3, langState.t('all'))]))); }
  Widget _buildTransFilterChip(int index, String label) { final isDark = Theme.of(context).brightness == Brightness.dark; final selected = _selectedTransFilter == index; return Expanded(child: GestureDetector(onTap: () => setState(() { _selectedTransFilter = index; if (index == 3) _fetchAdminData(); }), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: selected ? kAccentBlue : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : (isDark ? kTextSecondary : const Color(0xFF718096)), fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 12))))); }
  Widget _buildSummaryCards(double income, double expense) { final langState = Provider.of<LanguageState>(context); return Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 0), child: Row(children: [_buildSummaryItem(langState.t('income'), income, kAccentGreen), const SizedBox(width: 12), _buildSummaryItem(langState.t('expense'), expense, kAccentRed)])); }
  Widget _buildSummaryItem(String label, double amount, Color color) { return Builder(builder: (context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.1)), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: [Text(label, style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 11)), const SizedBox(height: 4), FittedBox(child: Text('฿${amount.toStringAsFixed(0)}', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)))]))); }); }
  
  Widget _buildStatsTab() { 
    final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final monday = today.subtract(Duration(days: now.weekday - 1)); final firstOfMonth = DateTime(now.year, now.month, 1); 
    final filteredTrans = _transactions.where((t) { final tDate = DateTime.tryParse(t['date']) ?? DateTime.now(); final compareDate = DateTime(tDate.year, tDate.month, tDate.day); if (_selectedStatFilter == 0) return compareDate.isAtSameMomentAs(today); if (_selectedStatFilter == 1) return compareDate.isAfter(monday.subtract(const Duration(seconds: 1))); if (_selectedStatFilter == 2) return compareDate.isAfter(firstOfMonth.subtract(const Duration(seconds: 1))); return true; }).toList(); 
    final income = filteredTrans.where((t) => t['isIncome'] == true).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()); 
    final expense = filteredTrans.where((t) => t['isIncome'] == false).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()); 
    final total = income + expense; 
    final isDark = Theme.of(context).brightness == Brightness.dark; 
    final langState = Provider.of<LanguageState>(context); 
    final titleStyle = TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontSize: 18, fontWeight: FontWeight.bold); 
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, 
        children: [
          if (_globalStats != null) _buildSystemHealthSection(langState, isDark),
          const SizedBox(height: 24),
          Text(langState.t('stats'), style: titleStyle.copyWith(fontSize: 16)), 
          const SizedBox(height: 12), 
          _buildStatFilterRow(), 
          const SizedBox(height: 24), 
          Text(langState.t('total_system'), style: titleStyle), 
          const SizedBox(height: 16), 
          _buildPieChartSection(income, expense, total), 
          const SizedBox(height: 32), 
          Text(langState.t('user_summary'), style: titleStyle), 
          const SizedBox(height: 16), 
          ..._users.where((u) => u['role'] != 'admin').map((u) => _buildUserStatCard(u, filteredTrans))
        ]
      )
    ); 
  }

  Widget _buildSystemHealthSection(LanguageState lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: isDark ? [kCard, Colors.black] : [kAccentBlue, const Color(0xFF2364AA)]),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _healthItem(lang.t('total_users').toUpperCase(), _globalStats!['totalUsers'].toString(), Icons.people_rounded),
              _healthItem(lang.t('total_trans').toUpperCase(), _globalStats!['totalTransactions'].toString(), Icons.receipt_long_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(lang.t('system_balance').toUpperCase(), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.bold)),
              Text('฿${formatNum((_globalStats!['totalBalance'] as num).toDouble())}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _healthItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 14),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildStatFilterRow() { final isDark = Theme.of(context).brightness == Brightness.dark; final langState = Provider.of<LanguageState>(context); return Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Row(children: [_buildFilterChip(0, langState.t('today')), _buildFilterChip(1, langState.t('week')), _buildFilterChip(2, langState.t('month')), _buildFilterChip(3, langState.t('all'))])); }
  Widget _buildFilterChip(int index, String label) { final isDark = Theme.of(context).brightness == Brightness.dark; final selected = _selectedStatFilter == index; return Expanded(child: GestureDetector(onTap: () => setState(() => _selectedStatFilter = index), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: selected ? kAccentBlue : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: selected ? Colors.white : (isDark ? kTextSecondary : const Color(0xFF718096)), fontWeight: selected ? FontWeight.bold : FontWeight.w500, fontSize: 12))))); }
  Widget _buildPieChartSection(double income, double expense, double total) { double inR = 0, exR = 0; if (total > 0) { inR = (income / total * 100); exR = (expense / total * 100); } final isDark = Theme.of(context).brightness == Brightness.dark; final langState = Provider.of<LanguageState>(context); return Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: [SizedBox(height: 200, child: total == 0 ? Center(child: Text(langState.t('no_data'), style: const TextStyle(color: kTextSecondary))) : PieChart(PieChartData(sectionsSpace: 4, centerSpaceRadius: 50, sections: [PieChartSectionData(value: inR, color: kAccentGreen, radius: 40, title: income > 0 ? '${inR.toStringAsFixed(1)}%' : '', titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)), PieChartSectionData(value: exR, color: kAccentRed, radius: 40, title: expense > 0 ? '${exR.toStringAsFixed(1)}%' : '', titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white))]))), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildChartIndicator(kAccentGreen, langState.t('income')), const SizedBox(width: 24), _buildChartIndicator(kAccentRed, langState.t('expense'))])])); }
  Widget _buildChartIndicator(Color color, String label) { return Builder(builder: (context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Row(children: [Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 8), Text(label, style: TextStyle(color: isDark ? kTextSecondary : const Color(0xFF4A5568), fontSize: 12, fontWeight: FontWeight.w500))]); }); }
  Widget _buildUserStatCard(dynamic u, List<dynamic> allFiltered) { final username = u['username']; final userTrans = allFiltered.where((t) => t['username'] == username); final uIncome = userTrans.where((t) => t['isIncome'] == true).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()); final uExpense = userTrans.where((t) => t['isIncome'] == false).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble()); final uBalance = uIncome - uExpense; final langState = Provider.of<LanguageState>(context); final isDark = Theme.of(context).brightness == Brightness.dark; return Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isDark ? kCard : Colors.white, borderRadius: BorderRadius.circular(24), boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: [Row(children: [CircleAvatar(backgroundColor: kAccentBlue.withValues(alpha: 0.1), child: const Icon(Icons.person_rounded, color: kAccentBlue, size: 20)), const SizedBox(width: 12), Text(username, style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), Text('฿${formatNum(uBalance)}', style: TextStyle(color: uBalance >= 0 ? kAccentGreen : kAccentRed, fontWeight: FontWeight.bold))]), const SizedBox(height: 16), Row(children: [_buildMiniStat(langState.t('income'), uIncome, kAccentGreen), const SizedBox(width: 12), _buildMiniStat(langState.t('expense'), uExpense, kAccentRed)])])); }
  Widget _buildMiniStat(String label, double amount, Color color) { return Builder(builder: (context) { final isDark = Theme.of(context).brightness == Brightness.dark; return Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), decoration: BoxDecoration(color: isDark ? kCardLight : const Color(0xFFF7FAFC), borderRadius: BorderRadius.circular(12), border: isDark ? null : Border.all(color: Colors.grey[200]!)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: isDark ? kTextSecondary : const Color(0xFF718096), fontSize: 10, fontWeight: FontWeight.bold)), Text('฿${formatNum(amount)}', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold))]))); }); }
}
class _AdminTypeChip extends StatelessWidget { final String label; final bool selected; final Color color; final VoidCallback onTap; const _AdminTypeChip({required this.label, required this.selected, required this.color, required this.onTap}); @override Widget build(BuildContext context) { return GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: selected ? color.withValues(alpha: 0.15) : kCardLight, borderRadius: BorderRadius.circular(10), border: Border.all(color: selected ? color : Colors.transparent)), child: Center(child: Text(label, style: TextStyle(color: selected ? color : kTextSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal))))); } }
class _AdminActionButton extends StatelessWidget { final IconData icon; final String label; final Color color; final VoidCallback onTap; const _AdminActionButton({required this.icon, required this.label, required this.color, required this.onTap}); @override Widget build(BuildContext context) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]))); } }
