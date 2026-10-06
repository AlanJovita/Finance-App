import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:responsive_framework/responsive_framework.dart';

import 'package:finance_app/models/categoria.dart';
import 'package:finance_app/models/fluxo_caixa.dart';
import 'package:finance_app/models/subcategoria.dart';
import 'package:finance_app/pages/fluxos_page.dart';
import 'package:finance_app/utils/app_colors_extension.dart';
import 'package:finance_app/utils/app_theme.dart';
import 'package:finance_app/widgets/card_fluxo.dart';
import 'package:finance_app/widgets/detalhes_mes_dialog.dart';

import 'fontes_de_teste.dart';

/// Data de referência fixa. A situação de cada card é relativa a "hoje", e sem
/// um hoje fixo o teste mudaria de resultado conforme o calendário da máquina.
final DateTime _hoje = DateTime(2026, 10, 6);

Categoria _categoria(int id, String descricao, String icone, String cor) =>
    Categoria(
      id: id,
      idLoja: 1,
      descricao: descricao,
      tipoFluxo: 2,
      icone: icone,
      cor: cor,
    );

Subcategoria _subcategoria(int id, int idCategoria, String descricao,
        String icone) =>
    Subcategoria(
      id: id,
      idCategoria: idCategoria,
      descricao: descricao,
      icone: icone,
    );

FluxoCaixa _fluxo({
  required int id,
  required String descricao,
  required double valor,
  DateTime? vencimento,
  bool confirmado = false,
  int idCategoria = 0,
  int idSubcategoria = 0,
  int idRef = 0,
  String repeticao = '1',
}) => FluxoCaixa(
  id: id,
  idLoja: 1,
  idCategoria: idCategoria,
  idSubcategoria: idSubcategoria,
  descricao: descricao,
  valor: valor,
  tipoFluxo: '2',
  cancelado: false,
  confirmado: confirmado,
  dataCriacao: DateTime(2026, 9, 1),
  dataVencimento: vencimento,
  diaVencimento: vencimento?.day ?? 0,
  repeticao: repeticao,
  idRef: idRef,
);

final _categorias = {
  1: _categoria(1, 'Casa', 'home', '#1E88E5'),
  2: _categoria(2, 'Transporte', 'directions_car', '#8E24AA'),
  3: _categoria(3, 'Fornecedores', 'handshake', '#FB8C00'),
};

final _subcategorias = {
  10: _subcategoria(10, 1, 'Energia', 'bolt'),
  11: _subcategoria(11, 2, 'Combustível', 'local_gas_station'),
};

/// Um caso por situação, mais os extremos que apertam o layout: descrição
/// longa, valor na casa do milhão e o rótulo mais comprido
/// ("Próximo do vencimento") competindo com a trilha de categoria.
final _casos = <FluxoCaixa>[
  _fluxo(
    id: 1,
    descricao: 'Aluguel da loja',
    valor: 2350,
    vencimento: DateTime(2026, 10, 1),
    idCategoria: 1,
    idRef: 990,
    repeticao: '4',
  ),
  _fluxo(
    id: 2,
    descricao: 'Conta de energia elétrica',
    valor: 486.9,
    vencimento: DateTime(2026, 10, 3),
    confirmado: true,
    idCategoria: 1,
    idSubcategoria: 10,
  ),
  _fluxo(
    id: 3,
    descricao: 'Combustível da entrega',
    valor: 320,
    vencimento: DateTime(2026, 10, 6),
    idCategoria: 2,
    idSubcategoria: 11,
  ),
  _fluxo(
    id: 4,
    descricao:
        'Reposição de estoque do fornecedor principal da loja matriz',
    valor: 1234567.89,
    vencimento: DateTime(2026, 10, 9),
    idCategoria: 3,
  ),
  _fluxo(
    id: 5,
    descricao: 'Manutenção do ar-condicionado',
    valor: 890,
    vencimento: DateTime(2026, 10, 25),
  ),
  _fluxo(
    id: 6,
    descricao: 'Adiantamento sem vencimento definido',
    valor: 150,
  ),
];

