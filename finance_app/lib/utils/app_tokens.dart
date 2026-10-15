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
/// Separado de [AppSpacing] porque não é respiro, é arquitetura — e porque os
/// dois números abaixo precisam concordar entre telas: a lista de lançamentos
/// e o painel de resumo trocam de arranjo na **mesma** largura, senão a janela
/// passa por um trecho em que uma tela já virou duas colunas e a outra não.
abstract final class AppLayout {
  /// A partir daqui a tela vira duas colunas: lista + formulário fixo nas
  /// Receitas/Despesas, e as duas pilhas do Resumo.
  ///
  /// 1100 não é arbitrário: abaixo disso a coluna da lista fica com menos de
  /// 600px úteis, e o card de lançamento começa a cortar a trilha de categoria
  /// — o aperto que o `CardFluxo` passa a vida evitando.
  static const double duasColunas = 1100;

  /// Largura do formulário quando ele está fixo na lateral. Estreito o
  /// bastante para a lista continuar sendo a protagonista, largo o bastante
  /// para os campos não quebrarem em duas linhas.
  static const double painelLateral = 420;

  /// Teto de largura de um bloco de conteúdo centralizado. Acima disso o olho
  /// percorre a linha inteira para ler um par rótulo/valor.
  static const double conteudoMaximo = 1400;
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
