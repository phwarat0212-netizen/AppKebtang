import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';
import '../utils/helpers.dart';
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
  String? _error;
  int _selectedStatFilter = 3; // 0: Today, 1: Week, 2: Month, 3: All Time
  int _selectedTransFilter = 3; // 0: Today, 1: Week, 2: Month, 3: All Time


  late TabController _tabController;
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // เพิ่มเป็น 4 แท็บ (ผู้ใช้, รายการ, สถิติ, ตั้งค่า)
    _fetchAdminData();
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
      if (mounted) {
        _fetchAdminData();
      }
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdminData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final headers = await ApiConfig.getHeaders();
      final transRes = await http.get(
        Uri.parse('$_baseUrl/admin/transactions'),
        headers: headers,
      );
      final usersRes = await http.get(
        Uri.parse('$_baseUrl/admin/users'),
        headers: headers,
      );

      if (transRes.statusCode == 200 && usersRes.statusCode == 200) {
        setState(() {
          _transactions = jsonDecode(transRes.body);
          _users = jsonDecode(usersRes.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load data (Code: ${transRes.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteUser(String username) async {
    if (username == 'admin') return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('ยืนยันการลบ', style: TextStyle(color: kTextPrimary)),
        content: Text('คุณต้องการลบบัญชี $username และรายการเงินทั้งหมดของผู้ใช้นี้ใช่หรือไม่?', style: const TextStyle(color: kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก', style: TextStyle(color: kTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: kAccentRed))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.delete(
        Uri.parse('$_baseUrl/admin/users/$username'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        _fetchAdminData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _deleteTransaction(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('ยืนยันการลบ', style: TextStyle(color: kTextPrimary)),
        content: const Text('คุณต้องการลบรายการนี้ใช่หรือไม่?', style: TextStyle(color: kTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก', style: TextStyle(color: kTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ', style: TextStyle(color: kAccentRed))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.delete(
        Uri.parse('$_baseUrl/admin/transactions/$id'),
        headers: headers,
      );
      if (res.statusCode == 200) {
        _fetchAdminData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${res.body}')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _editTransaction(dynamic t) {
    final titleCtrl = TextEditingController(text: t['title']);
    final amountCtrl = TextEditingController(text: t['amount'].toString());
    final categoryCtrl = TextEditingController(text: t['category'] ?? '');
    bool isIncome = t['isIncome'] == true;
    String selectedDateStr = t['date'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: kCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.edit_attributes_rounded, color: kAccentBlue),
                  SizedBox(width: 10),
                  Text('จัดการข้อมูลรายการ', style: TextStyle(color: kTextPrimary)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAdminTextField(titleCtrl, 'รายละเอียดรายการ', Icons.edit_note_rounded),
                    _buildAdminTextField(amountCtrl, 'จำนวนเงิน', Icons.payments_rounded, isNumber: true),
                    _buildAdminTextField(categoryCtrl, 'หมวดหมู่', Icons.category_rounded),
                    // ลบช่องหมายเหตุออกตามคำขอ
                    const SizedBox(height: 16),
                    // Date Picker in Dialog
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.tryParse(selectedDateStr) ?? DateTime.now(),
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setStateDialog(() => selectedDateStr = picked.toIso8601String());
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kCardLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: kTextSecondary),
                            const SizedBox(width: 12),
                            Text(
                              'วันที่: ${selectedDateStr.split('T')[0]}',
                              style: const TextStyle(color: kTextPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _AdminTypeChip(
                            label: 'รายรับ',
                            selected: isIncome,
                            color: kAccentGreen,
                            onTap: () => setStateDialog(() => isIncome = true),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _AdminTypeChip(
                            label: 'รายจ่าย',
                            selected: !isIncome,
                            color: kAccentRed,
                            onTap: () => setStateDialog(() => isIncome = false),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('ยกเลิก', style: TextStyle(color: kTextSecondary))
                ),
                ElevatedButton(
                  onPressed: () async {
                    final newTitle = titleCtrl.text.trim();
                    final newAmount = double.tryParse(amountCtrl.text) ?? 0.0;
                    if (newTitle.isNotEmpty && newAmount > 0) {
                      Navigator.pop(ctx);
                      try {
                        final headers = await ApiConfig.getHeaders();
                        final res = await http.put(
                          Uri.parse('$_baseUrl/admin/transactions/${t['id']}'),
                          headers: headers,
                          body: jsonEncode({
                            'title': newTitle,
                            'amount': newAmount,
                            'date': selectedDateStr,
                            'isIncome': isIncome,
                            'category': categoryCtrl.text.trim(),
                            'note': t['note'] // ใช้ค่าเดิมจากยูส
                          }),
                        );
                        if (res.statusCode == 200) {
                          _fetchAdminData();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('อัปเดตข้อมูลสำเร็จ'), backgroundColor: kAccentGreen),
                          );
                        }
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kAccentBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('บันทึกการเปลี่ยนแปลง', style: TextStyle(fontWeight: FontWeight.bold))
                ),
              ],
            );
          }
        );
      }
    );
  }

  Widget _buildAdminTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(color: kTextPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kTextSecondary, fontSize: 13),
          prefixIcon: Icon(icon, size: 18, color: kTextSecondary),
          filled: true,
          fillColor: kCardLight,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    
    return Scaffold(
      backgroundColor: isDark ? kBg : const Color(0xFFEDF2F7),
      appBar: AppBar(
        backgroundColor: isDark ? kCard : Colors.white,
        elevation: 0,
        title: Text(langState.t('admin_panel'), 
          style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: isDark ? kTextPrimary : const Color(0xFF1A202C)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchAdminData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: kAccentBlue,
          unselectedLabelColor: isDark ? kTextSecondary : const Color(0xFF718096),
          indicatorColor: kAccentBlue,
          indicatorWeight: 3,
          tabs: [
            Tab(icon: const Icon(Icons.people_alt_rounded), text: langState.t('users')),
            Tab(icon: const Icon(Icons.receipt_long_rounded), text: langState.t('history')),
            Tab(icon: const Icon(Icons.analytics_rounded), text: langState.t('stats')),
            Tab(icon: const Icon(Icons.settings_rounded), text: langState.t('settings')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccentGreen))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: kAccentRed)))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildUsersTab(),
                    _buildTransactionsTab(),
                    _buildStatsTab(),
                    const SettingsPage(),
                  ],
                ),
    );
  }

  Widget _buildUsersTab() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, i) {
        final u = _users[i];
        final isAd = u['username'] == 'admin';
        final isDark = Theme.of(context).brightness == Brightness.dark;
        
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: (isAd ? kAccentBlue : (isDark ? kTextSecondary : Colors.grey[300]))!.withValues(alpha: 0.1),
            child: Icon(isAd ? Icons.admin_panel_settings : Icons.person, color: isAd ? kAccentBlue : (isDark ? kTextSecondary : Colors.grey[600])),
          ),
          title: Text(u['username'], style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontWeight: FontWeight.bold)),
          subtitle: isAd ? null : Text('ID: ${u['id'] ?? u['username']}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600])),
          trailing: isAd ? null : IconButton(
            icon: const Icon(Icons.delete_outline, color: kAccentRed),
            onPressed: () => _deleteUser(u['username']),
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final firstOfMonth = DateTime(now.year, now.month, 1);

    final filtered = _transactions.where((t) {
      final tDate = DateTime.tryParse(t['date']) ?? DateTime.now();
      final compareDate = DateTime(tDate.year, tDate.month, tDate.day);
      
      if (_selectedTransFilter == 0) return compareDate.isAtSameMomentAs(today);
      if (_selectedTransFilter == 1) return compareDate.isAfter(monday.subtract(const Duration(seconds: 1)));
      if (_selectedTransFilter == 2) return compareDate.isAfter(firstOfMonth.subtract(const Duration(seconds: 1)));
      return true;
    }).toList();

    final income = filtered.where((t) => t['isIncome'] == true).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    final expense = filtered.where((t) => t['isIncome'] == false).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());

    return Column(
      children: [
        _buildTransFilterRow(),
        _buildSummaryCards(income, expense),
        Expanded(
          child: filtered.isEmpty 
            ? const Center(child: Text('ไม่มีรายการในช่วงเวลานี้', style: TextStyle(color: kTextSecondary)))
            : ListView.builder(
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final t = filtered[index];
                  final isIncome = t['isIncome'] == true;
                  final isDark = Theme.of(context).brightness == Brightness.dark;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? kCard : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isDark ? [] : [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: (isIncome ? kAccentGreen : kAccentRed).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            color: isIncome ? kAccentGreen : kAccentRed,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(t['title'] ?? '', style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontSize: 16, fontWeight: FontWeight.bold)),
                                  Text(
                                    '${isIncome ? '+' : '-'}${t['amount']}',
                                    style: TextStyle(
                                      color: isIncome ? kAccentGreen : kAccentRed,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.person_outline_rounded, size: 12, color: kAccentBlue.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text('${t['username']}', style: const TextStyle(color: kAccentBlue, fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.category_outlined, size: 12, color: kTextSecondary.withValues(alpha: 0.7)),
                                  const SizedBox(width: 4),
                                  Text('${t['category'] ?? '-'}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12)),
                                ],
                              ),
                              if (t['note'] != null && t['note'].toString().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'หมายเหตุ: ${t['note']}',
                                    style: TextStyle(color: kTextSecondary.withValues(alpha: 0.8), fontSize: 11, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _AdminActionButton(
                                    icon: Icons.edit_rounded,
                                    label: 'แก้ไข',
                                    color: kAccentBlue,
                                    onTap: () => _editTransaction(t),
                                  ),
                                  const SizedBox(width: 12),
                                  _AdminActionButton(
                                    icon: Icons.delete_forever_rounded,
                                    label: 'ลบ',
                                    color: kAccentRed,
                                    onTap: () => _deleteTransaction(t['id']),
                                  ),
                                ],
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        ),
      ],
    );
  }

  Widget _buildTransFilterRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? kCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            _buildTransFilterChip(0, langState.t('today')),
            _buildTransFilterChip(1, langState.t('week')),
            _buildTransFilterChip(2, langState.t('month')),
            _buildTransFilterChip(3, langState.t('all')),
          ],
        ),
      ),
    );
  }

  Widget _buildTransFilterChip(int index, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedTransFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTransFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kAccentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : (isDark ? kTextSecondary : const Color(0xFF718096)),
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards(double income, double expense) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _buildSummaryItem('รายรับช่วงนี้', income, kAccentGreen),
          const SizedBox(width: 12),
          _buildSummaryItem('รายจ่ายช่วงนี้', expense, kAccentRed),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? kCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.1)),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              children: [
                Text(label, style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 11)),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    '฿${amount.toStringAsFixed(0)}',
                    style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatsTab() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: now.weekday - 1));
    final firstOfMonth = DateTime(now.year, now.month, 1);

    // Filter transactions based on selection
    final filteredTrans = _transactions.where((t) {
      final tDate = DateTime.tryParse(t['date']) ?? DateTime.now();
      final compareDate = DateTime(tDate.year, tDate.month, tDate.day);
      
      if (_selectedStatFilter == 0) return compareDate.isAtSameMomentAs(today);
      if (_selectedStatFilter == 1) return compareDate.isAfter(monday.subtract(const Duration(seconds: 1)));
      if (_selectedStatFilter == 2) return compareDate.isAfter(firstOfMonth.subtract(const Duration(seconds: 1)));
      return true; // All Time
    }).toList();

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
          ..._users.where((u) => u['username'] != 'admin').map((u) => _buildUserStatCard(u, filteredTrans)),
        ],
      ),
    );
  }

  Widget _buildStatFilterRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          _buildFilterChip(0, langState.t('today')),
          _buildFilterChip(1, langState.t('week')),
          _buildFilterChip(2, langState.t('month')),
          _buildFilterChip(3, langState.t('all')),
        ],
      ),
    );
  }

  Widget _buildFilterChip(int index, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _selectedStatFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedStatFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kAccentBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : (isDark ? kTextSecondary : const Color(0xFF718096)),
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPieChartSection(double income, double expense, double total) {
    // Normalize values to prevent chart crash with extreme differences
    double incomeRatio = 0;
    double expenseRatio = 0;
    
    if (total > 0) {
      if (income > 0 && (income / total * 100) < 0.1) {
        incomeRatio = 0.1;
        expenseRatio = 99.9;
      } else if (expense > 0 && (expense / total * 100) < 0.1) {
        expenseRatio = 0.1;
        incomeRatio = 99.9;
      } else {
        incomeRatio = (income / total * 100);
        expenseRatio = (expense / total * 100);
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white, 
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: total == 0 
              ? const Center(child: Text('ไม่มีข้อมูลในช่วงเวลานี้', style: TextStyle(color: kTextSecondary)))
              : PieChart(
                  PieChartData(
                    sectionsSpace: 4,
                    centerSpaceRadius: 50,
                    sections: [
                      PieChartSectionData(
                        value: incomeRatio,
                        color: kAccentGreen,
                        radius: 40,
                        title: income > 0 ? '${incomeRatio.toStringAsFixed(1)}%' : '',
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      PieChartSectionData(
                        value: expenseRatio,
                        color: kAccentRed,
                        radius: 40,
                        title: expense > 0 ? '${expenseRatio.toStringAsFixed(1)}%' : '',
                        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildChartIndicator(kAccentGreen, 'รายรับ'),
              const SizedBox(width: 24),
              _buildChartIndicator(kAccentRed, 'รายจ่าย'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartIndicator(Color color, String label) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: isDark ? kTextSecondary : const Color(0xFF4A5568), fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        );
      }
    );
  }

  Widget _buildUserStatCard(dynamic u, List<dynamic> allFiltered) {
    final username = u['username'];
    final userTrans = allFiltered.where((t) => t['username'] == username);
    final uIncome = userTrans.where((t) => t['isIncome'] == true).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    final uExpense = userTrans.where((t) => t['isIncome'] == false).fold(0.0, (s, t) => s + (t['amount'] as num).toDouble());
    final uBalance = uIncome - uExpense;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: kAccentBlue.withValues(alpha: 0.1),
                child: const Icon(Icons.person_rounded, color: kAccentBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(username, style: TextStyle(color: isDark ? kTextPrimary : const Color(0xFF1A202C), fontSize: 16, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '฿${formatNum(uBalance)}',
                style: TextStyle(color: uBalance >= 0 ? kAccentGreen : kAccentRed, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildMiniStat('รายรับ', uIncome, kAccentGreen),
              const SizedBox(width: 12),
              _buildMiniStat('รายจ่าย', uExpense, kAccentRed),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double amount, Color color) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? kCardLight : const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(12),
              border: isDark ? null : Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: isDark ? kTextSecondary : const Color(0xFF718096), fontSize: 10, fontWeight: FontWeight.bold)),
                Text('฿${formatNum(amount)}', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        );
      }
    );
  }
}

// ─── Admin Components ─────────────────────────────────────────────

class _AdminTypeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AdminTypeChip({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : kCardLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Colors.transparent),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(color: selected ? color : kTextSecondary, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
