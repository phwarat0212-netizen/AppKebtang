import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// Global navigator key — lets non-widget code (e.g. API helpers) trigger navigation.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// ─── Colors ───────────────────────────────────────────────────────
const kBg            = Color(0xFF0F0F1A);
const kCard          = Color(0xFF1A1A2E);
const kCardLight     = Color(0xFF16213E);
const kAccentGreen   = Color(0xFF00C896); // เข้มขึ้นนิดนึง
const kAccentRed     = Color(0xFFFF5252); // แดงชัดขึ้น
const kAccentBlue    = Color(0xFF3DA5D9); // น้ำเงินเข้มขึ้นเพื่อให้ตัดกับพื้นขาวได้ดี
const kTextPrimary   = Color(0xFFF0F0F0);
const kTextSecondary = Color(0xFF94A3B8); // ปรับสีเทาให้เข้มขึ้นเพื่อให้อ่านง่าย

// ─── Secure Token Storage ────────────────────────────────────────
class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _tokenKey = 'user_token';

  static Future<String?> read() async {
    final secure = await _storage.read(key: _tokenKey);
    if (secure != null) return secure;

    // Migrate legacy token from SharedPreferences (one-time).
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(_tokenKey);
    if (legacy != null) {
      await _storage.write(key: _tokenKey, value: legacy);
      await prefs.remove(_tokenKey);
      return legacy;
    }
    return null;
  }

  static Future<void> write(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}

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
    final token = await SecureTokenStorage.read();

    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // Returns true if the response represents an auth failure (expired/invalid token)
  // and triggers an auto-logout to the login screen. Callers should bail out when true.
  static bool handleAuthError(http.Response response) {
    if (response.statusCode != 401 && response.statusCode != 403) return false;
    _forceLogout();
    return true;
  }

  static bool _logoutInFlight = false;
  static Future<void> _forceLogout() async {
    if (_logoutInFlight) return;
    _logoutInFlight = true;
    try {
      await SecureTokenStorage.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('saved_user');
      await prefs.remove('user_role');

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushNamedAndRemoveUntil('/login', (_) => false);
    } finally {
      _logoutInFlight = false;
    }
  }
}
