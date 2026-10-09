import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fluxo_caixa.dart';
import '../models/cartao.dart';
import '../models/categoria.dart';
import '../models/conta.dart';
import '../models/subcategoria.dart';
import '../models/caixa.dart';
import '../models/relatorio_mensal.dart';
import '../models/relatorio_semanal.dart';
import '../models/resumo_fluxo.dart';
import '../models/boleto.dart';
import 'api_config.dart';
import 'global_state.dart';
import 'logger_service.dart';

class ApiService {
  /// finance-api, não a api-master: o [LoggerService] é que continua apontando
  /// para lá, porque `/v1/erro` e `/v1/evento` não foram portados.
  final String _baseUrl = financeApiBaseUrl;
  final _logger = LoggerService();

  Future<Map<String, dynamic>> _handleRequest(
    Future<http.Response> Function() request,
    String endpoint,
  ) async {
    try {
      final response = await request();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          return json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          // Se não conseguir decodificar JSON, pode ser HTML de erro
          if (response.body.trim().startsWith('<')) {
            final error = Exception(
              'O servidor retornou HTML em vez de JSON. O endpoint pode não estar implementado.',
            );
            await _logger.logError(
              'ApiService.$endpoint',
              error,
              additionalInfo: {
                'statusCode': response.statusCode,
                'responsePreview': response.body.substring(
                  0,
                  response.body.length > 200 ? 200 : response.body.length,
                ),
              },
            );
            throw error;
          }
          rethrow;
        }
      } else {
        // Tenta extrair uma mensagem de erro mais específica do corpo da resposta
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['msg'] != null) {
            final error = Exception(errorBody['msg']);
            await _logger.logError(
              'ApiService.$endpoint',
              error,
              additionalInfo: {
                'statusCode': response.statusCode,
                'response': response.body,
              },
            );
            throw error;
          }
        } catch (e) {
          if (e is! Exception) {
            // Ignora se o corpo não for um JSON válido ou não tiver 'msg'
          } else {
            rethrow;
          }
        }
        final error = Exception(
          'Falha na comunicação. Status: ${response.statusCode}',
        );
        await _logger.logError(
          'ApiService.$endpoint',
          error,
          additionalInfo: {
            'statusCode': response.statusCode,
            'response': response.body,
          },
        );
        throw error;
      }
    } catch (e, stackTrace) {
      await _logger.logError('ApiService.$endpoint', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  // Endpoints de Fluxo de Caixa
  Future<FluxoCaixa> getFluxo(int id) async {
    try {
      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/fluxo/$id')),
        'getFluxo',
      );
      if (response['success'] == true) {
        // A API retorna data como lista (mesmo para busca por id)
        final data = response['data'];
        final item = data is List ? (data.isEmpty ? null : data.first) : data;
        if (item == null) {
          throw Exception('Fluxo não encontrado.');
        }
        return FluxoCaixa.fromJson(item as Map<String, dynamic>);
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar fluxo.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getFluxo',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id},
      );
      rethrow;
    }
  }

  /// Total por mês, somado no banco.
  ///
  /// Substituiu o `listFluxos(where)`, que mandava uma cláusula SQL pela URL e
  /// baixava o histórico inteiro da loja para somar em Dart. Aqui trafegam
  /// algumas dezenas de bytes por mês em vez de todos os lançamentos.
  Future<List<ResumoMes>> getResumoMensal({
    required int tipo,
    DateTime? de,
    DateTime? ate,
  }) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{'tipo': '$tipo'};
    if (de != null) params['de'] = _data(de);
    if (ate != null) params['ate'] = _data(ate);

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/fluxo/resumo/mensal/$idLoja',
      ).replace(queryParameters: params);

      final response = await _handleRequest(
        () => http.get(uri),
        'getResumoMensal',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((e) => ResumoMes.fromJson(e)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao carregar o resumo mensal.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getResumoMensal',
        e,
        stackTrace: stackTrace,
        additionalInfo: params,
      );
      rethrow;
    }
  }

  /// Uma página de lançamentos, filtrada por tipo e intervalo de vencimento.
  Future<PaginaFluxos> listFluxosPagina({
    required int tipo,
    DateTime? de,
    DateTime? ate,
    int pagina = 1,
    int porPagina = 100,
  }) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{
      'tipo': '$tipo',
      'pagina': '$pagina',
      'por_pagina': '$porPagina',
    };
    if (de != null) params['de'] = _data(de);
    if (ate != null) params['ate'] = _data(ate);

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/fluxo/list/$idLoja',
      ).replace(queryParameters: params);

      final response = await _handleRequest(
        () => http.get(uri),
        'listFluxosPagina',
      );

      if (response['success'] == true) {
        return PaginaFluxos.fromJson(response['data'] as Map<String, dynamic>);
      }
      throw Exception(response['msg'] ?? 'Erro ao listar lançamentos.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listFluxosPagina',
        e,
        stackTrace: stackTrace,
        additionalInfo: params,
      );
      rethrow;
    }
  }

  /// Receitas, despesas e saldo do período — previsto e realizado.
  Future<ResumoFluxo> getResumoFluxo({DateTime? de, DateTime? ate}) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{};
    if (de != null) params['de'] = _data(de);
    if (ate != null) params['ate'] = _data(ate);

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/fluxo/resumo/$idLoja',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await _handleRequest(
        () => http.get(uri),
        'getResumoFluxo',
      );

      if (response['success'] == true) {
        return ResumoFluxo.fromJson(response['data'] as Map<String, dynamic>);
      }
      throw Exception(response['msg'] ?? 'Erro ao carregar o resumo.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getResumoFluxo',
        e,
        stackTrace: stackTrace,
        additionalInfo: params,
      );
      rethrow;
    }
  }

  /// A API espera YYYY-MM-DD; `toIso8601String` traria hora junto.
  static String _data(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> createFluxo(FluxoCaixa fluxo) async {
    try {
      // A API rejeita id nulo (int(None) no from_dict); envia 0 na criação
      final body = fluxo.toJson();
      body['id'] ??= 0;

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/fluxo'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        ),
        'createFluxo',
      );
      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['msg'] ?? 'Erro ao criar fluxo.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createFluxo',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'fluxo': fluxo.toJson()},
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateFluxo(FluxoCaixa fluxo) async {
    try {
      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$_baseUrl/finance/fluxo'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(fluxo.toJson()),
        ),
        'updateFluxo',
      );
      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['msg'] ?? 'Erro ao atualizar fluxo.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateFluxo',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'fluxo': fluxo.toJson()},
      );
      rethrow;
    }
  }

  /// Replica os campos de uma edição para as outras parcelas do mesmo `id_ref`.
  ///
  /// [campos] são os nomes de coluna da API (`id_categoria`, `valor`, …) que o
  /// usuário efetivamente alterou — e não o registro inteiro: replicar tudo
  /// sobrescreveria o valor líquido que a baixa gravou em cada parcela já paga.
  /// A API descarta nome fora da lista dela e nunca toca parcela confirmada.
  ///
  /// Devolve quantas parcelas foram atualizadas.
  Future<int> updateFluxoGrupo(FluxoCaixa fluxo, List<String> campos) async {
    final corpo = {...fluxo.toJson(), 'campos': campos};

    try {
      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$_baseUrl/finance/fluxo/grupo'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(corpo),
        ),
        'updateFluxoGrupo',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao replicar a alteração.');
      }

      final data = response['data'];
      return data is Map ? (data['atualizados'] as num?)?.toInt() ?? 0 : 0;
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateFluxoGrupo',
        e,
        stackTrace: stackTrace,
        additionalInfo: corpo,
      );
      rethrow;
    }
  }

  /// Apaga um lançamento, ou o parcelamento inteiro.
  ///
  /// [idRef] é o seletor, não um dado de contexto: positivo apaga **todas** as
  /// linhas com aquele `id_ref` da loja, 0 apaga só o [id]. Quem chama decide —
  /// passar `fluxo.idRef` por reflexo transforma a exclusão de uma parcela na
  /// exclusão do lote.
  Future<Map<String, dynamic>> deleteFluxo(int id, int idRef) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.delete(
          Uri.parse('$_baseUrl/finance/fluxo/$id/$idLoja/$idRef'),
        ),
        'deleteFluxo',
      );

      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['msg'] ?? 'Erro ao deletar fluxo.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.deleteFluxo',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id, 'idRef': idRef},
      );
      rethrow;
    }
  }

  // Endpoints de Categoria
  Future<Categoria> getCategoria(int id) async {
    try {
      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/categoria/$id')),
        'getCategoria',
      );
      if (response['success'] == true) {
        return Categoria.fromJson(response['data']);
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar categoria.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getCategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id},
      );
      rethrow;
    }
  }

  Future<List<Categoria>> listCategorias() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/categoria/list/$idLoja')),
        'listCategorias',
      );
      if (response['success'] == true) {
        final List<dynamic> list = response['data'];
        return list.map((item) => Categoria.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao listar categorias.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listCategorias',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Devolve o id gerado, para o seletor já deixar marcada a categoria que o
  /// usuário acabou de criar, ou `null` quando a API confirmou a criação sem
  /// informar o id. Falha vira exceção com a mensagem da API.
  Future<int?> createCategoria(Categoria categoria) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/categoria'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(categoria.toJson()),
        ),
        'createCategoria',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao criar categoria.');
      }
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createCategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'categoria': categoria.toJson()},
      );
      rethrow;
    }
  }

  /// O id do INSERT vem em `data: [{id: N}]`. Uma API mais antiga responde
  /// `data: []` — aí o registro foi criado, mas não dá para selecioná-lo.
  int? _idCriado(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      final id = (data.first as Map)['id'];
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
    }
    return null;
  }

  // Endpoints de Subcategoria
  /// Todas as subcategorias da loja de uma vez — o modal de lançamento filtra
  /// em memória por categoria, em vez de bater na API a cada troca de círculo.
  Future<List<Subcategoria>> listSubcategorias() async {
    try {
      final idLoja = GlobalState().firstIdLoja;
      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$_baseUrl/finance/subcategoria/cliente/$idLoja'),
        ),
        'listSubcategorias',
      );
      if (response['success'] == true && response['data'] != null) {
        final List list = response['data'];
        return list.map((item) => Subcategoria.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao listar subcategorias.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listSubcategorias',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Devolve o id gerado, ou `null` quando a API confirmou a criação sem
  /// informar o id. Falha vira exceção com a mensagem da API.
  ///
  /// Antes qualquer problema virava `null` aqui, e a tela dizia "não foi
  /// possível criar" tanto para a recusa de verdade quanto para o caso em que o
  /// registro **foi** criado — levando o usuário a repetir e duplicar. Quem
  /// chama distingue os dois: exceção é falha, `null` é criado sem id.
  Future<int?> createSubcategoria(Subcategoria subcategoria) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/subcategoria'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(subcategoria.toJson()),
        ),
        'createSubcategoria',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao criar subcategoria.');
      }
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createSubcategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'subcategoria': subcategoria.toJson()},
      );
      rethrow;
    }
  }

  // Endpoints de Conta bancária
  /// Contas da loja, ativas primeiro.
  ///
  /// Quem chama isto é o [ContasCache], uma vez por sessão: o seletor do modal de
  /// lançamento precisa da lista a cada abertura, e consultar de novo a cada vez
  /// acrescentaria uma terceira requisição a um modal que já faz duas.
  Future<List<Conta>> listContas() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/conta/list/$idLoja')),
        'listContas',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => Conta.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao listar contas.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listContas',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Saldo atual e previsto de cada conta, acumulados até [ate].
  ///
  /// [ate] é o último dia do mês escolhido na tela. Os saldos somam desde o
  /// começo até essa data — a página mostra saldo de conta, não resultado do mês.
  ///
  /// A lista pode trazer uma entrada com `id == 0` ("Sem conta"), que é onde mora
  /// tudo que foi lançado antes de existir conta cadastrada.
  Future<List<SaldoConta>> getSaldosContas({DateTime? ate}) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{};
    if (ate != null) params['ate'] = _data(ate);

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/conta/saldos/$idLoja',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await _handleRequest(
        () => http.get(uri),
        'getSaldosContas',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => SaldoConta.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao carregar os saldos.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getSaldosContas',
        e,
        stackTrace: stackTrace,
        additionalInfo: params,
      );
      rethrow;
    }
  }

  /// Transferências do período, já pareadas pelo servidor — uma linha por
  /// transferência, não duas.
  ///
  /// As pernas ficam fora das listas de Receitas e Despesas, porque transferência
  /// entre contas da própria loja não é receita nem despesa; é por aqui que elas
  /// aparecem.
  Future<List<Transferencia>> listTransferencias({
    DateTime? de,
    DateTime? ate,
  }) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{};
    if (de != null) params['de'] = _data(de);
    if (ate != null) params['ate'] = _data(ate);

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/conta/transferencias/$idLoja',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await _handleRequest(
        () => http.get(uri),
        'listTransferencias',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => Transferencia.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao listar transferências.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listTransferencias',
        e,
        stackTrace: stackTrace,
        additionalInfo: params,
      );
      rethrow;
    }
  }

  /// Devolve o id gerado, ou `null` quando a API confirmou a criação sem
  /// informar o id. Falha vira exceção com a mensagem da API — a mesma distinção
  /// de [createSubcategoria], pelo mesmo motivo: tratar os dois como erro levaria
  /// o usuário a repetir e duplicar a conta.
  Future<int?> createConta(Conta conta) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/conta'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(conta.toJson()),
        ),
        'createConta',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao criar a conta.');
      }
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createConta',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'conta': conta.toJson()},
      );
      rethrow;
    }
  }

  Future<void> updateConta(Conta conta) async {
    try {
      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$_baseUrl/finance/conta'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(conta.toJson()),
        ),
        'updateConta',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao salvar a conta.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateConta',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'conta': conta.toJson()},
      );
      rethrow;
    }
  }

  /// Apaga a conta realocando as movimentações dela.
  ///
  /// [moverPara] 0 manda as movimentações para "sem conta", que é também o caminho
  /// quando a loja não tem outra conta cadastrada. Conta e movimentações são
  /// tratadas numa transação só do lado do servidor.
  Future<void> deleteConta(int id, {int moverPara = 0}) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final uri = Uri.parse(
        '$_baseUrl/finance/conta/$id/$idLoja',
      ).replace(queryParameters: {'mover_para': '$moverPara'});

      final response = await _handleRequest(
        () => http.delete(uri),
        'deleteConta',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao apagar a conta.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.deleteConta',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id, 'moverPara': moverPara},
      );
      rethrow;
    }
  }

  /// Move dinheiro entre duas contas: **uma** chamada cria as duas pernas.
  ///
  /// A despesa na origem e a receita no destino são gravadas sob transação única
  /// no servidor. Dois POST daqui no lugar disto poderiam deixar a origem
  /// debitada sem o crédito no destino — e os dois saldos errados, sem nada
  /// apontando o problema.
  Future<void> transferir({
    required int idOrigem,
    required int idDestino,
    required double valor,
    DateTime? data,
    String? observacao,
  }) async {
    final corpo = <String, dynamic>{
      'id_cliente': GlobalState().firstIdLoja,
      'id_origem': idOrigem,
      'id_destino': idDestino,
      'valor': valor,
      if (data != null) 'data': _data(data),
      if (observacao != null && observacao.trim().isNotEmpty)
        'observacao': observacao.trim(),
    };

    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/conta/transferencia'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(corpo),
        ),
        'transferir',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao transferir.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.transferir',
        e,
        stackTrace: stackTrace,
        additionalInfo: corpo,
      );
      rethrow;
    }
  }

  /// Apaga as duas pernas de uma transferência de uma vez.
  ///
  /// Não dá para usar [deleteFluxo] aqui: ele só agrupa por `id_ref`, que numa
  /// transferência é 0 — apagaria um lado só e deixaria as duas contas com saldo
  /// errado.
  Future<void> deleteTransferencia(int idTransferencia) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.delete(
          Uri.parse(
            '$_baseUrl/finance/conta/transferencia/$idTransferencia/$idLoja',
          ),
        ),
        'deleteTransferencia',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao apagar a transferência.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.deleteTransferencia',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idTransferencia': idTransferencia},
      );
      rethrow;
    }
  }

  // Endpoints de Cartão de crédito
  //
  // Nenhum destes endpoints mexe nos de Fluxo acima, e é por isso que as telas de
  // Receitas e Despesas não mudaram: compra no cartão não é saída de caixa. O que
  // entra em `finance_fluxo_caixa` é só a despesa da fatura, gerada pelo
  // [fecharFatura] — e ela é **uma só** por fatura, o que faz [pagarFatura] dar
  // baixa nela em vez de criar outra.

  /// Cartões da loja, ativos primeiro.
  ///
  /// Quem chama isto é o [CartoesCache], uma vez por sessão — mesma razão do
  /// [listContas].
  Future<List<Cartao>> listCartoes() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/cartao/list/$idLoja')),
        'listCartoes',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => Cartao.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao listar cartões.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listCartoes',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Saldo devedor, limite e recorte por fatura de cada cartão.
  ///
  /// Sem parâmetro de período, ao contrário do [getSaldosContas]: dívida de
  /// cartão é um número de **agora**, não um acumulado até uma data. Quem navega
  /// por mês é a tela da fatura, via [getFatura].
  Future<List<ResumoCartao>> getResumoCartoes() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/cartao/resumo/$idLoja')),
        'getResumoCartoes',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => ResumoCartao.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao carregar os cartões.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getResumoCartoes',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Devolve o id gerado, ou `null` quando a API confirmou a criação sem informar
  /// o id — a mesma distinção de [createConta], pelo mesmo motivo: tratar os dois
  /// como erro levaria o usuário a repetir e duplicar o cartão.
  Future<int?> createCartao(Cartao cartao) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/cartao'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cartao.toJson()),
        ),
        'createCartao',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao criar o cartão.');
      }
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'cartao': cartao.toJson()},
      );
      rethrow;
    }
  }

  Future<void> updateCartao(Cartao cartao) async {
    try {
      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$_baseUrl/finance/cartao'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(cartao.toJson()),
        ),
        'updateCartao',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao salvar o cartão.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'cartao': cartao.toJson()},
      );
      rethrow;
    }
  }

  /// Apaga o cartão.
  ///
  /// Sem [comMovimentos], a API **recusa** cartão com lançamento e devolve a
  /// contagem em `data[0]['quantidade']`: não existe "mover para outro cartão"
  /// (cada um tem o seu ciclo de fechamento), e o caminho normal para parar de
  /// usar um cartão é arquivar.
  ///
  /// Devolve a quantidade quando a recusa foi por isso, e `null` quando apagou.
  /// Falha de verdade vira exceção — tratar a recusa como erro faria a tela dizer
  /// "não foi possível" em vez de oferecer a escolha.
  Future<int?> deleteCartao(int id, {bool comMovimentos = false}) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final uri = Uri.parse('$_baseUrl/finance/cartao/$id/$idLoja').replace(
        queryParameters: comMovimentos ? {'com_movimentos': '1'} : null,
      );

      final response = await _handleRequest(() => http.delete(uri), 'deleteCartao');

      if (response['success'] == true) return null;

      final quantidade = _quantidade(response);
      if (quantidade != null) return quantidade;

      throw Exception(response['msg'] ?? 'Erro ao apagar o cartão.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.deleteCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id, 'comMovimentos': comMovimentos},
      );
      rethrow;
    }
  }

  /// `data: [{quantidade: N}]` de uma recusa que é informação, não falha.
  int? _quantidade(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is List && data.isNotEmpty && data.first is Map) {
      final q = (data.first as Map)['quantidade'];
      if (q is num) return q.toInt();
    }
    return null;
  }

  /// A fatura, os totais e os movimentos dela — uma requisição.
  ///
  /// [competencia] é o mês da fatura; sem ela, a API devolve a fatura **aberta**
  /// (a que uma compra de hoje receberia). Competência sem lançamento nenhum não
  /// é erro: vem a fatura vazia, com `id == 0` e as datas do ciclo do cartão.
  Future<FaturaDetalhe> getFatura(int idCartao, {DateTime? competencia}) async {
    final idLoja = GlobalState().firstIdLoja;
    final params = <String, String>{};
    if (competencia != null) {
      params['competencia'] = chaveCompetencia(competencia);
    }

    try {
      final uri = Uri.parse(
        '$_baseUrl/finance/cartao/fatura/$idLoja/$idCartao',
      ).replace(queryParameters: params.isEmpty ? null : params);

      final response = await _handleRequest(() => http.get(uri), 'getFatura');

      if (response['success'] == true) {
        return FaturaDetalhe.fromJson(response['data'] as Map<String, dynamic>);
      }
      throw Exception(response['msg'] ?? 'Erro ao carregar a fatura.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getFatura',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idCartao': idCartao, ...params},
      );
      rethrow;
    }
  }

  /// As competências que têm fatura, com saldo — alimenta o atalho de meses.
  Future<List<ResumoFatura>> listFaturas(int idCartao) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(
          Uri.parse('$_baseUrl/finance/cartao/faturas/$idLoja/$idCartao'),
        ),
        'listFaturas',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => ResumoFatura.fromJson(item)).toList();
      }
      throw Exception(response['msg'] ?? 'Erro ao listar as faturas.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listFaturas',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idCartao': idCartao},
      );
      rethrow;
    }
  }

  /// Fecha a fatura e gera a despesa dela no caixa.
  ///
  /// O ponto em que o cartão vira dinheiro. A despesa nasce **não confirmada**,
  /// vencendo na data de vencimento da fatura e debitando a conta de pagamento do
  /// cartão. Fatura sem saldo fecha sem gerar despesa, e aí o `id_fluxo` volta 0.
  ///
  /// Devolve o valor congelado, para a tela confirmar o que foi gerado.
  Future<double> fecharFatura(int idFatura) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/cartao/fatura/fechar/$idLoja/$idFatura'),
        ),
        'fecharFatura',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao fechar a fatura.');
      }

      final data = response['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        final valor = (data.first as Map)['valor'];
        if (valor is num) return valor.toDouble();
      }
      return 0.0;
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.fecharFatura',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idFatura': idFatura},
      );
      rethrow;
    }
  }

  /// Desfaz o fechamento: apaga a despesa gerada e reabre a fatura.
  ///
  /// DELETE do mesmo recurso que o POST cria — o fechamento. A API recusa com
  /// pagamento registrado, porque apagar a despesa faria o dinheiro que saiu da
  /// conta desaparecer do caixa.
  Future<void> reabrirFatura(int idFatura) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.delete(
          Uri.parse('$_baseUrl/finance/cartao/fatura/fechar/$idLoja/$idFatura'),
        ),
        'reabrirFatura',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao reabrir a fatura.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.reabrirFatura',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idFatura': idFatura},
      );
      rethrow;
    }
  }

  /// Registra o pagamento da fatura: crédito no cartão + baixa no caixa.
  ///
  /// [valor] nulo é "pagar o saldo", que é o caso normal.
  ///
  /// A saída de caixa **não é uma despesa nova**: é a baixa da despesa que o
  /// fechamento já gerou. Criar outra aqui faria a mesma fatura sair da conta
  /// duas vezes — é o invariante de uma despesa por fatura, e é por isso que a
  /// API exige a fatura fechada.
  ///
  /// Devolve `true` quando a fatura ficou quitada; `false` em pagamento parcial,
  /// que abate o saldo devedor do cartão mas **não** baixa a despesa (baixá-la
  /// pela parte paga exigiria modelar crédito rotativo).
  Future<bool> pagarFatura(
    int idFatura, {
    double? valor,
    DateTime? data,
    String? observacao,
  }) async {
    final corpo = <String, dynamic>{
      if (valor != null) 'valor': valor,
      if (data != null) 'data': _data(data),
      if (observacao != null && observacao.trim().isNotEmpty)
        'observacao': observacao.trim(),
    };

    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/cartao/fatura/pagar/$idLoja/$idFatura'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(corpo),
        ),
        'pagarFatura',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao registrar o pagamento.');
      }

      final data = response['data'];
      if (data is List && data.isNotEmpty && data.first is Map) {
        return (data.first as Map)['quitada'] == true;
      }
      return false;
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.pagarFatura',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idFatura': idFatura, ...corpo},
      );
      rethrow;
    }
  }

  /// Lança compra, estorno ou cashback no cartão.
  ///
  /// `total_parcelas > 1` cria as N linhas em faturas **consecutivas**, numa
  /// chamada: resolver a sequência no servidor é o que garante que ela não tenha
  /// buraco se a rede cair no meio — diferente do parcelamento do caixa, que o
  /// formulário monta com N POST. `valor` é o de **cada parcela**.
  ///
  /// Pagamento de fatura não passa por aqui: é [pagarFatura], porque paga uma
  /// fatura escolhida e dá baixa na despesa dela.
  Future<void> createMovimentoCartao(MovimentoCartao movimento) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/cartao/movimento'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(movimento.toJson()),
        ),
        'createMovimentoCartao',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao lançar no cartão.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createMovimentoCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'movimento': movimento.toJson()},
      );
      rethrow;
    }
  }

  /// Edita um lançamento do cartão.
  ///
  /// A API recusa quando a fatura já foi fechada — o valor dela foi congelado e
  /// virou uma despesa no caixa. A mensagem diz para reabrir a fatura, e é ela
  /// que a tela mostra.
  Future<void> updateMovimentoCartao(MovimentoCartao movimento) async {
    try {
      final response = await _handleRequest(
        () => http.put(
          Uri.parse('$_baseUrl/finance/cartao/movimento'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(movimento.toJson()),
        ),
        'updateMovimentoCartao',
      );
      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao salvar o lançamento.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateMovimentoCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'movimento': movimento.toJson()},
      );
      rethrow;
    }
  }

  /// Apaga um lançamento do cartão, ou a compra parcelada inteira.
  ///
  /// [idRef] é o **seletor**, não um dado de contexto — exatamente como no
  /// [deleteFluxo]: positivo apaga todas as parcelas daquele `id_ref`, 0 apaga só
  /// o [id]. Passar `movimento.idRef` por reflexo transforma "excluir esta
  /// parcela" em "excluir a compra".
  Future<void> deleteMovimentoCartao(int id, int idRef) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.delete(
          Uri.parse('$_baseUrl/finance/cartao/movimento/$id/$idLoja/$idRef'),
        ),
        'deleteMovimentoCartao',
      );

      if (response['success'] != true) {
        throw Exception(response['msg'] ?? 'Erro ao excluir o lançamento.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.deleteMovimentoCartao',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'id': id, 'idRef': idRef},
      );
      rethrow;
    }
  }

  // Endpoints de Caixa
  /// Retorna null quando a loja ainda não possui nenhum caixa registrado
  /// (a API responde success:false com msg vazia nesse caso).
  Future<Caixa?> getCaixa() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/caixa/$idLoja')),
        'getCaixa',
      );

      final data = response['data'];
      if (response['success'] == true) {
        if (data == null || data is! Map<String, dynamic>) {
          return null;
        }
        return Caixa.fromJson(data);
      } else {
        final msg = response['msg']?.toString() ?? '';
        if (msg.isEmpty) {
          return null;
        }
        throw Exception(msg);
      }
    } catch (e, stackTrace) {
      await _logger.logError('ApiService.getCaixa', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<Caixa>> getCaixas() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/caixas/$idLoja')),
        'getCaixas',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'];
        return list.map((item) => Caixa.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar lista de caixas.');
      }
    } catch (e, stackTrace) {
      await _logger.logError('ApiService.getCaixas', e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateCaixa(Caixa caixa) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/finance/caixa/$idLoja'),
          headers: {'Content-Type': 'application/json'},
          // Caixa.from_dict da API não lê as chaves de toJson (data_abertura,
          // status_caixa...); usa o formato legado de toApiJson
          body: json.encode(caixa.toApiJson()),
        ),
        'updateCaixa',
      );
      if (response['success'] == true) {
        return response;
      } else {
        throw Exception(response['msg'] ?? 'Erro ao atualizar caixa.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.updateCaixa',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'caixa': caixa.toJson()},
      );
      rethrow;
    }
  }

  // Relatório Mensal
  Future<List<RelatorioMensal>> getRelatorioMensal(int ano) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () =>
            http.get(Uri.parse('$_baseUrl/finance/caixa/mensal/$idLoja/$ano')),
        'getRelatorioMensal',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'];
        return list.map((item) => RelatorioMensal.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar relatório mensal.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getRelatorioMensal',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'ano': ano},
      );
      rethrow;
    }
  }

  // Relatório Semanal
  Future<List<RelatorioSemanal>> getRelatorioSemanal() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/finance/caixa/semanal/$idLoja')),
        'getRelatorioSemanal',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'];
        return list.map((item) => RelatorioSemanal.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar relatório semanal.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.getRelatorioSemanal',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String user, String password) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/finance/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'login': user, 'senha': password}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Tempo esgotado ao tentar conectar ao servidor');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 401) {
        final decodedJson = json.decode(response.body);
        if (decodedJson['success'] == false) {
          throw Exception(decodedJson['msg'] ?? 'Credenciais inválidas');
        }

        await _logger.logInfo(
          'Login realizado com sucesso para usuário: $user',
        );

        return decodedJson;
      } else {
        throw Exception(
          'Falha ao tentar realizar o login. Status: ${response.statusCode}',
        );
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.login',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'user': user, 'baseUrl': _baseUrl},
      );
      rethrow;
    }
  }

  /// Troca o token da URL pelos `id_cliente` a que ele dá acesso.
  ///
  /// O token é opaco e validado no servidor contra o hash guardado. Substituiu
  /// `POST /login/cnpj`, que entregava os ids a partir de um CNPJ — e CNPJ é
  /// público, então aquele endpoint não autenticava ninguém.
  ///
  /// A API responde 401 sem dizer se o token não existe, foi revogado ou o
  /// usuário está bloqueado. Não tente distinguir aqui: a indistinção é
  /// deliberada, para a rota não virar oráculo de quem sonda tokens.
  Future<List<int>> loginByToken(String token) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/finance/login/token'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': token}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Tempo esgotado ao tentar conectar ao servidor');
            },
          );

      Map<String, dynamic>? corpo;
      try {
        corpo = json.decode(response.body) as Map<String, dynamic>;
      } catch (_) {
        corpo = null;
      }

      if (response.statusCode == 200 && corpo?['success'] == true) {
        return List<int>.from(corpo!['data'] as List<dynamic>);
      }

      throw Exception(corpo?['msg'] ?? 'Link de acesso inválido');
    } catch (e, stackTrace) {
      // O token NÃO entra no log: ele é a credencial. Antes o CNPJ ia junto,
      // o que também era dado do cliente num log remoto.
      await _logger.logError(
        'ApiService.loginByToken',
        e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Boletos em aberto da loja — **vem do api-master, não da finance-api**.
  ///
  /// Boleto aqui é a cobrança da Prêmio ao lojista, não movimento de caixa: o
  /// Asaas é assunto do api-master, que já resolve o `customer_id` por
  /// `cliente_pagamento` (com fallback por CNPJ) e **pagina** as cobranças — a
  /// Asaas devolve 10 por página. A finance-api chegou a ter uma cópia disso,
  /// sem paginação e lendo uma tabela inexistente; foi removida.
  ///
  /// O `cnpj` da URL só é usado do outro lado quando o cliente ainda não está
  /// em `cliente_pagamento`. Mandá-lo cobre o cliente recém-criado.
  Future<List<Boleto>> checkBoletos(int idCliente) async {
    final cnpj = GlobalState().cnpj;

    try {
      final response = await _handleRequest(
        () => http.get(
          Uri.parse(
            '$apiBaseUrl/v1/pagamento/link/${cnpj.isEmpty ? '0' : cnpj}/$idCliente',
          ),
        ),
        'checkBoletos',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => Boleto.fromJson(item)).toList();
      }
      throw Exception(response['message'] ?? 'Erro ao buscar boletos.');
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.checkBoletos',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'idCliente': idCliente},
      );
      rethrow;
    }
  }
}
