import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/lista_caixas_page.dart';
import 'pages/fluxos_page.dart';
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
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('pt', 'BR')],
            locale: const Locale('pt', 'BR'),
            builder:
                (context, child) => ResponsiveBreakpoints.builder(
                  child: child!,
                  breakpoints: [
                    const Breakpoint(start: 0, end: 450, name: MOBILE),
                    const Breakpoint(start: 451, end: 800, name: TABLET),
                    const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                    const Breakpoint(
                      start: 1921,
                      end: double.infinity,
                      name: '4K',
                    ),
                  ],
                ),
            onGenerateRoute: (settings) {
              // Captura rotas dinâmicas para tokens
              if (settings.name != null && settings.name != '/') {
                final path = settings.name!;

                // Remove a barra inicial
                final token = path.replaceFirst('/', '');

                // Verifica se é uma rota nomeada conhecida
                if (token == 'login' ||
                    token == 'dashboard' ||
                    token == 'caixas' ||
                    token == 'receitas' ||
                    token == 'despesas') {
                  return null; // Deixa as rotas normais funcionarem
                }

                // Se não for rota conhecida, trata como token
                if (token.isNotEmpty) {
                  return MaterialPageRoute(
                    builder: (context) => TokenLoginWrapper(token: token),
                  );
                }
              }

              return null;
            },
            initialRoute: '/', // Rota inicial
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginPage(),
              '/dashboard': (context) => const DashboardPage(),
              '/caixas': (context) => const ListaCaixasPage(),
              '/receitas': (context) => const FluxosPage(tipo: TipoFluxo.receita),
              '/despesas': (context) => const FluxosPage(tipo: TipoFluxo.despesa),
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

class TokenLoginWrapper extends StatefulWidget {
  final String token;

  const TokenLoginWrapper({super.key, required this.token});

  @override
  State<TokenLoginWrapper> createState() => _TokenLoginWrapperState();
}

class _TokenLoginWrapperState extends State<TokenLoginWrapper> {
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _performTokenLogin();
  }

  Future<void> _performTokenLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.loginByToken(widget.token);

    if (mounted) {
      if (success) {
        // Redireciona para o dashboard após login bem-sucedido
        Navigator.of(context).pushReplacementNamed('/dashboard');
      } else {
        setState(() {
          _error = 'Token inválido ou expirado';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Validando acesso...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Se houver erro, mostra mensagem e botão para login manual
    return Scaffold(
      appBar: AppBar(title: const Text('Erro de Acesso')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                _error ?? 'Erro desconhecido',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/login');
                },
                icon: const Icon(Icons.login),
                label: const Text('Fazer Login Manual'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
