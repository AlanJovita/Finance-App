import 'package:flutter/material.dart';

/// Vai para um dos destinos do menu (`/dashboard`, `/caixas`, `/contas`,
/// `/cartoes`, `/receitas`, `/despesas`).
///
/// **Os seis são irmãos de topo, não telas empilhadas umas sobre as outras.**
/// Chegar em Receitas pelo menu lateral, pelo atalho do Resumo ou pelo "ver
/// todos" de um card tem de deixar a pilha igual. Antes cada caminho fazia a
/// sua própria chamada — o menu dava `pushNamedAndRemoveUntil`, os outros dois
/// davam `pushNamed` — e a profundidade da pilha dependia do caminho
/// percorrido: pelo menu dava 2, pelo atalho do Resumo dava 3. Com isso a seta
/// de voltar levava a lugares diferentes para a mesma tela.
///
/// O `(rota) => rota.isFirst` **preserva a raiz** (o `AuthWrapper`), e isso não
/// é detalhe: é dela que dependem o `popUntil` de `sairDoApp` e o da
/// `GuardaSessao`. Trocar por `pushReplacementNamed` tira o wrapper da pilha e
/// prende quem desloga na tela de login.
///
/// Tocar o destino em que já se está não faz nada — sem o atalho, o menu
/// recriaria a tela e refaria as requisições dela.
void irParaDestino(BuildContext context, String rota) {
  if (ModalRoute.of(context)?.settings.name == rota) return;

  Navigator.pushNamedAndRemoveUntil(context, rota, (r) => r.isFirst);
}
