import 'package:flutter/material.dart';

/// Troca de tela por **opacidade**, em 120ms.
///
/// O padrão do Flutter nesta plataforma é o `ZoomPageTransitionsBuilder` — a
/// transição do Android Q, de 300ms, que anima escala **e** opacidade e, para
/// conseguir isso de forma barata no celular, rasteriza a página inteira num
/// snapshot. Num app com `fl_chart` em quase toda tela esse snapshot é caro: o
/// que se via era a tela "abrindo" devagar, com os gráficos congelados.
///
/// Aqui não há escala nem snapshot, só a composição de duas camadas com
/// opacidade diferente — trabalho que a GPU faz sem rasterizar nada.
///
/// **Por que 120ms.** Abaixo de ~100ms a transição deixa de ser percebida como
/// movimento e vira um corte seco; acima de ~200ms ela passa a ser espera. 120
/// é o bastante para o olho entender que a tela trocou sem ter de aguardar a
/// troca terminar.
///
/// A duração vem daqui e não do `MaterialPageRoute`: o `transitionDuration`
/// dele é fixo em 300ms e consulta o builder do tema (ver
/// `MaterialRouteTransitionMixin.transitionDuration`), que é este.
class TransicaoFade extends PageTransitionsBuilder {
  const TransicaoFade();

  static const Duration duracao = Duration(milliseconds: 120);

  @override
  Duration get transitionDuration => duracao;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Só a animação de entrada. A `secondaryAnimation` — a tela que sai quando
    // outra entra por cima — fica parada de propósito: animar as duas dobra o
    // custo e, num fade curto, o resultado é um piscar.
    return FadeTransition(opacity: animation, child: child);
  }
}

/// O mesmo fade em todas as plataformas.
///
/// Sem isto o app teria três comportamentos: zoom no Chrome e no Windows,
/// deslizamento do Cupertino no macOS e no iOS, e o "predictive back" no
/// Android. A tela é a mesma nos três; a transição também deve ser.
const PageTransitionsTheme transicoesDoApp = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: TransicaoFade(),
    TargetPlatform.iOS: TransicaoFade(),
    TargetPlatform.macOS: TransicaoFade(),
    TargetPlatform.windows: TransicaoFade(),
    TargetPlatform.linux: TransicaoFade(),
    TargetPlatform.fuchsia: TransicaoFade(),
  },
);
