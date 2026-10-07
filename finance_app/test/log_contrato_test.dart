import 'package:flutter_test/flutter_test.dart';

import 'package:finance_app/models/erro.dart';
import 'package:finance_app/models/evento.dart';
import 'package:finance_app/services/api_config.dart';

/// Contrato do payload de log que o api-master consome em `/v1/erro` e
/// `/v1/evento`.
///
/// O que está travado aqui é o `id_software`. Ele é opcional no api-master:
/// `Erro.from_dict` cai num default quando a chave não vem, e a linha é gravada
/// com `id_software` nulo sem erro nenhum — o app continua funcionando e o log
/// simplesmente deixa de ser atribuível ao Finance no painel do suporte. Foi
/// exatamente assim que ficou até esta versão.
void main() {
  Erro erroExemplo() => Erro(
    idLog: 0,
    idCliente: 42,
    data: '2026-10-07 10:00:00',
    descricao: 'Erro: qualquer',
    versao: versaoLog,
    classe: 'ApiService',
    metodo: 'getCaixa',
    linha: 10,
    qtd: 1,
    status: 0,
    classificacao: 0,
    origem: idSoftwareFinance,
    idUsuarioLocal: 0,
    idComputadorLocal: 0,
  );

  group('payload de erro', () {
    test('leva id_software do Finance', () {
      expect(erroExemplo().toJson()['id_software'], 10);
    });

    test('id_software não precisa ser informado pelo chamador', () {
      // O default do construtor é o que garante a cobertura: nenhum ponto do
      // app monta um Erro passando o campo à mão.
      expect(erroExemplo().idSoftware, idSoftwareFinance);
    });

    test('a versão distingue o app da finance-api', () {
      // Os dois gravam id_software = 10, e `origem` não chega ao banco — o
      // api-master não o mapeia em Erro.to_supabase(). Sobra a versão.
      final versao = erroExemplo().toJson()['versao'] as String;

      expect(versao, contains('finance-app'));
      expect(versao, isNot(contains('finance-api')));
    });

    test('sobrevive à ida e volta pelo JSON', () {
      final json = erroExemplo().toJson();

      expect(Erro.fromJson(json).idSoftware, 10);
    });

    test('payload antigo, sem a chave, assume o Finance', () {
      final json = erroExemplo().toJson()..remove('id_software');

      expect(Erro.fromJson(json).idSoftware, idSoftwareFinance);
    });
  });

  group('payload de evento', () {
    Evento eventoExemplo() => Evento(
      idCliente: 42,
      data: '2026-10-07 10:00:00',
      descricao: 'qualquer',
      origem: idSoftwareFinance,
      idUsuarioLocal: 0,
    );

    test('leva id_software do Finance', () {
      expect(eventoExemplo().toJson()['id_software'], 10);
    });

    test('sobrevive à ida e volta pelo JSON', () {
      expect(Evento.fromJson(eventoExemplo().toJson()).idSoftware, 10);
    });
  });
}
