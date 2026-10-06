import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fluxo_caixa.dart';
import '../models/categoria.dart';
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
  /// usuário acabou de criar. Null em falha.
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
      if (response['success'] != true) return null;
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createCategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'categoria': categoria.toJson()},
      );
      return null;
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

  /// Devolve o id gerado. Null em falha.
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
      if (response['success'] != true) return null;
      return _idCriado(response);
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createSubcategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'subcategoria': subcategoria.toJson()},
      );
      return null;
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
