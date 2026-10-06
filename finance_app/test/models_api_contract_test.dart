import 'package:flutter_test/flutter_test.dart';
import 'package:finance_app/models/boleto.dart';
import 'package:finance_app/models/caixa.dart';
import 'package:finance_app/models/categoria.dart';
import 'package:finance_app/models/fluxo_caixa.dart';
import 'package:finance_app/models/resumo_fluxo.dart';
import 'package:finance_app/models/subcategoria.dart';

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

    test('lê destaque, icone e cor', () {
      final categoria = Categoria.fromJson({
        'id': 3,
        'id_cliente': 99999,
        'descricao': 'Mercado',
        'ativado': true,
        'tipo_fluxo': 2,
        'destaque': true,
        'icone': 'shopping_cart',
        'cor': '#E53935',
      });

      expect(categoria.destaque, true);
      expect(categoria.icone, 'shopping_cart');
      expect(categoria.cor, '#E53935');
    });

    test('tolera API antiga, sem os campos visuais', () {
      final categoria = Categoria.fromJson({
        'id': 4,
        'id_cliente': 99999,
        'descricao': 'Aluguel',
        'ativado': true,
        'tipo_fluxo': 2,
      });

      expect(categoria.destaque, false);
      expect(categoria.icone, isNull);
      expect(categoria.cor, isNull);
    });

    test('envia destaque como inteiro, que é o tipo da coluna', () {
      final json =
          Categoria(
            idLoja: 1,
            descricao: 'Mercado',
            ativado: true,
            tipoFluxo: 2,
            destaque: true,
            icone: 'shopping_cart',
            cor: '#E53935',
          ).toJson();

      expect(json['destaque'], 1);
      expect(json['ativado'], 1);
      expect(json['icone'], 'shopping_cart');
      expect(json['cor'], '#E53935');
    });
  });

  group('Subcategoria', () {
    test('parseia o vínculo com a categoria pai', () {
      final sub = Subcategoria.fromJson({
        'id': 8,
        'id_categoria': 3,
        'descricao': 'Hortifruti',
        'ativado': true,
        'destaque': true,
        'icone': 'eco',
      });

      expect(sub.id, 8);
      expect(sub.idCategoria, 3);
      expect(sub.descricao, 'Hortifruti');
      expect(sub.destaque, true);
      expect(sub.icone, 'eco');
    });

    test('serializa sem cor — a cor vem da categoria pai', () {
      final json =
          Subcategoria(
            idCategoria: 3,
            descricao: 'Hortifruti',
            ativado: true,
            destaque: false,
          ).toJson();

      expect(json.containsKey('cor'), isFalse);
      expect(json['id_categoria'], 3);
      expect(json['destaque'], 0);
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

    test('toApiJson envia as chaves maiusculas que o from_dict da API le', () {
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

  group('Resumo agregado no banco', () {
    test('ResumoMes parseia GET /fluxo/resumo/mensal', () {
      final mes = ResumoMes.fromJson({
        'ano': 2026,
        'mes': 10,
        'total': 1200.50,
        'total_realizado': 900.0,
        'quantidade': 4,
      });

      expect(mes.chave, '2026-10');
      expect(mes.semData, isFalse);
      expect(mes.total, 1200.50);
      expect(mes.quantidade, 4);
    });

    test('ResumoMes com vencimento nulo vira o grupo "sem-data"', () {
      final mes = ResumoMes.fromJson({
        'ano': null,
        'mes': null,
        'total': 50.0,
        'total_realizado': 0.0,
        'quantidade': 1,
      });

      expect(mes.semData, isTrue);
      expect(mes.chave, 'sem-data');
    });

    test('ResumoMes aceita total como string (DECIMAL vira texto)', () {
      expect(ResumoMes.fromJson({'ano': 2026, 'mes': 1, 'total': '87.30'}).total,
          87.30);
    });

    test('PaginaFluxos expõe o controle de paginação', () {
      final pagina = PaginaFluxos.fromJson({
        'itens': [
          {'id': 1, 'id_cliente': 42, 'valor': '10.00'},
        ],
        'pagina': 2,
        'por_pagina': 100,
        'total': 250,
        'tem_proxima': true,
      });

      expect(pagina.itens.length, 1);
      expect(pagina.pagina, 2);
      expect(pagina.total, 250);
      expect(pagina.temProxima, isTrue);
    });

    test('PaginaFluxos tolera resposta sem itens', () {
      final pagina = PaginaFluxos.fromJson({
        'pagina': 1,
        'por_pagina': 100,
        'total': 0,
        'tem_proxima': false,
      });

      expect(pagina.itens, isEmpty);
      expect(pagina.temProxima, isFalse);
    });

    test('Boleto parseia a resposta do api-master', () {
      // Resposta real de GET /v1/pagamento/link/<cnpj>/<id_cliente>, capturada
      // em produção. Boleto vem do api-master, não da finance-api: lá o model
      // é `Boleto` (dataclass serializada), não o objeto cru da Asaas — mas os
      // três campos que o app lê têm o mesmo nome.
      final json = {
        'object': 'payment',
        'id': 'pay_gx3guuh521uwmb0o',
        'dateCreated': '2026-10-02',
        'customer': 'cus_000065459949',
        'paymentLink': 'None',
        'billingType': 'BOLETO',
        'value': 52.0,
        'dueDate': '2026-11-10',
        'description': 'Mensalidade de uso de software Syscon Software',
        'status': 'PENDING',
        'deleted': false,
        'invoiceUrl': 'https://www.asaas.com/i/gx3guuh521uwmb0o',
        'loja': null,
      };

      final boleto = Boleto.fromJson(json);

      expect(boleto.status, 'PENDING');
      expect(boleto.dueDate, '2026-11-10');
      expect(boleto.invoiceUrl, 'https://www.asaas.com/i/gx3guuh521uwmb0o');
      expect(boleto.isPending, isTrue);
      expect(boleto.isOverdue, isFalse);
      expect(boleto.dueDateParsed, DateTime(2026, 11, 10));
    });

    test('ResumoFluxo separa previsto de realizado', () {
      final r = ResumoFluxo.fromJson({
        'receitas_previsto': 1500.0,
        'despesas_previsto': 400.0,
        'saldo_previsto': 1100.0,
        'receitas_realizado': 1000.0,
        'despesas_realizado': 250.0,
        'saldo_realizado': 750.0,
        'quantidade': 9,
      });

      expect(r.saldoPrevisto, 1100.0);
      expect(r.saldoRealizado, 750.0);
      expect(r.quantidade, 9);
    });
  });
}
