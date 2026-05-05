import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Colors ───────────────────────────────────────────────────────
const kBg            = Color(0xFF0F0F1A);
const kCard          = Color(0xFF1A1A2E);
const kCardLight     = Color(0xFF16213E);
const kAccentGreen   = Color(0xFF00C896); // เข้มขึ้นนิดนึง
const kAccentRed     = Color(0xFFFF5252); // แดงชัดขึ้น
const kAccentBlue    = Color(0xFF3DA5D9); // น้ำเงินเข้มขึ้นเพื่อให้ตัดกับพื้นขาวได้ดี
const kTextPrimary   = Color(0xFFF0F0F0);
const kTextSecondary = Color(0xFF94A3B8); // ปรับสีเทาให้เข้มขึ้นเพื่อให้อ่านง่าย

// ─── API Config ───────────────────────────────────────────────────
class ApiConfig {
  // URL ของเซิร์ฟเวอร์บน Render
  static String get baseUrl {
    return 'https://kebtang-api.onrender.com/api';
  }

  static String get socketUrl {
    return 'https://kebtang-api.onrender.com';
  }

  // Helper to get headers with JWT
  static Future<Map<String, String>> getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('user_token');
    
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
