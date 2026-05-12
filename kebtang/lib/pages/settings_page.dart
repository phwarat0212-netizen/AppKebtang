import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/theme_state.dart';
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';
import 'login_page.dart';

class SettingsPage extends StatelessWidget {
  final bool showAppBar;
  const SettingsPage({super.key, this.showAppBar = true});

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_user');
    await prefs.remove('user_role');
    await SecureTokenStorage.clear();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = Provider.of<ThemeState>(context);
    final langState = Provider.of<LanguageState>(context);
    final isDark = themeState.isDarkMode;

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(langState.t('language')),
        _buildLanguageTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('monthly_budget')),
        _buildBudgetTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('dark_mode')),
        _buildThemeTile(themeState, isDark, langState),
        const SizedBox(height: 24),
        _buildSection(langState.t('logout')),
        _buildLogoutTile(context, langState),
        const SizedBox(height: 24),
      ],
    );

    if (!showAppBar) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(langState.t('settings'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: content,
    );
  }

  Widget _buildBudgetTile(BuildContext context, LanguageState langState, bool isDark) {
    final appState = Provider.of<AppState>(context);
    final budget = appState.budget;

    return Card(
      elevation: 0,
      color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.account_balance_wallet_outlined, color: kAccentGreen),
        title: Text(langState.t('monthly_budget')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('฿${formatNum(budget)}', style: const TextStyle(color: kTextSecondary)),
            const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
          ],
        ),
        onTap: () => _showBudgetDialog(context, langState, appState, isDark),
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, LanguageState langState, AppState appState, bool isDark) {
    final ctrl = TextEditingController(text: appState.budget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(langState.t('set_budget'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              style: TextStyle(color: isDark ? kTextPrimary : Colors.black87),
              decoration: InputDecoration(
                hintText: langState.t('budget_hint'),
                prefixText: '฿ ',
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(langState.t('cancel'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0;
              appState.updateBudget(val);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(langState.t('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: kAccentGreen,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildThemeTile(ThemeState themeState, bool isDark, LanguageState langState) {
    return Card(
      elevation: 0,
      color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
          color: isDark ? Colors.amber : Colors.orange,
        ),
        title: Text(langState.t('dark_mode')),
        trailing: Switch(
          value: isDark,
          onChanged: (_) => themeState.toggleTheme(),
          activeThumbColor: kAccentGreen,
        ),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, LanguageState langState, bool isDark) {
    String langName = 'ไทย';
    if (langState.locale == 'en') langName = 'English';
    if (langState.locale == 'zh') langName = '中文';

    return Card(
      elevation: 0,
      color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.language_rounded, color: kAccentBlue),
        title: Text(langState.t('language')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(langName, style: const TextStyle(color: kTextSecondary)),
            const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
          ],
        ),
        onTap: () => _showLanguagePicker(context, langState),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageState langState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(langState.t('language'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _langItem(context, langState, 'th', 'ไทย', '🇹🇭'),
            _langItem(context, langState, 'en', 'English', '🇺🇸'),
            _langItem(context, langState, 'zh', '中文', '🇨🇳'),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _langItem(BuildContext context, LanguageState langState, String code, String name, String flag) {
    final selected = langState.locale == code;
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(name, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
      trailing: selected ? const Icon(Icons.check_circle_rounded, color: kAccentGreen) : null,
      onTap: () {
        langState.setLanguage(code);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildLogoutTile(BuildContext context, LanguageState langState) {
    final isDark = Provider.of<ThemeState>(context).isDarkMode;
    return Card(
      elevation: 0,
      color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: kAccentRed),
        title: Text(langState.t('logout'), style: const TextStyle(color: kAccentRed)),
        onTap: () => _showLogoutDialog(context, langState),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, LanguageState langState) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(langState.t('logout')),
        content: Text('${langState.t('logout')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langState.t('cancel'))),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logout(context);
            },
            child: Text(langState.t('logout'), style: const TextStyle(color: kAccentRed)),
          ),
        ],
      ),
    );
  }
}
