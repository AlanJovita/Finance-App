import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:finance_app/providers/auth_provider.dart';
import 'package:finance_app/utils/auth_actions.dart';

/// Reproduz a estrutura de navegação do `main.dart`: o wrapper que decide entre
/// login e dashboard é a rota **raiz**, e as demais telas são empilhadas por
/// cima dele. É dessa forma que o bug aparecia — deslogar trocava o conteúdo da
/// raiz, mas o usuário continuava vendo a rota empilhada.
Widget _app() {
  return ChangeNotifierProvider(
    create: (_) => AuthProvider(),
    child: MaterialApp(
      home: Consumer<AuthProvider>(
        builder:
            (_, auth, __) => Scaffold(
              body: Text(auth.isAuthenticated ? 'DASHBOARD' : 'LOGIN'),
            ),
      ),
      routes: {
        '/caixas': (context) => Scaffold(
          body: ElevatedButton(
            onPressed: () => sairDoApp(context),
            child: const Text('Sair'),
          ),
        ),
      },
    ),
  );
}

void main() {
  setUp(() {
    // O AuthProvider sobe autenticado quando as duas chaves existem.
    SharedPreferences.setMockInitialValues({
      'auth_user': '12345678000199',
      'id_lojas': <String>['42'],
    });
  });

  testWidgets('Sair a partir de rota empilhada volta para o login', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);

    // Empilha uma tela por cima do wrapper, como o drawer faz.
    tester.state<NavigatorState>(find.byType(Navigator)).pushNamed('/caixas');
    await tester.pumpAndSettle();
    expect(find.text('Sair'), findsOneWidget);

    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();

    // Sem o popUntil, aqui ainda estaria a tela empilhada.
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('Sair'), findsNothing);
  });

  testWidgets('Sair sem rota empilhada também volta para o login', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);

    final context = tester.element(find.text('DASHBOARD'));
    await sairDoApp(context);
    await tester.pumpAndSettle();

    expect(find.text('LOGIN'), findsOneWidget);
  });

  test('logout limpa o estado e apaga as chaves do disco', () async {
    SharedPreferences.setMockInitialValues({
      'auth_user': '12345678000199',
      'id_lojas': <String>['42'],
    });

    final auth = AuthProvider();
    await Future<void>.delayed(Duration.zero); // deixa o _loadUserFromPrefs rodar
    expect(auth.isAuthenticated, isTrue);

    var notificou = false;
    auth.addListener(() => notificou = true);

    await auth.logout();

    expect(auth.isAuthenticated, isFalse);
    expect(auth.user, isNull);
    expect(auth.idLojas, isEmpty);
    expect(notificou, isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('auth_user'), isNull);
    expect(prefs.getStringList('id_lojas'), isNull);
  });
}
