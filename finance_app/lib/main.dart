import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/lista_caixas_page.dart';
import 'pages/receitas_page.dart';
import 'pages/despesas_page.dart';
import 'utils/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Controle de Caixa',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/dashboard': (context) => const DashboardPage(),
              '/caixas': (context) => const ListaCaixasPage(),
              '/receitas': (context) => const ReceitasPage(),
              '/despesas': (context) => const DespesasPage(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return auth.isAuthenticated ? const DashboardPage() : const LoginPage();
      },
    );
  }
}
