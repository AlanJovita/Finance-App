import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/utils/situacao_fluxo.dart';

/// Faixa do `id_ref`, o agrupador das parcelas de um parcelamento.
///
/// Existe porque o estouro dessa faixa não falha de forma legível: o banco recusa
/// o INSERT, a API devolve "Falha ao executar o comando" e a mensagem real
/// ("Out of range value for column 'id_ref'") fica no log do container. O
/// formulário gerava `{idLoja}ddMMyyyyHHmmss` — 13 a 14 dígitos — e **toda conta
/// parcelada falhava**, sem nada na tela apontando para o campo culpado.
void main() {
  group('gerarIdRefParcelamento', () {
    test('cabe no INT de 4 bytes hoje', () {
      final id = gerarIdRefParcelamento();

      expect(id, greaterThan(0));
      expect(id, lessThanOrEqualTo(kIdRefMaximo));
    });

    test('continua caber nas próximas décadas', () {
      // O teto da época de 2020 é 2088. Até lá, nenhum relógio de loja gera um
      // id_ref que o banco recuse.
      for (final ano in [2026, 2030, 2050, 2080, 2087]) {
        final id = gerarIdRefParcelamento(DateTime.utc(ano, 12, 31, 23, 59, 59));

        expect(id, lessThanOrEqualTo(kIdRefMaximo), reason: 'estourou em $ano');
        expect(id, greaterThan(0), reason: 'não positivo em $ano');
      }
    });

    test('o carimbo antigo NÃO cabia — é o bug que isto previne', () {
      // {idLoja}ddMMyyyyHHmmss para a loja 0 em 07/10/2026 19:31:22, exatamente o
      // valor que apareceu no erro em produção.
      expect(7102026193122, greaterThan(kIdRefMaximo));
    });

    test('é positivo mesmo com o relógio antes da época', () {
      // `id_ref <= 0` faria a API apagar uma linha só em vez do grupo inteiro
      // (ver `RemoveFluxoCaixa` na finance-api).
      expect(gerarIdRefParcelamento(DateTime.utc(2019, 6, 1)), 1);
      expect(gerarIdRefParcelamento(DateTime.utc(1999)), 1);
    });

    test('avança com o tempo, para o grupo mais novo ter o id maior', () {
      final antes = gerarIdRefParcelamento(DateTime.utc(2026, 10, 7, 19, 31, 22));
      final depois = gerarIdRefParcelamento(DateTime.utc(2026, 10, 7, 19, 31, 23));

      expect(depois, antes + 1);
    });

    test('dois lotes no mesmo segundo colidem — e isso é aceito', () {
      // Granularidade de um segundo, igual à do esquema antigo. Toda consulta por
      // id_ref é pareada com id_cliente, então a colisão entre lojas é inofensiva.
      // O teste existe para que a escolha seja explícita, não acidental.
      final instante = DateTime.utc(2026, 10, 7, 19, 31, 22);

      expect(gerarIdRefParcelamento(instante), gerarIdRefParcelamento(instante));
    });
  });
}
