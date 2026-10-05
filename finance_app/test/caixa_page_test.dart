import 'package:finance_app/models/caixa.dart';
import 'package:finance_app/pages/caixa_page.dart';
import 'package:finance_app/utils/app_colors_extension.dart';
import 'package:finance_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Caixa _caixaExemplo() => Caixa(
  idLoja: 1,
  idUsuario: 1,
  idCaixa: 42,
  dataAbertura: DateTime(2026, 3, 11, 8, 30),
  dataFechamento: DateTime(2026, 3, 11, 18, 0),
  // Valores escolhidos para somar 2000 e dar percentuais distintos entre si:
  // dinheiro 50%, pix 20%, crédito 15%, débito 10%, ticket 3%, outros 2%.
  saldoDinheiro: 1000,
  saldoCartao: 500, // vira crédito 300 + débito 200
  saldoPix: 400,
  saldoTicket: 60,
  saldoOutras: 40,
  sangria: 200,
  troco: 80,
  saldo: 1800,
);

Widget _app(ThemeData theme, Caixa caixa) =>
    MaterialApp(theme: theme, home: CaixaPage(caixa: caixa));

void main() {
  group('CaixaPage', () {
    testWidgets('renderiza no tema claro', (tester) async {
      await tester.pumpWidget(_app(AppTheme.lightTheme, _caixaExemplo()));
      expect(find.text('Caixa #42'), findsOneWidget);
      expect(find.text('Detalhes do Caixa'), findsOneWidget);
    });

    testWidgets('renderiza no tema escuro', (tester) async {
      await tester.pumpWidget(_app(AppTheme.darkTheme, _caixaExemplo()));
      expect(find.text('Caixa #42'), findsOneWidget);
    });

    testWidgets('a legenda mostra o percentual de cada meio de pagamento', (
      tester,
    ) async {
      await tester.pumpWidget(_app(AppTheme.lightTheme, _caixaExemplo()));

      expect(find.textContaining('R\$ 1.000,00 · 50%'), findsOneWidget);
      expect(find.textContaining('R\$ 400,00 · 20%'), findsOneWidget);
      expect(find.textContaining('R\$ 40,00 · 2%'), findsOneWidget);
    });

    testWidgets('omite o gráfico quando não há pagamentos', (tester) async {
      final vazio = Caixa(idLoja: 1, idUsuario: 1, idCaixa: 7);
      await tester.pumpWidget(_app(AppTheme.lightTheme, vazio));

      expect(find.text('Sem dados'), findsOneWidget);
      // Sem fatias, não há legenda — mas a lista de detalhes continua lá.
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('Detalhes do Caixa'), findsOneWidget);
    });
  });

  group('AppColors', () {
    testWidgets('vem do tema nos dois modos', (tester) async {
      late AppColors claro;
      late AppColors escuro;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) {
              claro = context.appColors;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) {
              escuro = context.appColors;
              return const SizedBox();
            },
          ),
        ),
      );
      // O MaterialApp interpola a troca de tema (AnimatedTheme): sem esperar a
      // animação, `escuro` seria um estado intermediário do lerp.
      await tester.pumpAndSettle();

      expect(claro, AppColors.light);
      expect(escuro, AppColors.dark);
    });

    testWidgets('cai no padrão do modo se um Theme aninhado perder a extensão', (
      tester,
    ) async {
      late AppColors cores;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Theme(
            // ThemeData sem `extensions` — o cenário que faria o `!` estourar.
            data: ThemeData(brightness: Brightness.dark),
            child: Builder(
              builder: (context) {
                cores = context.appColors;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      expect(cores, AppColors.dark);
    });
  });
}
