import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../state/language_state.dart';
import '../state/theme_state.dart';
import '../utils/constants.dart';
import '../utils/biometric_service.dart';
import 'home_page.dart';
import 'admin_page.dart';
import 'register_page.dart';

// ─── Login Page ──────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePass = true;
  bool _canBiometric = false;
  bool _autoBiometricTriggered = false;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final enabled = await BiometricService.isEnabled();
    if (enabled) {
      setState(() => _canBiometric = true);
      // Auto-trigger biometric on startup
      if (!_autoBiometricTriggered) {
        _autoBiometricTriggered = true;
        Future.delayed(const Duration(milliseconds: 500), _biometricLogin);
      }
    }
  }

  Future<void> _biometricLogin() async {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final auth = await BiometricService.authenticate(langState.t('auth_reason'));
    if (auth) {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('saved_user');
      final savedRole = prefs.getString('user_role');
      final token = await SecureTokenStorage.read();

      if (savedUser != null && token != null) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => savedRole == 'admin' ? const AdminPage() : HomePage(username: savedUser),
          ),
        );
      } else {
        // If credentials missing, user must login manually
      }
    }
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (user.isEmpty || pass.isEmpty) {
      _showError('error_fields');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user', data['username']);
        await prefs.setString('user_role', data['role']);
        await SecureTokenStorage.write(data['token']);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => data['role'] == 'admin' ? const AdminPage() : HomePage(username: data['username']),
          ),
        );
      } else {
        final data = jsonDecode(response.body);
        _showError(data['error'] ?? 'invalid_credentials');
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

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Provider.of<ThemeState>(context).isDarkMode;

    return Scaffold(
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
                  const SizedBox(height: 60),
                  // Logo / Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kAccentGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, size: 64, color: kAccentGreen),
                  ),
                  const SizedBox(height: 24),
                  Text(langState.t('welcome'), 
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 8),
                  Text(langState.t('login_subtitle'), 
                    style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600], fontSize: 14)),
                  const SizedBox(height: 48),

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
                  const SizedBox(height: 32),

                  // Login Button
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccentGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(langState.t('login_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_canBiometric)
                    IconButton(
                      icon: const Icon(Icons.fingerprint_rounded, size: 40, color: kAccentGreen),
                      onPressed: _biometricLogin,
                    ),
                  const SizedBox(height: 16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(langState.t('no_account'), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[600])),
                      TextButton(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                        child: Text(langState.t('register_btn'), style: const TextStyle(color: kAccentGreen, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
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
            prefixIcon: Icon(icon, color: kAccentGreen, size: 20),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark ? kCard : Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: isDark ? Colors.transparent : Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: kAccentGreen, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
