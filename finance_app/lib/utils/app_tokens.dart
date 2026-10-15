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
  /// [largura] é a que sobra para o conteúdo depois do menu lateral fixo — use
  /// [larguraUtil] para obtê-la a partir da largura da tela. **Não** é a largura
  /// descontado o padding da página: os limiares acima descrevem o espaço de
  /// layout, e a grade depois se acomoda no respiro que a página dá.
  static int colunasResumo(double largura) {
    if (largura >= tresColunas) return 3;
    if (largura >= duasColunas) return 2;
    return 1;
  }

  /// A partir daqui o menu lateral deixa de ser gaveta e fica **fixo** na tela.
  ///
  /// É sobre a largura da tela, e não sobre a que sobra: quem decide se cabe um
  /// menu permanente é o aparelho. Abaixo disso ele volta a ser a gaveta do
  /// botão de hambúrguer.
  static const double menuFixo = 1500;

  /// Largura do menu quando fixo — o padrão do `Drawer` do Material.
  static const double larguraMenu = 304;

  /// O divisor entre o menu e o conteúdo.
  static const double _divisorMenu = 1;

  static bool menuLateralFixo(double larguraTela) => larguraTela >= menuFixo;

  /// O que sobra da tela para o conteúdo, já descontado o menu fixo.
  ///
  /// Existe porque o menu fixo nasce exatamente em [menuFixo] = 1500, o mesmo
  /// número que seria o piso de três colunas: sem descontá-lo, uma tela de
  /// 1500px montaria três colunas de ~367px — mais estreitas que as duas
  /// colunas de um celular deitado, que é o cenário mais apertado que existe.
  static double larguraUtil(double larguraTela) => menuLateralFixo(larguraTela)
      ? larguraTela - larguraMenu - _divisorMenu
      : larguraTela;
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
