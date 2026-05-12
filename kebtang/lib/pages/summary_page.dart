import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/pdf_helper.dart';
import '../utils/biometric_service.dart';

// ─── Summary Page (หน้าสรุปข้อมูลสำหรับ Export) ─────────────────────

class SummaryPage extends StatefulWidget {
  final AppState appState;
  const SummaryPage({super.key, required this.appState});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final income = widget.appState.totalIncome;
    final expense = widget.appState.totalExpense;
    final balance = widget.appState.totalBalance;

    return Scaffold(
      backgroundColor: isDark ? kBg : const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(langState.t('summary'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFinancialOverview(langState, income, expense, balance, isDark),
            const SizedBox(height: 30),
            _buildMonthlyTrend(langState, isDark),
            const SizedBox(height: 30),
            _buildCategoryBreakdown(langState, isDark),
            const SizedBox(height: 40),
            _buildExportSection(langState, isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildFinancialOverview(LanguageState lang, double income, double expense, double balance, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          _overviewItem(lang.t('income'), income, kAccentGreen),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          _overviewItem(lang.t('expense'), expense, kAccentRed),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          _overviewItem(lang.t('balance'), balance, balance >= 0 ? kAccentBlue : kAccentRed),
        ],
      ),
    );
  }

  Widget _overviewItem(String label, double amount, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.bold)),
        Text('฿${formatNum(amount)}', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildMonthlyTrend(LanguageState lang, bool isDark) {
    final data = widget.appState.monthlyTrendData;
    if (data.isEmpty) return const SizedBox();

    final maxVal = data.map((e) => (e['amount'] as num).toDouble()).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.t('stats'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          height: 180,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? kCard : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: BarChart(
            BarChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                show: true,
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double val, TitleMeta meta) {
                      final i = val.toInt();
                      if (i < 0 || i >= data.length) return const SizedBox();
                      final monthStr = data[i]['month'].toString().split('-')[1]; // Get MM
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(monthStr, style: const TextStyle(color: kTextSecondary, fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(data.length, (i) {
                final amt = (data[i]['amount'] as num).toDouble();
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: amt == 0 ? 1 : amt,
                      color: kAccentBlue.withValues(alpha: 0.7),
                      width: 18,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown(LanguageState lang, bool isDark) {
    final transactions = widget.appState.transactions.where((t) => !t.isIncome).toList();
    final Map<String, double> categories = {};
    for (var t in transactions) {
      categories[t.category] = (categories[t.category] ?? 0) + t.amount;
    }
    final sorted = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final total = categories.values.fold(0.0, (s, v) => s + v);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.t('expense_by_category'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        if (sorted.isEmpty) Text(lang.t('no_data'), style: const TextStyle(color: kTextSecondary)),
        ...sorted.map((e) => _categoryItem(lang.t(e.key), e.value, total, isDark)),
      ],
    );
  }

  Widget _categoryItem(String label, double amount, double total, bool isDark) {
    final percent = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 14)),
              Text('฿${formatNum(amount)} (${(percent * 100).toStringAsFixed(1)}%)', style: const TextStyle(color: kTextSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 6,
              backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation<Color>(kAccentBlue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection(LanguageState lang, bool isDark) {
    return Column(
      children: [
        Text(lang.t('export'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: kTextSecondary)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _exportButton(lang.t('export_csv'), Icons.description_outlined, Colors.green, _exportCsv)),
            const SizedBox(width: 16),
            Expanded(child: _exportButton(lang.t('export_pdf'), Icons.picture_as_pdf_outlined, Colors.red, _exportPdf)),
          ],
        ),
      ],
    );
  }

  Widget _exportButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: _isExporting ? null : onTap,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  Future<void> _exportCsv() async {
    final lang = Provider.of<LanguageState>(context, listen: false);
    if (await BiometricService.isEnabled()) {
      if (!await BiometricService.authenticate(lang.t('auth_sensitive'))) return;
    }
    
    setState(() => _isExporting = true);
    try {
      final csv = generateCsv(widget.appState.transactions, lang);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kebtang_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(csv);
      
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: lang.t('export_csv'));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('connection_error')), backgroundColor: kAccentRed));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final lang = Provider.of<LanguageState>(context, listen: false);
    if (await BiometricService.isEnabled()) {
      if (!await BiometricService.authenticate(lang.t('auth_sensitive'))) return;
    }

    setState(() => _isExporting = true);
    try {
      final pdfBytes = await PdfHelper.generateTransactionReport(
        widget.appState.transactions,
        lang,
        widget.appState.username,
        widget.appState.monthlyTrendData,
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kebtang_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(pdfBytes);
      
      if (mounted) {
        await Share.shareXFiles([XFile(file.path)], text: lang.t('export_pdf'));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(lang.t('connection_error')), backgroundColor: kAccentRed));
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }
}
