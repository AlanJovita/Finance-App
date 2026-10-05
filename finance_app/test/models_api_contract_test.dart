import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/models/caixa.dart';
import 'package:finance_app/models/categoria.dart';
import 'package:finance_app/models/fluxo_caixa.dart';

/// Valida o parse dos modelos contra o formato real retornado pela API
/// (finance-api.premiosistemas.com.br), capturado em testes manuais.
void main() {
  group('Categoria', () {
    test('parseia resposta real da API (id_cliente no lugar de id_loja)', () {
      // Resposta real de GET /finance/categoria/list/<id_cliente>
      final json = {
        'id': 1,
        'id_cliente': 99999,
        'descricao': 'TESTE_CLAUDE',
        'ativado': true,
        'tipo_fluxo': 1,
      };

      final categoria = Categoria.fromJson(json);

      expect(categoria.id, 1);
      expect(categoria.idLoja, 99999);
      expect(categoria.descricao, 'TESTE_CLAUDE');
      expect(categoria.ativado, true);
      expect(categoria.tipoFluxo, 1);
    });

    test('mantém compatibilidade com payload legado (id_loja)', () {
      final json = {
        'id': 2,
        'id_loja': 10,
        'descricao': 'Legado',
        'ativado': 1,
        'tipo_fluxo': 2,
      };

      final categoria = Categoria.fromJson(json);

      expect(categoria.idLoja, 10);
      expect(categoria.ativado, true);
    });
  });

  group('FluxoCaixa', () {
    test('parseia resposta no formato da API (datas d/M/yyyy, valor string)', () {
      // Formato produzido por FluxoCaixa.from_position + GenericResult na API
      final json = {
        'id': 5,
        'id_cliente': 99999,
        'id_categoria': 1,
        'descricao': 'FLUXO_TESTE',
        'valor': '150.50',
        'tipo_fluxo': 1,
        'cancelado': false,
        'confirmado': true,
        'data_criacao': '9/7/2026',
        'data_vencimento': '15/7/2026',
        'dia_vencimento': '15',
        'repeticao': '0',
        'id_ref': 0,
      };

      final fluxo = FluxoCaixa.fromJson(json);

      expect(fluxo.id, 5);
      expect(fluxo.idLoja, 99999);
      expect(fluxo.idCategoria, 1);
      expect(fluxo.valor, 150.50);
      expect(fluxo.tipoFluxo, '1');
      expect(fluxo.dataCriacao, DateTime(2026, 7, 9));
      expect(fluxo.dataVencimento, DateTime(2026, 7, 15));
      expect(fluxo.diaVencimento, 15);
    });

    test('trata data inválida "--:--" retornada pela API como null', () {
      final json = {
        'id': 6,
        'id_cliente': 99999,
        'data_criacao': '--:--',
        'data_vencimento': null,
      };

      final fluxo = FluxoCaixa.fromJson(json);

      expect(fluxo.dataCriacao, isNull);
      expect(fluxo.dataVencimento, isNull);
    });
  });

  group('Caixa', () {
    test('parseia resposta real da API (id_cliente no lugar de id_loja)', () {
      // Resposta real de GET /finance/caixa/<id_cliente>. A API devolve
      // `id_cliente`; lendo só `id_loja` o campo caía em 0 sem erro nenhum.
      final json = {
        'id': 1,
        'id_cliente': 99999,
        'id_caixa': 5,
        'id_usuario': 3,
        'saldo': 150.0,
        'status_caixa': 1,
      };

      final caixa = Caixa.fromJson(json);

      expect(caixa.idLoja, 99999);
      expect(caixa.idCaixa, 5);
      expect(caixa.idUsuario, 3);
      expect(caixa.statusCaixa, 1);
    });

    test('mantém compatibilidade com payload legado (id_loja)', () {
      final json = {'id': 2, 'id_loja': 10, 'id_usuario': 1};

      expect(Caixa.fromJson(json).idLoja, 10);
    });

    test('toApiJson envia as chaves maiúsculas que o from_dict da API lê', () {
      final caixa = Caixa.fromJson({
        'id': 1,
        'id_cliente': 42,
        'id_caixa': 7,
        'id_usuario': 3,
      });

      final payload = caixa.toApiJson();

      // O Caixa.from_dict da finance-api não aceita as chaves de toJson().
      expect(payload['ID_CLIENTE'], 42);
      expect(payload['ID_CAIXA'], 7);
      expect(payload.containsKey('total_pedido_confirmado'), isTrue);
    });
  });
}
