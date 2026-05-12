import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../state/app_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../models/transaction.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/transaction_tile.dart';

// ─── History Tab ──────────────────────────────────────────────────

class HistoryTab extends StatefulWidget {
  final AppState appState;

  const HistoryTab({super.key, required this.appState});

  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  String _currentFilter = 'all'; // all, income, expense, range
  DateTimeRange? _selectedRange;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.appState.addListener(_refresh);
    _searchCtrl.addListener(_onSearchChanged);
    _scrollCtrl.addListener(_onScroll);
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      widget.appState.setFilters(search: _searchCtrl.text.trim());
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
      widget.appState.loadMore();
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    widget.appState.removeListener(_refresh);
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // Group transactions by date
  Map<String, List<Transaction>> _groupItems(List<Transaction> items) {
    final Map<String, List<Transaction>> grouped = {};
    for (var item in items) {
      final dateKey = formatDate(item.date); 
      if (grouped[dateKey] == null) grouped[dateKey] = [];
      grouped[dateKey]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupItems(widget.appState.transactions);
    final dateKeys = grouped.keys.toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => widget.appState.refreshData(),
        color: kAccentGreen,
        child: CustomScrollView(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchField()),
            SliverToBoxAdapter(child: _buildFilterChips()),
            if (_currentFilter == 'range' && _selectedRange != null)
              SliverToBoxAdapter(child: _buildRangeInfo()),
            
            // Grouped Slivers
            for (var dateKey in dateKeys) ...[
              SliverToBoxAdapter(child: _buildDateHeader(dateKey)),
              _buildGroupedList(grouped[dateKey]!),
            ],

            if (widget.appState.hasMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: Text(
        date,
        style: TextStyle(
          color: isDark ? kTextSecondary : Colors.grey[700],
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildGroupedList(List<Transaction> items) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            return Dismissible(
              key: Key(items[i].id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: kAccentRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_outline, color: kAccentRed),
              ),
              onDismissed: (_) => widget.appState.removeTransaction(items[i].id),
              child: TransactionTile(
                transaction: items[i],
                appState: widget.appState,
              ),
            );
          },
          childCount: items.length,
        ),
      ),
    );
  }

  Widget _buildRangeInfo() {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: kAccentBlue.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kAccentBlue.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.date_range_rounded, size: 18, color: kAccentBlue),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${formatDate(_selectedRange!.start)} - ${formatDate(_selectedRange!.end)}',
                style: const TextStyle(color: kAccentBlue, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() { _currentFilter = 'all'; _selectedRange = null; });
                widget.appState.setFilters(range: null);
              },
              child: const Icon(Icons.close_rounded, size: 18, color: kAccentBlue),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      helpText: langState.t('select_range'),
      saveText: langState.t('save'),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: kAccentBlue,
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: kAccentBlue,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _currentFilter = 'range';
        _selectedRange = picked;
      });
      widget.appState.setFilters(range: picked);
    }
  }

  Widget _buildSearchField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: TextField(
        controller: _searchCtrl,
        style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 14),
        decoration: InputDecoration(
          hintText: langState.t('search_hint'),
          hintStyle: TextStyle(color: isDark ? kTextSecondary : Colors.grey[400]),
          prefixIcon: Icon(Icons.search_rounded, color: isDark ? kTextSecondary : Colors.grey),
          suffixIcon: _searchCtrl.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 20),
                onPressed: () {
                  _searchCtrl.clear();
                  widget.appState.setFilters(search: '');
                },
              ) 
            : null,
          filled: true,
          fillColor: isDark ? kCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: isDark ? BorderSide.none : BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
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
      {'key': 'range', 'label': langState.t('select_range')},
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final selected = _currentFilter == f['key'];
            Color chipColor = kAccentBlue;
            if (f['key'] == 'income')  chipColor = kAccentGreen;
            if (f['key'] == 'expense') chipColor = kAccentRed;

            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () {
                  if (f['key'] == 'range') {
                    _pickRange();
                  } else {
                    setState(() {
                      _currentFilter = f['key']!;
                      _selectedRange = null;
                    });
                    widget.appState.setFilters(
                      type: f['key'] == 'all' ? null : f['key'],
                      range: null,
                    );
                  }
                },
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
                  ),
                  child: Row(
                    children: [
                      if (f['key'] == 'range') ...[
                        Icon(Icons.date_range_rounded, size: 14, color: selected ? chipColor : (isDark ? kTextSecondary : Colors.grey[600])),
                        const SizedBox(width: 6),
                      ],
                      Text(f['label']!,
                        style: TextStyle(
                          color: selected ? chipColor : (isDark ? kTextSecondary : Colors.grey[600]),
                          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
