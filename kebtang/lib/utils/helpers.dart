import '../state/language_state.dart';

String formatNum(double n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) {
    final s = n.toStringAsFixed(0);
    final result = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if ((s.length - i) % 3 == 0 && i != 0) result.write(',');
      result.write(s[i]);
    }
    return result.toString();
  }
  return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
}

String formatDate(DateTime d) {
  // ฟังก์ชันเดิม (เก็บไว้รองรับโค้ดเก่า)
  return '${d.day}/${d.month}/${d.year + 543}';
}

String formatRelativeDate(DateTime d, LanguageState langState) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final dateToCompare = DateTime(d.year, d.month, d.day);

  // ตรวจสอบวันนี้/เมื่อวานก่อน
  if (dateToCompare == today) return langState.t('today');
  if (dateToCompare == yesterday) return langState.t('yesterday');
  
  // จัดรูปแบบตาม Locale
  switch (langState.locale) {
    case 'en':
      // US Format: MM/DD/YYYY
      return '${d.month}/${d.day}/${d.year}';
    case 'zh':
      // China Format: YYYY/MM/DD
      return '${d.year}/${d.month}/${d.day}';
    case 'th':
    default:
      // Thai Format: DD/MM/BBBB (Buddhist Year)
      return '${d.day}/${d.month}/${d.year + 543}';
  }
}

String generateCsv(List<dynamic> transactions, LanguageState lang) {
  final buffer = StringBuffer();
  // Header
  buffer.writeln('Date,Title,Category,Amount,Type,Recurring,Frequency,Note,User');
  for (final t in transactions) {
    // Check if it's Transaction model or dynamic map (from admin)
    final date     = t is Map ? (DateTime.tryParse(t['date'] ?? '') ?? DateTime.now()) : t.date;
    final title    = (t is Map ? t['title'] : t.title).toString().replaceAll(',', ';');
    final category = lang.t((t is Map ? t['category'] : t.category).toString().toLowerCase()).replaceAll(',', ';');
    final amount   = t is Map ? t['amount'] : t.amount;
    final isIncome = t is Map ? t['isIncome'] == true : t.isIncome;
    final type     = isIncome ? lang.t('income') : lang.t('expense');
    
    final isRec    = t is Map ? t['isRecurring'] == true : t.isRecurring;
    final freq     = lang.t(t is Map ? (t['frequency'] ?? 'none') : t.frequency);
    
    final note     = (t is Map ? (t['note'] ?? '') : t.note).toString().replaceAll(',', ';');
    final user     = t is Map ? (t['username'] ?? '-') : '';

    buffer.writeln('${formatDate(date)},$title,$category,$amount,$type,${isRec ? "Yes" : "No"},$freq,$note,$user');
  }
  return buffer.toString();
}
