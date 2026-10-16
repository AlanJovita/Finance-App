import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/menu_provider.dart';
import 'pages/login_page.dart';
import 'pages/dashboard_page.dart';
import 'pages/lista_caixas_page.dart';
import 'pages/cartoes_page.dart';
import 'pages/categorias_page.dart';
import 'pages/contas_page.dart';
import 'pages/fluxos_page.dart';
import 'utils/app_theme.dart';
import 'widgets/guarda_sessao.dart';

/// A rota vem do **caminho** da URL, não do fragmento.
///
/// O padrão do Flutter Web é `HashUrlStrategy`, e com ele o navegador lê a rota
/// de depois do `#`. O link de acesso direto que o app-suporte gera é
/// `finance.premiosistemas.com.br/<token>` — caminho, sem `#`: o Flutter subia,
/// olhava um fragmento vazio, resolvia a rota inicial como `/` e caía na tela de
/// login. O `onGenerateRoute` abaixo, que trata o token, nunca era chamado.
///
/// Chamar isto antes do `runApp` é o que faz o caminho virar a rota. O nginx já
/// manda todo caminho desconhecido para o `index.html` (ver `nginx.conf`), que é
/// a outra metade necessária — sem ela, recarregar em `/receitas` daria 404.
///
/// Fora da web é no-op: o `url_strategy.dart` do `flutter_web_plugins` exporta
/// um stub condicional para as outras plataformas.
void main() {
  usePathUrlStrategy();
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
        ChangeNotifierProvider(create: (_) => MenuProvider()),
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
                    token == 'contas' ||
                    token == 'cartoes' ||
                    token == 'categorias' ||
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
            // Toda rota interna entra pela `GuardaSessao`. Não é redundância
            // com o `AuthWrapper`: o wrapper é só a raiz, e em web o navegador
            // recarrega o app **na rota em foco** (é o que o voltar/avançar
            // faz), montando a tela direto daqui, sem sessão nenhuma. Ver
            // `widgets/guarda_sessao.dart`.
            //
            // Rota nova no mapa precisa vir embrulhada igual — e, como diz a
            // nota do `onGenerateRoute` acima, entrar também na lista de rotas
            // conhecidas de lá.
            routes: {
              '/login': (context) => const LoginPage(),
              '/dashboard':
                  (context) => const GuardaSessao(
                    rota: '/dashboard',
                    child: DashboardPage(),
                  ),
              '/caixas':
                  (context) => const GuardaSessao(
                    rota: '/caixas',
                    child: ListaCaixasPage(),
                  ),
              '/contas':
                  (context) =>
                      const GuardaSessao(rota: '/contas', child: ContasPage()),
              '/cartoes':
                  (context) => const GuardaSessao(
                    rota: '/cartoes',
                    child: CartoesPage(),
                  ),
              '/categorias':
                  (context) => const GuardaSessao(
                    rota: '/categorias',
                    child: CategoriasPage(),
                  ),
              '/receitas':
                  (context) => const GuardaSessao(
                    rota: '/receitas',
                    child: FluxosPage(tipo: TipoFluxo.receita),
                  ),
              '/despesas':
                  (context) => const GuardaSessao(
                    rota: '/despesas',
                    child: FluxosPage(tipo: TipoFluxo.despesa),
                  ),
            },
          );
        },
      ),
    );
  }
}

/// A rota raiz: decide entre login e painel.
///
/// Decide por `sessaoValida`, e não por `isAuthenticated`: autenticado com a
/// lista de lojas vazia é o estado em que o app operava no cliente 0, e aqui
/// ele tem de parecer o que é — ninguém logado.
///
/// Enquanto a sessão gravada está sendo lida mostra a espera, em vez da tela de
/// login. A leitura é assíncrona; devolver "login" por default fazia a tela
/// piscar em toda abertura de quem marcou "lembrar login".
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.sessaoCarregando) return const EsperaSessao();

        return auth.sessaoValida ? const DashboardPage() : const LoginPage();
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
          _error = 'Link de acesso inválido ou revogado';
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
