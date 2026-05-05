import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../models/transaction.dart';
import '../state/app_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';
import '../utils/helpers.dart';

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
      // จำกัดการเลื่อนไว้ที่ 60% ของหน้าจอตามคำขอ
      double maxDrag = MediaQuery.of(context).size.width * 0.60;
      if (_dragExtent > maxDrag) _dragExtent = maxDrag;
      if (_dragExtent < -maxDrag) _dragExtent = -maxDrag;
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    double threshold = MediaQuery.of(context).size.width * 0.4;
    
    if (_dragExtent > threshold) {
      // เลื่อนขวาสำเร็จ -> เปิดหมายเหตุแล้วเด้งกลับ
      _showNoteDialog(context, Theme.of(context).brightness == Brightness.dark);
    } else if (_dragExtent < -threshold) {
      // เลื่อนซ้ายสำเร็จ -> ถามลบ
      _showDeleteConfirm();
    }
    
    // เด้งกลับที่เดิมเสมอ
    _reset();
  }

  void _reset() {
    Animation<double> animation = Tween<double>(
      begin: _dragExtent,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    animation.addListener(() {
      setState(() => _dragExtent = animation.value);
    });
    _controller.forward(from: 0.0);
  }

  void _showDeleteConfirm() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);
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
          // Background Layer (Stationary)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                final langState = Provider.of<LanguageState>(context);
                return Container(
                  decoration: BoxDecoration(
                    color: _dragExtent > 0 
                      ? kAccentBlue.withValues(alpha: 0.9) 
                      : kAccentRed.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: _dragExtent > 0 
                      ? MainAxisAlignment.start 
                      : MainAxisAlignment.end,
                    children: [
                      if (_dragExtent > 0) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note_rounded, color: Colors.white),
                              const SizedBox(width: 10),
                              Text(langState.t('note'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: Row(
                            children: [
                              Text(langState.t('delete_item'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 10),
                              const Icon(Icons.delete_outline_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }
            ),
          ),
          
          // Sliding Tile Layer
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
                    BoxShadow(
                      color: Colors.black.withValues(alpha: _dragExtent.abs() > 0 ? 0.1 : 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: color,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.transaction.title,
                            style: TextStyle(
                              color: isDark ? kTextPrimary : Colors.black87,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${langState.t(widget.transaction.category.toLowerCase())} • ${formatRelativeDate(widget.transaction.date, langState)}',
                            style: TextStyle(
                              color: isDark ? kTextSecondary : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? '+' : '-'}฿${formatNum(widget.transaction.amount)}',
                      style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteDialog(BuildContext context, bool isDark) {
    final color = widget.transaction.isIncome ? kAccentGreen : kAccentRed;
    showDialog(
      context: context,
      builder: (ctx) => _NoteEditDialog(
        transaction: widget.transaction,
        appState: widget.appState,
        isDark: isDark,
        color: color,
      ),
    );
  }
}

class _NoteEditDialog extends StatefulWidget {
  final Transaction transaction;
  final AppState appState;
  final bool isDark;
  final Color color;

  const _NoteEditDialog({
    required this.transaction,
    required this.appState,
    required this.isDark,
    required this.color,
  });

  @override
  State<_NoteEditDialog> createState() => _NoteEditDialogState();
}

class _NoteEditDialogState extends State<_NoteEditDialog> {
  late TextEditingController _ctrl;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.transaction.note);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = Transaction(
      id: widget.transaction.id,
      title: widget.transaction.title,
      amount: widget.transaction.amount,
      isIncome: widget.transaction.isIncome,
      date: widget.transaction.date,
      category: widget.transaction.category,
      note: _ctrl.text,
    );
    await widget.appState.updateTransaction(updated);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('อัปเดตหมายเหตุเรียบร้อย'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return AlertDialog(
      backgroundColor: widget.isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: EdgeInsets.zero,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
                      child: Icon(
                        widget.transaction.isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.transaction.isIncome ? '+' : '-'} ฿${formatNum(widget.transaction.amount)}',
                      style: TextStyle(color: widget.color, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow(Icons.edit_note_rounded, langState.t('summary'), widget.transaction.title, widget.isDark),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: _buildDetailRow(Icons.category_rounded, langState.t('stats'), langState.t(widget.transaction.category.toLowerCase()), widget.isDark)),
                      Expanded(child: _buildDetailRow(Icons.calendar_today_rounded, langState.t('today'), formatDate(widget.transaction.date), widget.isDark)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLabelRow(Icons.description_outlined, langState.t('note'), widget.isDark),
                      if (!_isEditing)
                        IconButton(
                          onPressed: () => setState(() => _isEditing = true),
                          icon: const Icon(Icons.edit_rounded, size: 20, color: kAccentBlue),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _ctrl,
                      maxLines: 3,
                      autofocus: true,
                      style: TextStyle(color: widget.isDark ? kTextPrimary : Colors.black87),
                      decoration: InputDecoration(
                        hintText: '${langState.t('note')}...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        filled: true,
                        fillColor: widget.isDark ? Colors.black26 : Colors.grey[100],
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                    )
                  else
                    Text(
                      widget.transaction.note.isEmpty ? '-' : widget.transaction.note,
                      style: TextStyle(
                        color: widget.isDark ? kTextPrimary : Colors.black87,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(langState.t('close'), style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                  ),
                  if (_isEditing) ...[
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(langState.t('save'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabelRow(icon, label, isDark),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 32),
          child: Text(
            value,
            style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelRow(IconData icon, String label, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 20, color: isDark ? kTextSecondary : Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}
