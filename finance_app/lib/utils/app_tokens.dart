/// Escalas de espaçamento, raio e elevação do app.
///
/// Os valores foram extraídos dos literais que já estavam espalhados por
/// `app_theme.dart` e pelas telas — não são valores novos, então trocar um
/// literal pelo token correspondente não muda nada visualmente.
///
/// Use [AppSpacing] para medidas fixas. Quando a medida varia por breakpoint,
/// use `ResponsiveUtils` (`responsive_utils.dart`), cujos defaults saem daqui.
library;

abstract final class AppSpacing {
  /// Distância entre um ícone e seu rótulo.
  static const double xs = 4;

  /// Respiro interno de chips e itens de lista compactos.
  static const double sm = 8;

  /// Padding vertical de botões; gap entre itens irmãos.
  static const double md = 12;

  /// Padding padrão de cards, telas e diálogos.
  static const double lg = 16;

  /// Padding horizontal de botões; respiro entre blocos.
  static const double xl = 24;

  /// Separação entre seções.
  static const double xxl = 32;

  /// Respiro de destaque (topo de tela, estados vazios).
  static const double xxxl = 48;
}

abstract final class AppRadius {
  /// Ícones em caixa tonal, chips pequenos.
  static const double sm = 4;

  /// Botões, campos de formulário, list tiles.
  static const double md = 6;

  /// Cards.
  static const double lg = 8;

  /// Diálogos e chips.
  static const double xl = 10;
}

/// Medidas de **estrutura**: onde um layout troca de forma, e quanto ocupa a
/// forma nova.
///
/// Separado de [AppSpacing] porque não é respiro, é arquitetura.
abstract final class AppLayout {
  /// Piso da segunda coluna do Resumo.
  ///
  /// 720 é o que faz celular **deitado** (≈844 de largura) ganhar a segunda
  /// coluna e celular **em pé** (≈390) ficar com uma só, que era o pedido.
  /// Tablet em pé (≈800) cai do lado de cima e também ganha duas — consequência
  /// aceita de medir largura em vez de orientação: no navegador, "orientação"
  /// não diz nada sobre quanto espaço existe.
  static const double duasColunas = 720;

  /// Piso da terceira coluna. Abaixo disso três colunas sairiam com menos de
  /// ~460px cada, e um gráfico de pizza com legenda ao lado não cabe nisso.
  static const double tresColunas = 1500;

  /// Teto de largura do conteúdo centralizado. Em ultrawide sobram tarjas
  /// laterais de propósito: esticar três colunas por 3440px dá cards de 1100px,
  /// e aí o olho percorre a linha inteira para ler um par rótulo/valor.
  static const double conteudoMaximo = 1800;

  /// Quantas colunas o Resumo monta em [largura].
  ///
  /// A conta é sobre a largura **da tela**, não a que sobra depois do padding:
  /// é o número que descreve o aparelho, e é por ele que os dois limiares acima
  /// foram escolhidos. A grade depois se acomoda no espaço que de fato tem.
  static int colunasResumo(double largura) {
    if (largura >= tresColunas) return 3;
    if (largura >= duasColunas) return 2;
    return 1;
  }
}

/// Superfícies escuras precisam de mais elevação que as claras para se separarem
/// do fundo — daí cada papel ter um par: o valor claro e sua contraparte escura.
abstract final class AppElevation {
  static const double none = 0;

  static const double card = 2;
  static const double cardRaised = 4;

  static const double button = 2;
  static const double buttonRaised = 3;

  static const double floating = 4;
  static const double floatingRaised = 6;

  static const double overlay = 8;
  static const double overlayRaised = 12;
}
