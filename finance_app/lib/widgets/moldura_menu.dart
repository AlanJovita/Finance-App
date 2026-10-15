import 'package:flutter/material.dart';

import '../utils/app_tokens.dart';
import 'app_drawer.dart';

/// Põe o [AppDrawer] **fixo** na lateral acima de [AppLayout.menuFixo], e o
/// deixa como gaveta abaixo disso.
///
/// Embrulha a tela inteira, `AppBar` incluída — e não só o `body`. Posto dentro
/// do `body`, o menu ficaria abaixo da barra de título, e numa tela como a de
/// Receitas a barra de totais do rodapé (`bottomNavigationBar`) correria por
/// baixo dele, somando a lista debaixo do menu. Fixo, ele é a primeira coluna da
/// janela; tudo o mais vive à direita.
///
/// O `builder` recebe se o menu está fixo porque quem monta o `Scaffold` precisa
/// saber: fixo, a tela **não** pode declarar `drawer:` — senão sobra o botão de
/// hambúrguer na barra, abrindo uma segunda cópia do menu por cima da primeira.
class MolduraMenu extends StatelessWidget {
  const MolduraMenu({super.key, required this.builder});

  final Widget Function(BuildContext context, bool menuFixo) builder;

  @override
  Widget build(BuildContext context) {
    // Lido do `MediaQuery` a cada build, e não guardado: a janela de um
    // navegador muda de tamanho, e um booleano calculado uma vez deixaria a
    // tela no arranjo errado depois do primeiro redimensionamento.
    final fixo = AppLayout.menuLateralFixo(MediaQuery.sizeOf(context).width);
    final tela = builder(context, fixo);

    if (!fixo) return tela;

    return Row(
      // `stretch` porque nem o menu nem o divisor têm altura própria: num `Row`
      // alinhado ao centro, o divisor sairia com zero de altura.
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppDrawer(fixo: true),
        const VerticalDivider(width: 1),
        Expanded(child: tela),
      ],
    );
  }
}
