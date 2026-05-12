import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'state/theme_state.dart';
import 'state/language_state.dart';
import 'pages/login_page.dart';
import 'pages/home_page.dart';
import 'pages/admin_page.dart';
import 'utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Local Storage
  await Hive.initFlutter();
  
  // Setup Encryption for Cache
  const secureStorage = FlutterSecureStorage();
  final containsEncryptionKey = await secureStorage.containsKey(key: 'encryptionKey');
  if (!containsEncryptionKey) {
    final key = Hive.generateSecureKey();
    await secureStorage.write(key: 'encryptionKey', value: base64Url.encode(key));
  }
  
  final keyStr = await secureStorage.read(key: 'encryptionKey');
  final encryptionKey = base64Url.decode(keyStr!);
  
  await Hive.openBox('cache', encryptionCipher: HiveAesCipher(encryptionKey));
  
  await dotenv.load(fileName: ".env");
  
  final prefs = await SharedPreferences.getInstance();
  final String? savedUser = prefs.getString('saved_user');
  final String? savedRole = prefs.getString('user_role');

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
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      title: 'AppKebtang',
      theme: themeState.currentTheme,
      routes: {
        '/login': (_) => const LoginPage(),
        '/home':  (_) => HomePage(username: savedUser ?? ''),
        '/admin': (_) => const AdminPage(),
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
