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
