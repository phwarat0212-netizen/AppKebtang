import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kebtang/pages/login_page.dart';
import 'package:kebtang/pages/register_page.dart';
import 'package:kebtang/state/language_state.dart';
import 'package:kebtang/state/theme_state.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeState()),
        ChangeNotifierProvider(create: (_) => LanguageState()),
      ],
      child: Consumer<ThemeState>(
        builder: (context, theme, _) => MaterialApp(
          theme: theme.currentTheme,
          home: child,
        ),
      ),
    );
  }

  group('Authentication Widget Tests', () {
    testWidgets('LoginPage should display welcome text and login button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const LoginPage()));
      
      expect(find.byType(TextField), findsNWidgets(2));
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsOneWidget);
    });

    testWidgets('RegisterPage should display register fields and button', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const RegisterPage()));
      
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.person_add_rounded), findsOneWidget);
    });

    testWidgets('Toggling password visibility in LoginPage', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(const LoginPage()));
      
      final passField = find.byType(TextField).last;
      TextField widget = tester.widget(passField);
      expect(widget.obscureText, isTrue);

      await tester.tap(find.byIcon(Icons.visibility_off_rounded));
      await tester.pump();

      widget = tester.widget(passField);
      expect(widget.obscureText, isFalse);
    });

    group('Navigation Tests', () {
      testWidgets('Tapping register link should navigate to RegisterPage', (WidgetTester tester) async {
        await tester.pumpWidget(createTestWidget(const LoginPage()));
        
        final regBtn = find.byType(TextButton);
        await tester.tap(regBtn);
        await tester.pumpAndSettle();

        expect(find.byType(RegisterPage), findsOneWidget);
      });
    });
  });
}
