import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeState extends ChangeNotifier {
  bool _isDarkMode = false; // เปลี่ยนค่าเริ่มต้นเป็นธีมสว่าง
  bool get isDarkMode => _isDarkMode;

  ThemeState() {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false; // ถ้าไม่มีค่าให้เป็นเท็จ (สว่าง)
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    notifyListeners();
  }

  ThemeData get currentTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A1A2E),
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
      ),
      fontFamily: 'Sarabun',
      useMaterial3: true,
      scaffoldBackgroundColor: _isDarkMode ? const Color(0xFF0F0F1A) : const Color(0xFFEDF2F7), // ปรับให้เข้มขึ้นเล็กน้อยจากขาวจั๊ว
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: _isDarkMode ? Colors.white : const Color(0xFF1A202C)), // สีตัวอักษรดำเข้มในโหมดสว่าง
        bodyMedium: TextStyle(color: _isDarkMode ? Colors.white : const Color(0xFF2D3748)),
        titleLarge: TextStyle(color: _isDarkMode ? Colors.white : const Color(0xFF111827), fontWeight: FontWeight.bold),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: _isDarkMode ? Colors.white : const Color(0xFF1A202C)),
        titleTextStyle: TextStyle(
          color: _isDarkMode ? Colors.white : const Color(0xFF1A202C),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          fontFamily: 'Sarabun',
        ),
      ),
    );
  }
}
