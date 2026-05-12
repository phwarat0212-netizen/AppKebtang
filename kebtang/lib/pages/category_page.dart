import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';

class CategoryManagementPage extends StatefulWidget {
  final AppState appState;
  const CategoryManagementPage({super.key, required this.appState});

  @override
  State<CategoryManagementPage> createState() => _CategoryManagementPageState();
}

class _CategoryManagementPageState extends State<CategoryManagementPage> {
  late List<String> _incomeCats;
  late List<String> _expenseCats;
  bool _isIncome = true;

  @override
  void initState() {
    super.initState();
    _incomeCats = List.from(widget.appState.incomeCategories);
    _expenseCats = List.from(widget.appState.expenseCategories);
  }

  void _addCategory() {
    final lang = Provider.of<LanguageState>(context, listen: false);
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${lang.t('add_income')} / ${lang.t('add_expense')}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(hintText: lang.t('category')),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('cancel'))),
          TextButton(
            onPressed: () {
              final name = ctrl.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  if (_isIncome) {
                    if (!_incomeCats.contains(name)) _incomeCats.add(name);
                  } else {
                    if (!_expenseCats.contains(name)) _expenseCats.add(name);
                  }
                });
                _save();
              }
              Navigator.pop(ctx);
            },
            child: Text(lang.t('save')),
          ),
        ],
      ),
    );
  }

  void _deleteCategory(String name) {
    setState(() {
      if (_isIncome) _incomeCats.remove(name);
      else _expenseCats.remove(name);
    });
    _save();
  }

  void _save() {
    widget.appState.updateCategories(income: _incomeCats, expense: _expenseCats);
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentList = _isIncome ? _incomeCats : _expenseCats;
    final color = _isIncome ? kAccentGreen : kAccentRed;

    return Scaffold(
      backgroundColor: isDark ? kBg : const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(lang.t('category'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildToggle(lang, isDark),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: currentList.length,
              itemBuilder: (ctx, i) => _buildCategoryTile(currentList[i], color, isDark),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        backgroundColor: color,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildToggle(LanguageState lang, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? kCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _toggleItem(lang.t('income'), true, kAccentGreen),
            _toggleItem(lang.t('expense'), false, kAccentRed),
          ],
        ),
      ),
    );
  }

  Widget _toggleItem(String label, bool isIncome, Color color) {
    final sel = _isIncome == isIncome;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _isIncome = isIncome),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: sel ? Colors.white : kTextSecondary,
              fontWeight: sel ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTile(String name, Color color, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: ListTile(
        leading: Icon(Icons.circle, color: color, size: 12),
        title: Text(name, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87)),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline_rounded, color: kAccentRed, size: 20),
          onPressed: () => _deleteCategory(name),
        ),
      ),
    );
  }
}
