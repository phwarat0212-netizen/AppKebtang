import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../state/language_state.dart'; 
import '../utils/constants.dart';
import '../utils/helpers.dart';

// ─── Add Transaction Bottom Sheet ─────────────────────────────────

class AddTransactionSheet extends StatefulWidget {
  final bool     isIncome;
  final AppState appState;

  const AddTransactionSheet({
    super.key,
    required this.isIncome,
    required this.appState,
  });

  @override
  State<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<AddTransactionSheet> {
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl   = TextEditingController();
  String _selectedCategory = '';
  DateTime _selectedDate = DateTime.now();
  bool _isRecurring = false;
  String _frequency = 'none';

  List<String> get _categories => widget.isIncome ? widget.appState.incomeCategories : widget.appState.expenseCategories;

  @override
  void initState() {
    super.initState();
    if (_categories.isNotEmpty) {
      _selectedCategory = _categories.first;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final title  = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    
    if (title.isEmpty || amount <= 0) {
      final langState = Provider.of<LanguageState>(context, listen: false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(langState.t('fields_required')), 
          backgroundColor: kAccentRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    widget.appState.addTransaction(Transaction(
      id      : DateTime.now().millisecondsSinceEpoch.toString(),
      title   : title,
      amount  : amount,
      isIncome: widget.isIncome,
      date    : _selectedDate,
      category: _selectedCategory,
      note    : _noteCtrl.text,
      isRecurring: _isRecurring,
      frequency: _isRecurring ? _frequency : 'none',
    ));

    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: widget.isIncome ? kAccentGreen : kAccentRed,
              brightness: isDark ? Brightness.dark : Brightness.light,
              primary: widget.isIncome ? kAccentGreen : kAccentRed,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final color = widget.isIncome ? kAccentGreen : kAccentRed;
    final label = widget.isIncome ? langState.t('add_income') : langState.t('add_expense');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: kTextSecondary.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                    child: Icon(widget.isIncome ? Icons.add_rounded : Icons.remove_rounded, color: color),
                  ),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 20, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: color),
                          const SizedBox(width: 8),
                          Text(formatDate(_selectedDate), style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildInput(context, controller: _titleCtrl, label: langState.t('desc_label'), hint: langState.t('desc_hint'), icon: Icons.edit_note_rounded),
              const SizedBox(height: 12),
              _buildInput(context, controller: _amountCtrl, label: '${langState.t('amount_label')} (${langState.t('baht')})', hint: '0.00', icon: Icons.attach_money_rounded, keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
              const SizedBox(height: 12),
              _buildInput(context, controller: _noteCtrl, label: langState.t('note_label'), hint: langState.t('note_hint'), icon: Icons.description_outlined),
              const SizedBox(height: 20),
              
              // Recurring Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.repeat_rounded, size: 20, color: isDark ? kTextSecondary : Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(langState.t('recurring'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (v) => setState(() => _isRecurring = v),
                    activeThumbColor: kAccentBlue,
                  ),
                ],
              ),
              if (_isRecurring) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['daily', 'weekly', 'monthly', 'yearly'].map((f) {
                      final sel = _frequency == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _frequency = f),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? kAccentBlue.withValues(alpha: 0.2) : (isDark ? kBg : Colors.grey[100]),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: sel ? kAccentBlue : Colors.transparent),
                            ),
                            child: Text(langState.t(f), style: TextStyle(color: sel ? kAccentBlue : kTextSecondary, fontSize: 12, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              Text(langState.t('category'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _categories.map((c) {
                  final sel = c == _selectedCategory;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCategory = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: sel ? color.withValues(alpha: 0.2) : (isDark ? kBg : Colors.grey[100]), borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? color : Colors.transparent)),
                      child: Text(langState.t(c.toLowerCase()), style: TextStyle(color: sel ? color : (isDark ? kTextSecondary : Colors.grey[600]), fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 0),
                  child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(BuildContext context, {required TextEditingController controller, required String label, required String hint, required IconData icon, TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters, bool obscureText = false, Widget? suffixIcon}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 13)), const SizedBox(height: 6), TextField(controller: controller, obscureText: obscureText, keyboardType: keyboardType, inputFormatters: inputFormatters, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 15), decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: isDark ? kTextSecondary.withValues(alpha: 0.5) : Colors.grey[400]), prefixIcon: Icon(icon, color: isDark ? kTextSecondary : Colors.grey, size: 20), suffixIcon: suffixIcon, filled: true, fillColor: isDark ? kBg : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)))]);
  }
}

// ─── Helper to open sheet ─────────────────────────────────────────
void showAddTransactionSheet(BuildContext context, {required AppState appState, required bool isIncome}) {
  showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => AddTransactionSheet(isIncome: isIncome, appState: appState));
}
