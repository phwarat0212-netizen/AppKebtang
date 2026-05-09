import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../state/app_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../models/transaction.dart';
import '../utils/constants.dart';
import '../widgets/transaction_tile.dart';

// ─── History Tab ──────────────────────────────────────────────────

class HistoryTab extends StatefulWidget {
  final AppState appState;

  const HistoryTab({super.key, required this.appState});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  String _filter = 'all'; // ใช้คีย์ภาษาอังกฤษเป็นค่าภายใน

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    super.dispose();
  }

  List<Transaction> get _filtered {
    if (_filter == 'income')  return widget.appState.transactions.where((t) =>  t.isIncome).toList();
    if (_filter == 'expense') return widget.appState.transactions.where((t) => !t.isIncome).toList();
    return widget.appState.transactions;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          _buildFilterChips(),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Row(
        children: [
          Text(langState.t('history'),
            style: TextStyle(
              color: isDark ? kTextPrimary : Colors.black87, 
              fontSize: 24, 
              fontWeight: FontWeight.bold
            )),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? kCard : Colors.white, 
              borderRadius: BorderRadius.circular(20),
              border: isDark ? null : Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Text(
              '${widget.appState.transactions.length} ${langState.t('items')}',
              style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final langState = Provider.of<LanguageState>(context);
    final filters = [
      {'key': 'all', 'label': langState.t('all')},
      {'key': 'income', 'label': langState.t('income')},
      {'key': 'expense', 'label': langState.t('expense')},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f['key'];
          Color chipColor = kAccentBlue;
          if (f['key'] == 'income')  chipColor = kAccentGreen;
          if (f['key'] == 'expense') chipColor = kAccentRed;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => _filter = f['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? chipColor.withValues(alpha: 0.2) : (isDark ? kCard : Colors.white),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? chipColor : (isDark ? Colors.transparent : Colors.grey.withValues(alpha: 0.2)), 
                    width: 1.5
                  ),
                  boxShadow: (!selected && !isDark) ? [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2))
                  ] : [],
                ),
                child: Text(f['label']!,
                  style: TextStyle(
                    color: selected ? chipColor : (isDark ? kTextSecondary : Colors.grey[600]),
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  )),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList() {
    final items = _filtered;
    final langState = Provider.of<LanguageState>(context);
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long_outlined, color: kTextSecondary, size: 48),
            const SizedBox(height: 12),
            Text(langState.t('no_data'), style: const TextStyle(color: kTextSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      itemCount: items.length,
      itemBuilder: (context, i) {
        return Dismissible(
          key: Key(items[i].id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: kAccentRed.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_outline, color: kAccentRed),
          ),
          onDismissed: (_) => widget.appState.removeTransaction(items[i].id),
          child: TransactionTile(
            transaction: items[i],
            appState: widget.appState, // ส่ง appState ไปด้วย
          ),
        );
      },
    );
  }
}
