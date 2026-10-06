import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

/// Desloga e devolve o usuário à tela de login.
///
/// Só `AuthProvider.logout()` não basta. Quem decide entre login e dashboard é o
/// `AuthWrapper`, e ele é a rota **raiz** (`home:` do MaterialApp): ao deslogar,
/// o wrapper passa a renderizar a `LoginPage`, mas `/dashboard`, `/caixas`,
/// `/receitas` e `/despesas` são empilhadas por cima dele. O usuário continuava
/// olhando a página empilhada, aparentemente logado.
///
/// O `popUntil` até a raiz descobre o wrapper, que já está mostrando o login. É
/// no-op quando não há nada empilhado — o caso de quem acabou de entrar pelo
/// formulário e nunca navegou.
///
/// Não use `pushNamedAndRemoveUntil('/login', …)` aqui: isso tira o `AuthWrapper`
/// da pilha, e como a `LoginPage` não navega sozinha depois do login (ela confia
/// no wrapper reconstruir), o usuário conseguiria autenticar e ficaria preso na
/// tela de login.
Future<void> sairDoApp(BuildContext context) async {
  final navigator = Navigator.of(context);

  await context.read<AuthProvider>().logout();

  navigator.popUntil((route) => route.isFirst);
}
