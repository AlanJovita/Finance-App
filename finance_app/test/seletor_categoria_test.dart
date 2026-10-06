import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/utils/categoria_visuais.dart';
import 'package:finance_app/widgets/seletor_categoria.dart';

/// As regras de exibição do card de categorias/subcategorias:
/// 0 itens → mensagem e botão piscando; 1 a 4 → só círculos; 5+ → 4 círculos
/// em destaque mais o combobox com todos.
void main() {
  ItemSelecionavel item(
    int id, {
    String? icone,
    bool destaque = false,
    String? nome,
  }) => ItemSelecionavel(
    id: id,
    descricao: nome ?? 'Categoria $id',
    icone: icone,
    cor: const Color(0xFF1E88E5),
    destaque: destaque,
  );

  Future<int?> montar(
    WidgetTester tester, {
    required List<ItemSelecionavel> itens,
    int? selecionadoId,
    VoidCallback? onNovo,
  }) async {
    int? escolhido;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeletorCategoria(
            titulo: 'Categorias',
            rotuloBotaoNovo: 'nova categoria',
            mensagemVazio: 'Nenhuma categoria cadastrada',
            itens: itens,
            selecionadoId: selecionadoId,
            onSelecionar: (id) => escolhido = id,
            onNovo: onNovo ?? () {},
          ),
        ),
      ),
    );

    return escolhido;
  }

  final combobox = find.byType(DropdownButtonFormField<int>);

  testWidgets('sem categoria cadastrada mostra a mensagem e esconde o combobox', (
    tester,
  ) async {
    await montar(tester, itens: const []);

    expect(find.text('Nenhuma categoria cadastrada'), findsOneWidget);
    expect(combobox, findsNothing);
  });

  testWidgets('o botão de nova categoria pisca enquanto a lista está vazia', (
    tester,
  ) async {
    await montar(tester, itens: const []);

    double opacidade() =>
        tester
            .widget<FadeTransition>(find.byKey(SeletorCategoria.chavePiscar))
            .opacity
            .value;

    final inicial = opacidade();
    await tester.pump(const Duration(milliseconds: 375));

    expect(
      opacidade(),
      isNot(inicial),
      reason: 'sem animação o botão não chama atenção na tela vazia',
    );

    // Deixa a animação parada para o teste não terminar com timer pendente.
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('com 4 categorias não exibe o combobox', (tester) async {
    await montar(tester, itens: [item(1), item(2), item(3), item(4)]);

    expect(combobox, findsNothing);
    expect(find.text('Categoria 1'), findsOneWidget);
    expect(find.text('Categoria 4'), findsOneWidget);
    expect(
      find.byKey(SeletorCategoria.chavePiscar),
      findsNothing,
      reason: 'com categoria cadastrada o botão não pisca',
    );
  });

  testWidgets('com 5 categorias exibe 4 círculos e o combobox', (tester) async {
    await montar(
      tester,
      itens: [item(1), item(2), item(3), item(4), item(5)],
    );

    expect(combobox, findsOneWidget);

    // A quinta só existe dentro do combobox — não ganhou círculo.
    expect(find.text('Categoria 5'), findsNothing);
  });

  testWidgets('os círculos preferem as categorias marcadas como destaque', (
    tester,
  ) async {
    await montar(
      tester,
      itens: [
        item(1),
        item(2),
        item(3, destaque: true),
        item(4),
        item(5, destaque: true),
        item(6),
      ],
    );

    // 3 e 5 têm destaque, então entram antes das sem destaque; sobram duas
    // vagas para as duas primeiras da ordem original.
    expect(find.text('Categoria 3'), findsOneWidget);
    expect(find.text('Categoria 5'), findsOneWidget);
    expect(find.text('Categoria 1'), findsOneWidget);
    expect(find.text('Categoria 2'), findsOneWidget);
    expect(find.text('Categoria 4'), findsNothing);
    expect(find.text('Categoria 6'), findsNothing);
  });

  testWidgets('categoria sem ícone cai no genérico, com o nome embaixo', (
    tester,
  ) async {
    await montar(tester, itens: [item(1, nome: 'Aluguel')]);

    expect(find.byIcon(CategoriaVisuais.iconeGenerico), findsOneWidget);
    expect(find.text('Aluguel'), findsOneWidget);
  });

  testWidgets('categoria com ícone cadastrado usa o ícone do catálogo', (
    tester,
  ) async {
    await montar(tester, itens: [item(1, icone: 'shopping_cart')]);

    expect(find.byIcon(Icons.shopping_cart), findsOneWidget);
    expect(find.byIcon(CategoriaVisuais.iconeGenerico), findsNothing);
  });

  testWidgets('tocar num círculo seleciona a categoria', (tester) async {
    int? escolhido;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeletorCategoria(
            titulo: 'Categorias',
            rotuloBotaoNovo: 'nova categoria',
            mensagemVazio: 'Nenhuma categoria cadastrada',
            itens: [item(1), item(7, nome: 'Mercado')],
            selecionadoId: null,
            onSelecionar: (id) => escolhido = id,
            onNovo: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mercado'));
    expect(escolhido, 7);
  });

  testWidgets('tocar no círculo já selecionado limpa a seleção', (
    tester,
  ) async {
    int? escolhido = -1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SeletorCategoria(
            titulo: 'Categorias',
            rotuloBotaoNovo: 'nova categoria',
            mensagemVazio: 'Nenhuma categoria cadastrada',
            itens: [item(7, nome: 'Mercado')],
            selecionadoId: 7,
            onSelecionar: (id) => escolhido = id,
            onNovo: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mercado'));
    expect(escolhido, isNull, reason: 'categoria é opcional no lançamento');
  });

  testWidgets('o botão de nova categoria dispara o callback', (tester) async {
    var chamou = false;
    await montar(tester, itens: [item(1)], onNovo: () => chamou = true);

    await tester.tap(find.text('nova categoria'));
    expect(chamou, isTrue);
  });
}
