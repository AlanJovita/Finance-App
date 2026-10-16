/// Escalas de espaçamento, raio e elevação do app.
///
/// Os valores foram extraídos dos literais que já estavam espalhados por
/// `app_theme.dart` e pelas telas — não são valores novos, então trocar um
/// literal pelo token correspondente não muda nada visualmente.
///
/// Use [AppSpacing] para medidas fixas. Quando a medida varia por breakpoint,
/// use `ResponsiveUtils` (`responsive_utils.dart`), cujos defaults saem daqui.
library;

// Só pelo `Size` de [AppLayout.menuLateral]. O arquivo é de medidas, e não
// depende de Material nem de widget nenhum.
import 'dart:ui' show Size;

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

  /// Em [largura] cabem as duas tabelas da página de Categorias, lado a lado.
  ///
  /// Reusa o limiar do Resumo de propósito: o pedido era "em formato horizontal,
  /// duas colunas", e o limiar de 720 é justamente o que separa celular deitado
  /// (≈844) de celular em pé (≈390). **Largura, não orientação** — no navegador
  /// "orientação" não diz nada sobre quanto espaço existe, e uma janela
  /// estreitada continua paisagem.
  ///
  /// Como no Resumo, [largura] é a que sobra depois do menu lateral fixo
  /// ([larguraUtil]): a barra expandida come 305px, e sem descontá-la uma tela
  /// de 800 montaria duas tabelas de ~250px cada.
  ///
  /// Abaixo do limiar a lista de subcategorias não desaparece — ela passa a
  /// abrir pelo menu de três pontos da categoria.
  static bool duasTabelasCategorias(double largura) => largura >= duasColunas;

  /// A partir daqui o menu lateral cabe **expandido**, com os rótulos.
  ///
  /// É sobre a largura da tela, e não sobre a que sobra: quem decide se cabe um
  /// menu permanente é o aparelho.
  static const double menuFixo = 1500;

  /// Largura do menu expandido — o padrão do `Drawer` do Material.
  static const double larguraMenu = 304;

  /// Largura do menu recolhido só aos ícones.
  ///
  /// 72 é a medida do `NavigationRail` do Material: cabe o alvo de toque de
  /// 48px com respiro dos dois lados.
  static const double larguraMenuColapsado = 72;

  /// O divisor entre o menu e o conteúdo.
  static const double _divisorMenu = 1;

  /// Piso de largura para o menu fixo **recolhido**: o que a segunda coluna
  /// precisa, mais o que a barra de ícones ocupa. Dá 793.
  ///
  /// É o que permite a barra aparecer bem antes dos 1500px do menu expandido:
  /// recolhida ela custa 73px, e numa tela de 1366 (notebook comum) ainda
  /// sobram 1293 — as mesmas duas colunas que haveria sem barra nenhuma.
  static const double menuFixoColapsado =
      duasColunas + larguraMenuColapsado + _divisorMenu;

  /// Altura mínima para o menu ficar fixo, recolhido ou não.
  ///
  /// A barra tem **sete** itens de 48px, mais a marca, o tema e o "Sair" —
  /// abaixo disso ela vira uma lista rolante de ícones, que é pior que o botão
  /// de hambúrguer. É o que mantém **celular deitado** (≈390 de altura) na
  /// gaveta, mesmo com os 844px de largura dando de sobra para a barra
  /// recolhida.
  ///
  /// Eram 500 com seis destinos; Categorias é o sétimo, e o valor subiu os 48px
  /// de um item. **Esta constante acompanha a contagem do `AppDrawer`**: item
  /// novo no menu sem subir o piso aqui devolve a barra rolante numa faixa
  /// estreita de alturas, que é o caso que ninguém testa.
  static const double alturaMinimaMenu = 548;

  /// Como o menu se apresenta nesta tela.
  ///
  /// [preferenciaColapsado] é a escolha de quem usa (ver `MenuProvider`), e ela
  /// só é consultada quando as duas formas cabem — abaixo de [menuFixo] a barra
  /// é recolhida por imposição, não por preferência.
  static MenuLateral menuLateral(
    Size tela, {
    required bool preferenciaColapsado,
  }) {
    if (tela.height < alturaMinimaMenu) return MenuLateral.gaveta;

    if (tela.width >= menuFixo) {
      return preferenciaColapsado
          ? MenuLateral.recolhido
          : MenuLateral.expandido;
    }

    // Aqui só cabe recolhida — expandida, os 304px derrubariam a segunda
    // coluna, e aí a barra custaria mais do que entrega.
    if (tela.width >= menuFixoColapsado) return MenuLateral.recolhido;

    return MenuLateral.gaveta;
  }

  /// A tela comporta as duas formas — é o que decide se o botão de recolher
  /// aparece.
  ///
  /// Repare que **não** se pergunta isto à forma atual: quem recolheu a barra
  /// num monitor de 1920 está em [MenuLateral.recolhido] e precisa do botão
  /// justamente para desfazer. Abaixo de [menuFixo] não há botão porque não há
  /// escolha — expandida ela não cabe.
  static bool podeAlternarMenu(Size tela) =>
      tela.height >= alturaMinimaMenu && tela.width >= menuFixo;

  /// Quanto o menu tira da largura da tela, divisor incluído.
  static double larguraDoMenu(MenuLateral menu) => switch (menu) {
    MenuLateral.gaveta => 0,
    MenuLateral.recolhido => larguraMenuColapsado + _divisorMenu,
    MenuLateral.expandido => larguraMenu + _divisorMenu,
  };

  /// O que sobra da tela para o conteúdo, já descontado o menu.
  ///
  /// Descontar importa porque o menu expandido nasce em [menuFixo] = 1500, o
  /// mesmo número que é o piso de três colunas: sem a subtração, uma tela de
  /// 1500px montaria três colunas de ~367px — mais estreitas que as duas de um
  /// celular deitado, que é o cenário mais apertado que existe.
  ///
  /// E é isto que faz recolher o menu valer a pena: os 232px que ele devolve
  /// são o que cabe a terceira coluna entre 1573 e 1804px de tela.
  static double larguraUtil(double larguraTela, MenuLateral menu) =>
      larguraTela - larguraDoMenu(menu);
}

/// Em que forma o menu lateral está nesta tela — ver [AppLayout.menuLateral].
enum MenuLateral {
  /// Atrás do botão de hambúrguer, por cima da tela.
  gaveta,

  /// Fixo na lateral, só com os ícones.
  recolhido,

  /// Fixo na lateral, com ícones e rótulos.
  expandido;

  bool get ehGaveta => this == MenuLateral.gaveta;

  bool get ehFixo => !ehGaveta;
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
