import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class RecurringPage extends StatefulWidget {
  final AppState appState;
  const RecurringPage({super.key, required this.appState});

  @override
  State<RecurringPage> createState() => _RecurringPageState();
}

class _RecurringPageState extends State<RecurringPage> {
  bool _isLoading = false;

  List<Transaction> get _recurringItems => widget.appState.transactions.where((t) => t.isRecurring).toList();

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? kBg : const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(langState.t('recurring') ?? 'Recurring', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _recurringItems.isEmpty
          ? _buildEmptyState(langState, isDark)
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _recurringItems.length,
              itemBuilder: (context, i) => _buildScheduleCard(_recurringItems[i], langState, isDark),
            ),
    );
  }

  Widget _buildEmptyState(LanguageState lang, bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 64, color: isDark ? kTextSecondary.withValues(alpha: 0.2) : Colors.grey[300]),
          const SizedBox(height: 16),
          Text(lang.t('no_data'), style: const TextStyle(color: kTextSecondary)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Transaction t, LanguageState lang, bool isDark) {
    final color = t.isIncome ? kAccentGreen : kAccentRed;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(CategoryIcons.getIcon(t.category), color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.title, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.event_repeat_rounded, size: 14, color: kAccentBlue),
                    const SizedBox(width: 6),
                    Text(lang.t(t.frequency), style: TextStyle(color: kAccentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    Text('฿${formatNum(t.amount)}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel_outlined, color: kAccentRed),
            onPressed: () => _cancelSchedule(t),
          ),
        ],
      ),
    );
  }

  void _cancelSchedule(Transaction t) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Schedule?'),
        content: const Text('This will stop future automatic entries for this item.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Stop Recurring', style: TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updated = Transaction(
        id: t.id, title: t.title, amount: t.amount, isIncome: t.isIncome,
        date: t.date, category: t.category, note: t.note,
        isRecurring: false, frequency: 'none'
      );
      await widget.appState.updateTransaction(updated);
    }
  }
}
