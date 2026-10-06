import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/models/relatorio_mensal.dart';
import 'package:finance_app/utils/app_theme.dart';
import 'package:finance_app/widgets/charts/monthly_charts_widget.dart';

import 'fontes_de_teste.dart';

/// Renderiza os gráficos para inspeção visual — o validador de paleta confere
/// cor, não geometria. Colisão de rótulo, estouro de largura e eixo cortado só
/// aparecem olhando.
///
/// Atualizar as imagens: flutter test test/charts_golden_test.dart --update-goldens
List<RelatorioMensal> _meses(int quantos) {
  // Valores desiguais de propósito: com barras iguais, erro de escala não aparece.
  const somas = [18400.0, 31250.0, 12900.0, 27800.0, 23150.0, 42180.0, 9400.0, 15600.0];
  const pedidos = [210.0, 355.0, 140.0, 300.0, 255.0, 468.0, 98.0, 170.0];

  return List.generate(quantos, (i) {
    final mes = ((i) % 12) + 1;
    return RelatorioMensal(
      idLoja: 1,
      ano: 2026,
      mes: mes,
      somaSaldo: somas[i % somas.length],
      mediaSaldo: somas[i % somas.length] / 30,
      somaPedidosConfirmados: pedidos[i % pedidos.length],
      mediaPedidosConfirmados: pedidos[i % pedidos.length] / 30,
      somaPedidosEstornados: (i * 3).toDouble(),
    );
  });
}

Widget _tela(ThemeData tema, List<RelatorioMensal> dados) {
  return MaterialApp(
    theme: tema,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: MonthlyChartsWidget(relatorios: dados),
      ),
    ),
  );
}

void main() {
  setUpAll(carregarRoboto);

  testWidgets('graficos mensais — claro', (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_tela(AppTheme.lightTheme, _meses(8)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(
      find.byType(MonthlyChartsWidget),
      matchesGoldenFile('goldens/graficos_claro.png'),
    );
  });

  testWidgets('graficos mensais — escuro', (tester) async {
    tester.view.physicalSize = const Size(900, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_tela(AppTheme.darkTheme, _meses(8)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(
      find.byType(MonthlyChartsWidget),
      matchesGoldenFile('goldens/graficos_escuro.png'),
    );
  });

  testWidgets('tela estreita — rótulos não colidem', (tester) async {
    tester.view.physicalSize = const Size(380, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_tela(AppTheme.lightTheme, _meses(6)));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    await expectLater(
      find.byType(MonthlyChartsWidget),
      matchesGoldenFile('goldens/graficos_estreito.png'),
    );
  });

  test('mostra no máximo 6 meses, e os mais recentes', () {
    expect(MonthlyChartsWidget.mesesExibidos, 6);
  });
}
