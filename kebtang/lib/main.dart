import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/theme_state.dart';
import 'state/language_state.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/admin_page.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final savedUser = prefs.getString('saved_user');
  final savedRole = prefs.getString('user_role');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeState()),
        ChangeNotifierProvider(create: (_) => LanguageState()),
      ],
      child: MyApp(savedUser: savedUser, savedRole: savedRole),
    ),
  );
}

class MyApp extends StatelessWidget {
  final String? savedUser;
  final String? savedRole;
  const MyApp({super.key, this.savedUser, this.savedRole});

  @override
  Widget build(BuildContext context) {
    final themeState = Provider.of<ThemeState>(context);
    
    return MaterialApp(
      title: 'บัญชีรายรับรายจ่าย',
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      theme: themeState.currentTheme,
      routes: {
        '/login': (_) => const LoginPage(),
      },
      home: _getHome(),
    );
  }

  Widget _getHome() {
    if (savedUser == null) return const LoginPage();
    if (savedRole == 'admin') return const AdminPage();
    return HomePage(username: savedUser!);
  }
}
