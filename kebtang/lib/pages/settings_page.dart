import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import '../state/theme_state.dart';
import '../state/language_state.dart';
import '../state/app_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/biometric_service.dart';
import 'login_page.dart';
import 'recurring_page.dart';
import 'profile_page.dart';
import 'category_page.dart';

class SettingsPage extends StatefulWidget {
  final bool showAppBar;
  const SettingsPage({super.key, this.showAppBar = true});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _initBiometric();
  }

  Future<void> _initBiometric() async {
    final avail = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = avail;
        _biometricEnabled = enabled;
      });
    }
  }

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

  Future<void> _deleteAccount(BuildContext context, LanguageState lang) async {
    final bioEnabled = await BiometricService.isEnabled();
    if (bioEnabled) {
      final auth = await BiometricService.authenticate(lang.t('auth_sensitive'));
      if (!auth) return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('delete_account')),
        content: Text(lang.t('delete_account_warning')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.t('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lang.t('delete_item'), style: const TextStyle(color: kAccentRed, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.delete(Uri.parse('${ApiConfig.baseUrl}/user'), headers: headers);
      if (res.statusCode == 200) { if (context.mounted) _logout(context); }
    } catch (e) { }
  }

  @override
  Widget build(BuildContext context) {
    final themeState = Provider.of<ThemeState>(context);
    final langState = Provider.of<LanguageState>(context);
    final appState = Provider.of<AppState>(context);
    final isDark = themeState.isDarkMode;

    final content = ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSection(langState.t('profile')),
        _buildProfileTile(context, langState, appState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('language')),
        _buildLanguageTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('category')),
        _buildCategoryTile(context, langState, appState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('monthly_budget')),
        _buildBudgetTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('recurring')),
        _buildRecurringTile(context, langState, appState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('security')),
        _buildPasswordTile(context, langState, isDark),
        if (_biometricAvailable) ...[
          const SizedBox(height: 8),
          _buildBiometricTile(context, langState, isDark),
        ],
        const SizedBox(height: 8),
        _buildClearCacheTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('dark_mode')),
        _buildThemeTile(themeState, isDark, langState),
        const SizedBox(height: 24),
        _buildSection(langState.t('privacy')),
        _buildDeleteAccountTile(context, langState, isDark),
        const SizedBox(height: 24),
        _buildSection(langState.t('logout')),
        _buildLogoutTile(context, langState),
        const SizedBox(height: 24),
      ],
    );

    if (!widget.showAppBar) return content;

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

  Widget _buildProfileTile(BuildContext context, LanguageState lang, AppState appState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.person_outline_rounded, color: kAccentBlue),
        title: Text(lang.t('profile')),
        subtitle: Text(appState.username, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfilePage(appState: appState))),
      ),
    );
  }

  Widget _buildCategoryTile(BuildContext context, LanguageState lang, AppState appState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.category_outlined, color: Colors.orange),
        title: Text(lang.t('category')),
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryManagementPage(appState: appState))),
      ),
    );
  }

  Widget _buildBudgetTile(BuildContext context, LanguageState langState, bool isDark) {
    final appState = Provider.of<AppState>(context);
    final budget = appState.budget;
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
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

  Widget _buildRecurringTile(BuildContext context, LanguageState lang, AppState appState, bool isDark) {
    final count = appState.transactions.where((t) => t.isRecurring).length;
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.repeat_rounded, color: kAccentBlue),
        title: Text(lang.t('recurring')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0) Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: kAccentBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Text('$count', style: const TextStyle(color: kAccentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
          ],
        ),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringPage(appState: appState))),
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
              controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87),
              decoration: InputDecoration(
                hintText: langState.t('budget_hint'), prefixText: '฿ ',
                filled: true, fillColor: isDark ? Colors.black26 : Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langState.t('cancel'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey))),
          ElevatedButton(
            onPressed: () { final val = double.tryParse(ctrl.text) ?? 0; appState.updateBudget(val); Navigator.pop(ctx); },
            style: ElevatedButton.styleFrom(backgroundColor: kAccentGreen, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(langState.t('save')),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordTile(BuildContext context, LanguageState langState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.lock_outline_rounded, color: kAccentBlue),
        title: Text(langState.t('change_password')),
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
        onTap: () => _showPasswordDialog(context, langState, isDark),
      ),
    );
  }

  void _showPasswordDialog(BuildContext context, LanguageState langState, bool isDark) {
    final oldCtrl = TextEditingController(); final newCtrl = TextEditingController(); final confirmCtrl = TextEditingController(); bool loading = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? kCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(langState.t('change_password'), style: const TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDialogField(oldCtrl, langState.t('old_password'), isDark),
                const SizedBox(height: 12),
                _buildDialogField(newCtrl, langState.t('new_password'), isDark),
                const SizedBox(height: 12),
                _buildDialogField(confirmCtrl, langState.t('confirm_new_password'), isDark),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: loading ? null : () => Navigator.pop(ctx), child: Text(langState.t('cancel'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey))),
            ElevatedButton(
              onPressed: loading ? null : () async {
                if (newCtrl.text != confirmCtrl.text) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(langState.t('passwords_not_match')), backgroundColor: kAccentRed)); return; }
                setDialogState(() => loading = true);
                try {
                  final headers = await ApiConfig.getHeaders();
                  final response = await http.put(Uri.parse('${ApiConfig.baseUrl}/user/password'), headers: headers, body: jsonEncode({'oldPassword': oldCtrl.text, 'newPassword': newCtrl.text}));
                  if (response.statusCode == 200) { if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(langState.t('password_changed')), backgroundColor: kAccentGreen)); } }
                  else { final data = jsonDecode(response.body); if (context.mounted) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['error'] ?? 'Error'), backgroundColor: kAccentRed)); } }
                } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(langState.t('connection_error')), backgroundColor: kAccentRed)); }
                finally { setDialogState(() => loading = false); }
              },
              style: ElevatedButton.styleFrom(backgroundColor: kAccentBlue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(langState.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricTile(BuildContext context, LanguageState langState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.fingerprint_rounded, color: kAccentGreen),
        title: Text(langState.t('biometric')),
        trailing: Switch(
          value: _biometricEnabled,
          onChanged: (val) async {
            if (val) {
              final auth = await BiometricService.authenticate(langState.t('auth_reason'));
              if (auth) { await BiometricService.setEnabled(true); setState(() => _biometricEnabled = true); }
            } else { await BiometricService.setEnabled(false); setState(() => _biometricEnabled = false); }
          },
          activeThumbColor: kAccentGreen,
        ),
      ),
    );
  }

  Widget _buildClearCacheTile(BuildContext context, LanguageState langState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.cleaning_services_rounded, color: Colors.orange),
        title: Text(langState.t('clear_cache')),
        trailing: const Icon(Icons.chevron_right_rounded, color: kTextSecondary),
        onTap: () => _showClearCacheConfirm(context, langState, isDark),
      ),
    );
  }

  void _showClearCacheConfirm(BuildContext context, LanguageState langState, bool isDark) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? kCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(langState.t('clear_cache'), style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${langState.t('clear_cache')}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langState.t('cancel'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey))),
          TextButton(
            onPressed: () async {
              final box = Hive.box('cache'); await box.clear();
              if (context.mounted) { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(langState.t('cache_cleared')), backgroundColor: kAccentGreen)); }
            },
            child: const Text('Clear', style: TextStyle(color: kAccentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteAccountTile(BuildContext context, LanguageState langState, bool isDark) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.person_remove_outlined, color: kAccentRed),
        title: Text(langState.t('delete_account'), style: const TextStyle(color: kAccentRed)),
        trailing: const Icon(Icons.chevron_right_rounded, color: kAccentRed),
        onTap: () => _deleteAccount(context, langState),
      ),
    );
  }

  Widget _buildDialogField(TextEditingController ctrl, String label, bool isDark) {
    return TextField(
      controller: ctrl, obscureText: true,
      style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 14),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: kTextSecondary, fontSize: 12), filled: true, fillColor: isDark ? Colors.black26 : Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
    );
  }

  Widget _buildSection(String title) {
    return Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title, style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold, fontSize: 14)));
  }

  Widget _buildThemeTile(ThemeState themeState, bool isDark, LanguageState langState) {
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, color: isDark ? Colors.amber : Colors.orange),
        title: Text(langState.t('dark_mode')),
        trailing: Switch(value: isDark, onChanged: (_) => themeState.toggleTheme(), activeThumbColor: kAccentGreen),
      ),
    );
  }

  Widget _buildLanguageTile(BuildContext context, LanguageState langState, bool isDark) {
    String langName = 'ไทย';
    if (langState.locale == 'en') langName = 'English';
    if (langState.locale == 'zh') langName = '中文';
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const Icon(Icons.language_rounded, color: kAccentBlue),
        title: Text(langState.t('language')),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(langName, style: const TextStyle(color: kTextSecondary)), const Icon(Icons.chevron_right_rounded, color: kTextSecondary)]),
        onTap: () => _showLanguagePicker(context, langState),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, LanguageState langState) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(langState.t('language'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20), _langItem(context, langState, 'th', 'ไทย', '🇹🇭'), _langItem(context, langState, 'en', 'English', '🇺🇸'), _langItem(context, langState, 'zh', '中文', '🇨🇳'), const SizedBox(height: 16)])));
  }

  Widget _langItem(BuildContext context, LanguageState langState, String code, String name, String flag) {
    final selected = langState.locale == code;
    return ListTile(leading: Text(flag, style: const TextStyle(fontSize: 24)), title: Text(name, style: TextStyle(fontWeight: selected ? FontWeight.bold : FontWeight.normal)), trailing: selected ? const Icon(Icons.check_circle_rounded, color: kAccentGreen) : null, onTap: () { langState.setLanguage(code); Navigator.pop(context); });
  }

  Widget _buildLogoutTile(BuildContext context, LanguageState langState) {
    final isDark = Provider.of<ThemeState>(context, listen: false).isDarkMode;
    return Card(
      elevation: 0, color: isDark ? kCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(leading: const Icon(Icons.logout_rounded, color: kAccentRed), title: Text(langState.t('logout'), style: const TextStyle(color: kAccentRed)), onTap: () => _showLogoutDialog(context, langState)),
    );
  }

  void _showLogoutDialog(BuildContext context, LanguageState langState) {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(langState.t('logout')), content: Text('${langState.t('logout')}?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(langState.t('cancel'))), TextButton(onPressed: () { Navigator.pop(ctx); _logout(context); }, child: Text(langState.t('logout'), style: const TextStyle(color: kAccentRed)))]));
  }
}
