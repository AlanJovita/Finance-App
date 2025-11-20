import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fluxo_caixa.dart';
import '../models/categoria.dart';
import '../models/caixa.dart';
import '../models/relatorio_mensal.dart';
import '../models/relatorio_semanal.dart';
import '../models/boleto.dart';
import 'global_state.dart';
import 'logger_service.dart';

class ApiService {
  final String _baseUrl = 'https://finance-api.premiosistemas.com.br';
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
        () => http.get(Uri.parse('$_baseUrl/fluxo/$id')),
        'getFluxo',
      );
      if (response['success'] == true) {
        return FluxoCaixa.fromJson(response['data']);
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

  Future<List<FluxoCaixa>> listFluxos(String where) async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/fluxo/list/$idLoja/$where')),
        'listFluxos',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'];
        return list.map((item) => FluxoCaixa.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao listar fluxos.');
      }
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.listFluxos',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'where': where},
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createFluxo(FluxoCaixa fluxo) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/fluxo'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(fluxo.toJson()),
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
          Uri.parse('$_baseUrl/fluxo'),
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
        () => http.delete(Uri.parse('$_baseUrl/fluxo/$id/$idLoja/$idRef')),
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
        () => http.get(Uri.parse('$_baseUrl/categoria/$id')),
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
        () => http.get(Uri.parse('$_baseUrl/categoria/list/$idLoja')),
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

  Future<bool> createCategoria(Categoria categoria) async {
    try {
      final response = await _handleRequest(
        () => http.post(
          Uri.parse('$_baseUrl/categoria'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(categoria.toJson()),
        ),
        'createCategoria',
      );
      return response['success'] == true;
    } catch (e, stackTrace) {
      await _logger.logError(
        'ApiService.createCategoria',
        e,
        stackTrace: stackTrace,
        additionalInfo: {'categoria': categoria.toJson()},
      );
      return false;
    }
  }

  // Endpoints de Caixa
  Future<Caixa> getCaixa() async {
    try {
      final idLoja = GlobalState().firstIdLoja;

      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/caixa/$idLoja')),
        'getCaixa',
      );

      if (response['success'] == true) {
        if (response['data'] == null) {
          throw Exception('Caixa não encontrado para a loja $idLoja.');
        }
        return Caixa.fromJson(response['data']);
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar caixa.');
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
        () => http.get(Uri.parse('$_baseUrl/caixas/$idLoja')),
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
          Uri.parse('$_baseUrl/caixa/$idLoja'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(caixa.toJson()),
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
        () => http.get(Uri.parse('$_baseUrl/caixa/mensal/$idLoja/$ano')),
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
        () => http.get(Uri.parse('$_baseUrl/caixa/semanal/$idLoja')),
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
            Uri.parse('$_baseUrl/login'),
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

  // Boletos
  Future<List<Boleto>> checkBoletos(int idCliente) async {
    try {
      final response = await _handleRequest(
        () => http.get(Uri.parse('$_baseUrl/boletos/check/$idCliente')),
        'checkBoletos',
      );

      if (response['success'] == true) {
        final List<dynamic> list = response['data'] ?? [];
        return list.map((item) => Boleto.fromJson(item)).toList();
      } else {
        throw Exception(response['msg'] ?? 'Erro ao buscar boletos.');
      }
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
