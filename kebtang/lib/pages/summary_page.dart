import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../state/app_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';
import '../models/transaction.dart';
import '../utils/helpers.dart';

class SummaryPage extends StatefulWidget {
  final AppState appState;
  const SummaryPage({super.key, required this.appState});

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  int _selectedFilter = 0; // 0: Today, 1: Week, 2: Month

  @override
  Widget build(BuildContext context) {
    List<Transaction> transactions;
    String rangeText = '';
    final now = DateTime.now();
    final langState = Provider.of<LanguageState>(context);

    switch (_selectedFilter) {
      case 1:
        transactions = widget.appState.transactionsThisWeek;
        final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        final sunday = monday.add(const Duration(days: 6));
        rangeText = '${monday.day}/${monday.month}/${monday.year} - ${sunday.day}/${sunday.month}/${sunday.year}';
        break;
      case 2:
        transactions = widget.appState.transactionsThisMonth;
        final lastDay = DateTime(now.year, now.month + 1, 0).day;
        rangeText = '1/${now.month}/${now.year} - $lastDay/${now.month}/${now.year}';
        break;
      default:
        transactions = widget.appState.transactionsToday;
        rangeText = '${now.day}/${now.month}/${now.year}';
    }

    final income = widget.appState.getIncomeOf(transactions);
    final expense = widget.appState.getExpenseOf(transactions);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(langState.t('summary'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildFilterTabs(),
            const SizedBox(height: 16),
            Text(
              rangeText,
              style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 30),
            _buildChart(income, expense),
            const SizedBox(height: 40),
            _buildStatCards(income, expense),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _buildTabItem(0, langState.t('today')),
          _buildTabItem(1, langState.t('week')),
          _buildTabItem(2, langState.t('month')),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label) {
    final selected = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? kAccentGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : kTextSecondary,
              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChart(double income, double expense) {
    final total = income + expense;
    final langState = Provider.of<LanguageState>(context);
    if (total == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.pie_chart_outline_rounded, size: 48, color: kTextSecondary),
            const SizedBox(height: 12),
            Text(langState.t('no_data'), style: const TextStyle(color: kTextSecondary)),
          ],
        ),
      );
    }

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

    return SizedBox(
      height: 240,
      child: PieChart(
        PieChartData(
          sectionsSpace: 4,
          centerSpaceRadius: 60,
          sections: [
            PieChartSectionData(
              value: incomeRatio, // ใช้ Ratio ที่คำนวณแล้วแทนค่าจริง
              color: kAccentGreen,
              title: income > 0 ? '${incomeRatio.toStringAsFixed(1)}%' : '',
              radius: 50,
              titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
            PieChartSectionData(
              value: expenseRatio, // ใช้ Ratio ที่คำนวณแล้วแทนค่าจริง
              color: kAccentRed,
              title: expense > 0 ? '${expenseRatio.toStringAsFixed(1)}%' : '',
              radius: 50,
              titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards(double income, double expense) {
    final langState = Provider.of<LanguageState>(context);
    return Row(
      children: [
        _buildStatCard(langState.t('income'), income, kAccentGreen),
        const SizedBox(width: 16),
        _buildStatCard(langState.t('expense'), expense, kAccentRed),
      ],
    );
  }

  Widget _buildStatCard(String label, double amount, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? kCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                '฿${formatNum(amount)}',
                style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
