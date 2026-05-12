import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../state/theme_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ProfilePage extends StatefulWidget {
  final AppState appState;
  const ProfilePage({super.key, required this.appState});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _nameCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  String _username = '';
  String _role = '';
  
  Color _selectedColor = kAccentGreen;
  IconData _selectedIcon = Icons.person_rounded;

  final List<Color> _colors = [
    const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFF44336),
    const Color(0xFFFF9800), const Color(0xFF9C27B0), const Color(0xFF00BCD4),
    const Color(0xFF795548), const Color(0xFF607D8B),
  ];

  final List<IconData> _icons = [
    Icons.person_rounded, Icons.face_rounded, Icons.pets_rounded,
    Icons.star_rounded, Icons.favorite_rounded, Icons.bolt_rounded,
    Icons.rocket_launch_rounded, Icons.savings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.get(Uri.parse('${ApiConfig.baseUrl}/user/profile'), headers: headers);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          _username = data['username'];
          _role = data['role'];
          _nameCtrl.text = data['displayName'] ?? '';
          
          if (data['avatarColor'] != null) {
            _selectedColor = Color(int.parse(data['avatarColor']));
          }
          if (data['avatarIcon'] != null) {
            _selectedIcon = _getIconData(data['avatarIcon']);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'face': return Icons.face_rounded;
      case 'pets': return Icons.pets_rounded;
      case 'star': return Icons.star_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'rocket': return Icons.rocket_launch_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'person':
      default: return Icons.person_rounded;
    }
  }

  String _getIconName(IconData icon) {
    if (icon == Icons.face_rounded) return 'face';
    if (icon == Icons.pets_rounded) return 'pets';
    if (icon == Icons.star_rounded) return 'star';
    if (icon == Icons.favorite_rounded) return 'favorite';
    if (icon == Icons.bolt_rounded) return 'bolt';
    if (icon == Icons.rocket_launch_rounded) return 'rocket';
    if (icon == Icons.savings_rounded) return 'savings';
    return 'person';
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final headers = await ApiConfig.getHeaders();
      final res = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/user/profile'),
        headers: headers,
        body: jsonEncode({
          'displayName': _nameCtrl.text.trim(),
          'avatarColor': '0x${_selectedColor.value.toRadixString(16).toUpperCase()}',
          'avatarIcon': _getIconName(_selectedIcon),
        }),
      );
      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(Provider.of<LanguageState>(context, listen: false).t('save_success')), backgroundColor: kAccentGreen),
          );
        }
      }
    } catch (e) { }
    finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Provider.of<ThemeState>(context).isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? kBg : const Color(0xFFF7FAFC),
      appBar: AppBar(
        title: Text(langState.t('profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kAccentGreen))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildAvatarPreview(isDark),
                const SizedBox(height: 32),
                _buildCustomizationSection(langState, isDark),
                const SizedBox(height: 24),
                _buildInfoCard(langState, isDark),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kAccentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(langState.t('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }

  Widget _buildAvatarPreview(bool isDark) {
    return Container(
      width: 120, height: 120,
      decoration: BoxDecoration(
        color: _selectedColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: _selectedColor, width: 4),
        boxShadow: [
          BoxShadow(color: _selectedColor.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))
        ],
      ),
      child: Icon(_selectedIcon, size: 60, color: _selectedColor),
    );
  }

  Widget _buildCustomizationSection(LanguageState lang, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.t('avatar_color'), style: const TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _colors.length,
            itemBuilder: (ctx, i) => _colorChip(_colors[i]),
          ),
        ),
        const SizedBox(height: 24),
        Text(lang.t('avatar_icon'), style: const TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _icons.length,
            itemBuilder: (ctx, i) => _iconChip(_icons[i], isDark),
          ),
        ),
      ],
    );
  }

  Widget _colorChip(Color color) {
    final sel = _selectedColor.value == color.value;
    return GestureDetector(
      onTap: () => setState(() => _selectedColor = color),
      child: Container(
        width: 40, height: 40,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 3),
          boxShadow: sel ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8)] : [],
        ),
        child: sel ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
      ),
    );
  }

  Widget _iconChip(IconData icon, bool isDark) {
    final sel = _selectedIcon == icon;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: Container(
        width: 50, height: 50,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: sel ? _selectedColor.withValues(alpha: 0.2) : (isDark ? kCard : Colors.white),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: sel ? _selectedColor : Colors.transparent, width: 2),
        ),
        child: Icon(icon, color: sel ? _selectedColor : kTextSecondary, size: 28),
      ),
    );
  }

  Widget _buildInfoCard(LanguageState lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? kCard : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: isDark ? [] : [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStaticItem(lang.t('username_label'), _username, isDark),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          _buildStaticItem(lang.t('role'), _role.toUpperCase(), isDark),
          const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider()),
          _buildEditableItem(lang.t('display_name'), _nameCtrl, isDark),
        ],
      ),
    );
  }

  Widget _buildStaticItem(String label, String value, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildEditableItem(String label, TextEditingController ctrl, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: ctrl,
          style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 16),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.black26 : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
