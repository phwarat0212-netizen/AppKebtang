import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/language_state.dart';
import '../state/theme_state.dart';
import '../utils/constants.dart';
import 'login_page.dart';

// ─── Register Page ───────────────────────────────────────────────

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _obscureConf = true;

  Future<void> _register() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    final conf = _confCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty || conf.isEmpty) {
      _showError('error_fields');
      return;
    }
    if (pass != conf) {
      _showError('error_pass_match');
      return;
    }
    if (pass.length < 8) {
      _showError('error_pass_short');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        _showSuccess('register_success');
        if (!mounted) return;
        Navigator.pop(context); // Return to login
      } else {
        final data = jsonDecode(response.body);
        _showError(data['error'] ?? 'register_failed');
      }
    } catch (e) {
      _showError('connection_error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String key) {
    if (!mounted) return;
    final lang = Provider.of<LanguageState>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.t(key)), backgroundColor: kAccentRed, behavior: SnackBarBehavior.floating),
    );
  }

  void _showSuccess(String key) {
    if (!mounted) return;
    final lang = Provider.of<LanguageState>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(lang.t(key)), backgroundColor: kAccentGreen, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Provider.of<ThemeState>(context).isDarkMode;

    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      extendBodyBehindAppBar: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark 
              ? [const Color(0xFF1A1A2E), kBg] 
              : [const Color(0xFFE2E8F0), const Color(0xFFEDF2F7)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kAccentBlue.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_rounded, size: 64, color: kAccentBlue),
                  ),
                  const SizedBox(height: 24),
                  Text(langState.t('register'), 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(langState.t('register_subtitle'), 
                    style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 40),

                  // Fields
                  _buildField(
                    controller: _userCtrl,
                    label: langState.t('username_label'),
                    hint: langState.t('username_hint'),
                    icon: Icons.person_outline_rounded,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _passCtrl,
                    label: langState.t('password_label'),
                    hint: langState.t('password_hint'),
                    icon: Icons.lock_outline_rounded,
                    isDark: isDark,
                    obscure: _obscurePass,
                    suffix: IconButton(
                      icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: kTextSecondary),
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildField(
                    controller: _confCtrl,
                    label: langState.t('confirm_password_label'),
                    hint: langState.t('confirm_password_hint'),
                    icon: Icons.lock_reset_rounded,
                    isDark: isDark,
                    obscure: _obscureConf,
                    suffix: IconButton(
                      icon: Icon(_obscureConf ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20, color: kTextSecondary),
                      onPressed: () => setState(() => _obscureConf = !_obscureConf),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Register Button
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(langState.t('register_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Back to Login
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(langState.t('has_account'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600])),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(langState.t('login_btn'), style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: isDark ? kTextSecondary.withValues(alpha: 0.5) : Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(icon, color: kAccentBlue, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark ? kCard : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kAccentBlue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
