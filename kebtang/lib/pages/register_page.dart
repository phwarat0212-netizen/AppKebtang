import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart'; // เพิ่ม Provider
import '../state/language_state.dart'; // เพิ่ม LanguageState
import '../utils/constants.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

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
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final langState = Provider.of<LanguageState>(context, listen: false);
    final user = _userCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    if (user.isEmpty || pass.isEmpty) {
      setState(() => _error = 'fields_required');
      return;
    }

    // Regex สำหรับภาษาอังกฤษ ตัวเลข และอักษรพิเศษเท่านั้น (ไม่อนุญาตภาษาไทยหรือภาษาอื่น)
    final validChars = RegExp(r'^[a-zA-Z0-9!@#$%^&*(),.?":{}|<>+=\-_\[\]\\\/ ]+$');
    
    if (!validChars.hasMatch(user)) {
      setState(() => _error = 'error_lang_limit');
      return;
    }
    
    if (!validChars.hasMatch(pass)) {
      setState(() => _error = 'error_lang_limit');
      return;
    }

    if (pass.length < 8) {
      setState(() => _error = 'error_pass_short');
      return;
    }

    if (pass.toLowerCase() == user.toLowerCase()) {
      setState(() => _error = 'error_pass_same_user');
      return;
    }

    if (pass != confirmPass) {
      setState(() => _error = 'error_pass_match');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final headers = await ApiConfig.getHeaders();
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/register'),
        headers: headers,
        body: jsonEncode({'username': user, 'password': pass}),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () => throw Exception('timeout'),
      );

      if (!mounted) return;

      if (response.statusCode == 201) {
        // Success
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(langState.t('register_success')), backgroundColor: kAccentGreen),
        );
        Navigator.pop(context); // Go back to login page
      } else {
        setState(() {
          _error = 'register_failed';
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: kTextPrimary),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Text(langState.t('register'),
                    style: const TextStyle(color: kTextPrimary, fontSize: 28, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(langState.t('register_subtitle'),
                    style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                ),
                const SizedBox(height: 48),
                _RegisterField(
                  controller: _userCtrl,
                  label: langState.t('username_label'),
                  hint: langState.t('username_hint'),
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 16),
                _RegisterField(
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
                ),
                const SizedBox(height: 16),
                _RegisterField(
                  controller: _confirmPassCtrl,
                  label: langState.t('confirm_password_label'),
                  hint: langState.t('confirm_password_hint'),
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                ),
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
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : Text(langState.t('register_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(langState.t('has_account'), style: const TextStyle(color: kTextSecondary)),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(langState.t('login_btn'), style: const TextStyle(color: kAccentBlue, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Register Field Widget ───────────────────────────────────────────

class _RegisterField extends StatelessWidget {
  final TextEditingController  controller;
  final String                 label;
  final String                 hint;
  final IconData               icon;
  final bool                   obscure;
  final Widget?                suffixIcon;

  const _RegisterField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure     = false,
    this.suffixIcon,
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
              borderSide: const BorderSide(color: kAccentBlue, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }
}
