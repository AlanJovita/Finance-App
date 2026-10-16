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
/// recriaria a tela e refaria as requisições dela. **Com [argumentos] isso não
/// vale**: quem manda um filtro quer a tela remontada com ele, mesmo estando
/// nela (é o caso de pular de uma categoria para outra).
void irParaDestino(BuildContext context, String rota, {Object? argumentos}) {
  if (argumentos == null && ModalRoute.of(context)?.settings.name == rota) {
    return;
  }

  Navigator.pushNamedAndRemoveUntil(
    context,
    rota,
    (r) => r.isFirst,
    arguments: argumentos,
  );
}

/// Com que recorte a tela de Receitas/Despesas deve abrir.
///
/// Vai como `arguments` da rota, e quem o lê é a própria `FluxosPage` pelo
/// `ModalRoute.of(context).settings.arguments` — as telas são construídas dentro
/// do mapa `routes` do `main.dart`, que não vê os argumentos.
///
/// Existe porque o filtro de categoria da lista é **estado local** dela: a
/// página de Categorias precisava de um jeito de dizer "abra em outubro, só
/// Mercado" sem que a lista expusesse um setter para fora.
///
/// Nulo em qualquer campo é "não filtre": abrir pelo menu lateral não manda
/// argumento nenhum e a tela nasce no mês corrente, sem filtro.
class FiltroInicialFluxos {
  /// O mês em que a lista abre. Só ano e mês importam.
  final DateTime? mes;

  /// A categoria a filtrar. **0 não filtra** — é "sem categoria" no app inteiro,
  /// e a tela não oferece esse recorte (ver `fluxoPassaNoFiltro`).
  final int? idCategoria;

  const FiltroInicialFluxos({this.mes, this.idCategoria});
}
