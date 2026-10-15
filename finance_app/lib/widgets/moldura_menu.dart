import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/menu_provider.dart';
import '../utils/app_tokens.dart';
import 'app_drawer.dart';

/// Resolve em que forma o [AppDrawer] se apresenta — gaveta, barra recolhida ou
/// barra expandida — e põe a barra na lateral quando ela é fixa.
///
/// A regra inteira mora em [AppLayout.menuLateral]; o resumo é que **a barra
/// fica fixa sempre que couber sem derrubar a segunda coluna do Resumo**.
/// Expandida ela custa 305px e só cabe a partir de 1500; recolhida custa 73 e
/// já cabe a partir de 793, o que inclui praticamente todo notebook. Abaixo
/// disso, ou em tela baixa demais (celular deitado), volta a ser gaveta.
///
/// Embrulha a tela inteira, `AppBar` incluída — e não só o `body`. Posta dentro
/// do `body`, a barra ficaria abaixo da barra de título, e numa tela como a de
/// Receitas a barra de totais do rodapé (`bottomNavigationBar`) correria por
/// baixo dela, somando a lista debaixo do menu.
///
/// O `builder` recebe a forma porque quem monta o `Scaffold` precisa saber:
/// fixa, a tela **não** pode declarar `drawer:` — senão sobra o botão de
/// hambúrguer na barra, abrindo uma segunda cópia do menu por cima da primeira.
class MolduraMenu extends StatelessWidget {
  const MolduraMenu({super.key, required this.builder});

  final Widget Function(BuildContext context, MenuLateral menu) builder;

  @override
  Widget build(BuildContext context) {
    // Lidos a cada build, e não guardados: a janela de um navegador muda de
    // tamanho, e um valor calculado uma vez deixaria a tela no arranjo errado
    // depois do primeiro redimensionamento.
    final tela = MediaQuery.sizeOf(context);
    final colapsado = context.watch<MenuProvider>().colapsado;

    final menu = AppLayout.menuLateral(tela, preferenciaColapsado: colapsado);
    final conteudo = builder(context, menu);

    if (menu.ehGaveta) return conteudo;

    return Row(
      // `stretch` porque nem a barra nem o divisor têm altura própria: num
      // `Row` alinhado ao centro, o divisor sairia com zero de altura.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppDrawer(
          forma: menu,
          // Sem botão quando a tela não comporta as duas formas: ali a barra
          // está recolhida por imposição, não por escolha.
          onAlternar: AppLayout.podeAlternarMenu(tela)
              ? context.read<MenuProvider>().alternar
              : null,
        ),
        const VerticalDivider(width: 1),
        Expanded(child: conteudo),
      ],
    );
  }
}
