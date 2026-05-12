import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/biometric_service.dart';

class TransactionTile extends StatefulWidget {
  final Transaction transaction;
  final AppState appState;
  final bool showDivider;

  const TransactionTile({
    super.key,
    required this.transaction,
    required this.appState,
    this.showDivider = false,
  });

  @override
  State<TransactionTile> createState() => _TransactionTileState();
}

class _TransactionTileState extends State<TransactionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragExtent = 0.0;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.primaryDelta!;
      double maxDrag = MediaQuery.of(context).size.width * 0.60;
      if (_dragExtent > maxDrag) _dragExtent = maxDrag;
      if (_dragExtent < -maxDrag) _dragExtent = -maxDrag;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    double threshold = MediaQuery.of(context).size.width * 0.4;
    if (_dragExtent > threshold) {
      _showEditDialog();
    } else if (_dragExtent < -threshold) {
      _showDeleteConfirm();
    }
    _reset();
  }

  void _reset() {
    Animation<double> animation = Tween<double>(
      begin: _dragExtent,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    animation.addListener(() => setState(() => _dragExtent = animation.value));
    _controller.forward(from: 0.0);
  }

  void _showDeleteConfirm() async {
    final langState = Provider.of<LanguageState>(context, listen: false);

    // SECURITY CHECK: Re-authenticate for Delete
    final bioEnabled = await BiometricService.isEnabled();
    if (bioEnabled) {
      final auth = await BiometricService.authenticate(langState.t('auth_sensitive'));
      if (!auth) return;
    }

    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(langState.t('confirm_delete'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(langState.t('delete_question')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(langState.t('cancel'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(langState.t('delete_item'), style: const TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await widget.appState.deleteTransaction(widget.transaction.id);
    }
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _TransactionEditDialog(
        transaction: widget.transaction,
        appState: widget.appState,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isIncome = widget.transaction.isIncome;
    final color = isIncome ? kAccentGreen : kAccentRed;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: _dragExtent > 0 ? kAccentBlue.withValues(alpha: 0.9) : kAccentRed.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: _dragExtent > 0 ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: [
                  if (_dragExtent > 0) ...[
                    const Padding(padding: EdgeInsets.only(left: 20), child: Icon(Icons.edit_rounded, color: Colors.white)),
                  ] else ...[
                    const Padding(padding: EdgeInsets.only(right: 20), child: Icon(Icons.delete_outline_rounded, color: Colors.white)),
                  ],
                ],
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: Transform.translate(
              offset: Offset(_dragExtent, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? kCard : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: _dragExtent.abs() > 0 ? 0.1 : 0.04), blurRadius: 8, offset: const Offset(0, 2))
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48, height: 48,
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
                      child: Icon(CategoryIcons.getIcon(widget.transaction.category), color: color, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.transaction.title, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('${langState.t(widget.transaction.category.toLowerCase())} • ${formatRelativeDate(widget.transaction.date, langState)}', style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${isIncome ? '+' : '-'}฿${formatNum(widget.transaction.amount)}', style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionEditDialog extends StatefulWidget {
  final Transaction transaction;
  final AppState appState;
  const _TransactionEditDialog({required this.transaction, required this.appState});

  @override
  State<_TransactionEditDialog> createState() => _TransactionEditDialogState();
}

class _TransactionEditDialogState extends State<_TransactionEditDialog> {
  late TextEditingController _titleCtrl;
  late TextEditingController _amountCtrl;
  late TextEditingController _noteCtrl;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  final _incomeCategories  = ['salary', 'freelance', 'bonus', 'investment', 'other'];
  final _expenseCategories = ['food', 'travel', 'shopping', 'bill', 'entertainment', 'health', 'other'];
  List<String> get _categories => widget.transaction.isIncome ? _incomeCategories : _expenseCategories;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.transaction.title);
    _amountCtrl = TextEditingController(text: widget.transaction.amount.toString());
    _noteCtrl = TextEditingController(text: widget.transaction.note);
    _selectedCategory = widget.transaction.category;
    _selectedDate = widget.transaction.date;
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _amountCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    if (title.isEmpty || amount <= 0) return;

    setState(() => _isSaving = true);
    final updated = Transaction(
      id: widget.transaction.id,
      title: title,
      amount: amount,
      isIncome: widget.transaction.isIncome,
      date: _selectedDate,
      category: _selectedCategory,
      note: _noteCtrl.text,
    );
    await widget.appState.updateTransaction(updated);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.transaction.isIncome ? kAccentGreen : kAccentRed;

    return AlertDialog(
      backgroundColor: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
              child: Row(
                children: [
                  Icon(Icons.edit_rounded, color: color),
                  const SizedBox(width: 12),
                  Text(langState.t('edit'), style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInput(langState.t('desc_label'), _titleCtrl, isDark),
                  const SizedBox(height: 12),
                  _buildInput(langState.t('amount_label'), _amountCtrl, isDark, isNumber: true),
                  const SizedBox(height: 12),
                  _buildInput(langState.t('note'), _noteCtrl, isDark),
                  const SizedBox(height: 16),
                  Text(langState.t('category'), style: const TextStyle(color: kTextSecondary, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _categories.map((c) {
                      final sel = c == _selectedCategory;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCategory = c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: sel ? color.withValues(alpha: 0.2) : (isDark ? kBg : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: sel ? color : Colors.transparent),
                          ),
                          child: Text(langState.t(c), style: TextStyle(color: sel ? color : kTextSecondary, fontSize: 12)),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(langState.t('cancel'), style: const TextStyle(color: kTextSecondary))),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                    child: _isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(langState.t('save')),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, bool isDark, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : [],
          style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? kBg : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