Widget _lista(ThemeData tema) {
  return MaterialApp(
    theme: tema,
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final f in _casos)
            CardFluxo(
              fluxo: f,
              categoria: _categorias[f.idCategoria],
              subcategoria: _subcategorias[f.idSubcategoria],
              // Despesa: a tela passa `cores.error` do tema em uso.
              corValor:
                  (tema.extension<AppColors>() ??
                          (tema.brightness == Brightness.dark
                              ? AppColors.dark
                              : AppColors.light))
                      .error,
              rotuloAcao: 'Pagar',
              hoje: _hoje,
              onEditar: () {},
              onBaixar: () {},
              onEstornar: () {},
              onExcluir: () {},
            ),
        ],
      ),
    ),
  );
}

Widget _detalhes(ThemeData tema) {
  return MaterialApp(
    theme: tema,
    // O modal consulta `ResponsiveUtils` para escolher a própria largura, e
    // isso exige os mesmos breakpoints que o `main.dart` instala.
    builder:
        (context, child) => ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: [
            const Breakpoint(start: 0, end: 450, name: MOBILE),
            const Breakpoint(start: 451, end: 800, name: TABLET),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
        ),
    home: Scaffold(
      body: Center(
        child: DetalhesMesDialog(
          mesReferencia: 'Outubro 2026',
          itens: _casos,
          ehReceita: false,
        ),
      ),
    ),
  );
}

/// A página inteira, com a API indisponível.
///
/// `FluxosPage` instancia `ApiService` no `initState` e o teste não tem rede, o
/// que exercita justamente o caminho de falha: o que interessa aqui é a moldura
/// — barra de mês, busca, filtro e o resumo do rodapé — que não depende dos
/// dados e é onde o layout pode estourar.
Widget _pagina(ThemeData tema) {
  return MaterialApp(
    theme: tema,
    builder:
        (context, child) => ResponsiveBreakpoints.builder(
          child: child!,
          breakpoints: [
            const Breakpoint(start: 0, end: 450, name: MOBILE),
            const Breakpoint(start: 451, end: 800, name: TABLET),
            const Breakpoint(start: 801, end: 1920, name: DESKTOP),
            const Breakpoint(start: 1921, end: double.infinity, name: '4K'),
          ],
        ),
    home: const FluxosPage(tipo: TipoFluxo.despesa),
  );
}

void main() {
  setUpAll(carregarRoboto);

  for (final (nome, largura) in const [
    ('desktop', 900.0),
    ('estreito', 360.0),
  ]) {
    testWidgets('cards de lançamento — $nome não estoura', (tester) async {
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_lista(AppTheme.lightTheme));
      await tester.pumpAndSettle();

      // `pumpAndSettle` não falha sozinho com RenderFlex overflow: o erro vai
      // para a fila de exceções do binding e some se ninguém o drenar.
      expect(tester.takeException(), isNull);

      await expectLater(
        find.byType(ListView),
        matchesGoldenFile('goldens/fluxos_cards_$nome.png'),
      );
    });
  }

  testWidgets('cards de lançamento — escuro', (tester) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_lista(AppTheme.darkTheme));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(ListView),
      matchesGoldenFile('goldens/fluxos_cards_escuro.png'),
    );
  });

  for (final (nome, largura) in const [
    ('desktop', 900.0),
    ('estreito', 360.0),
  ]) {
    testWidgets('modal de detalhes — $nome', (tester) async {
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_detalhes(AppTheme.darkTheme));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(DetalhesMesDialog),
        matchesGoldenFile('goldens/fluxos_detalhes_$nome.png'),
      );
    });
  }

  for (final (nome, largura) in const [
    ('desktop', 900.0),
    ('estreito', 360.0),
  ]) {
    testWidgets('tela de despesas — $nome', (tester) async {
      tester.view.physicalSize = Size(largura, 720);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_pagina(AppTheme.darkTheme));
      await tester.pump(const Duration(seconds: 1));

      // As falhas de rede são capturadas pela própria tela; o que não pode
      // escapar é erro de layout.
      final excecao = tester.takeException();
      expect(
        '$excecao'.contains('overflow'),
        isFalse,
        reason: 'layout estourou: $excecao',
      );

      await expectLater(
        find.byType(FluxosPage),
        matchesGoldenFile('goldens/fluxos_tela_$nome.png'),
      );
    });
  }
}
