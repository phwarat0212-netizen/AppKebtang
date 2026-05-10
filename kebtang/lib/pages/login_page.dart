import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import 'home_page.dart';
import 'admin_page.dart';
import 'register_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Login Page ───────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool    _obscure = true;
  bool    _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'fields_required');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/login'),
        headers: {'Content-Type': 'application/json', 'bypass-tunnel-reminder': 'true'},
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('timeout'),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        final role = (data['role'] as String?) ?? 'user';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('saved_user', user);
        await prefs.setString('user_role', role);
        await SecureTokenStorage.write(token);

        if (!mounted) return;

        if (role == 'admin') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminPage()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomePage(username: user)),
          );
        }
      } else if (response.statusCode == 429) {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data['message'] ?? 'ลองผิดเกินขีดจำกัด กรุณารอ 30 วินาที';
        });
      } else {
        setState(() {
          _error = 'invalid_credentials';
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('timeout')) {
          _error = 'timeout_error';
        } else {
          _error = 'connection_error';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Scaffold(
      backgroundColor: kBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                // Logo
                Center(
                  child: Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kAccentGreen, kAccentBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(color: kAccentGreen.withValues(alpha: 0.35), blurRadius: 30, offset: const Offset(0, 10)),
                      ],
                    ),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 44),
                  ),
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(langState.t('welcome'),
                    style: const TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(langState.t('login_subtitle'),
                    style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                ),
                const SizedBox(height: 48),
                // Username
                _LoginField(
                  controller: _userCtrl,
                  label: langState.t('username_label'),
                  hint: langState.t('username_hint'),
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                // Password
                _LoginField(
                  controller: _passCtrl,
                  label: langState.t('password_label'),
                  hint: langState.t('password_hint'),
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: kTextSecondary, size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                // Error message
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: kAccentRed.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccentRed.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: kAccentRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(langState.t(_error!), style: const TextStyle(color: kAccentRed, fontSize: 13))),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Login button
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(langState.t('login_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                // Register link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${langState.t('no_account')} ', style: const TextStyle(color: kTextSecondary)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const RegisterPage()),
                          );
                        },
                        child: Text(langState.t('register_btn'), style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Login Field Widget ───────────────────────────────────────────

class _LoginField extends StatelessWidget {
  final TextEditingController  controller;
  final String                 label;
  final String                 hint;
  final IconData               icon;
  final bool                   obscure;
  final Widget?                suffixIcon;
  final ValueChanged<String>?  onSubmitted;

  const _LoginField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure     = false,
    this.suffixIcon,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 13)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          onSubmitted: onSubmitted,
          style: const TextStyle(color: kTextPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kTextSecondary.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: kTextSecondary, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: kCard,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
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
