import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/fluxo_caixa.dart';
import '../models/categoria.dart';
import '../models/caixa.dart';
import '../models/relatorio_mensal.dart';
import '../models/relatorio_semanal.dart';
import 'global_state.dart';

class ApiService {
  final String _baseUrl = 'http://localhost:5000';
  // Cache simples em memória

  Future<Map<String, dynamic>> _handleRequest(
    Future<http.Response> Function() request,
  ) async {
    try {
      final response = await request();
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        // Tenta extrair uma mensagem de erro mais específica do corpo da resposta
        try {
          final errorBody = json.decode(response.body);
          if (errorBody['msg'] != null) {
            throw Exception(errorBody['msg']);
          }
        } catch (_) {
          // Ignora se o corpo não for um JSON válido ou não tiver 'msg'
        }
        throw Exception('Falha na comunicação. Status: ${response.statusCode}');
      }
    } catch (e) {
      // Apenas repassa a exceção para ser tratada pela camada de UI
      rethrow;
    }
  }

  // Endpoints de Fluxo de Caixa
  Future<FluxoCaixa> getFluxo(int id) async {
    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/fluxo/$id')),
    );
    if (response['success'] == true) {
      return FluxoCaixa.fromJson(response['data']);
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar fluxo.');
    }
  }

  Future<List<FluxoCaixa>> listFluxos(String where) async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/fluxo/list/$idLoja/$where')),
    );

    if (response['success'] == true) {
      final List<dynamic> list = response['data'];
      return list.map((item) => FluxoCaixa.fromJson(item)).toList();
    } else {
      throw Exception(response['msg'] ?? 'Erro ao listar fluxos.');
    }
  }

  Future<Map<String, dynamic>> createFluxo(FluxoCaixa fluxo) async {
    final response = await _handleRequest(
      () => http.post(
        Uri.parse('$_baseUrl/fluxo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(fluxo.toJson()),
      ),
    );
    if (response['success'] == true) {
      return response;
    } else {
      throw Exception(response['msg'] ?? 'Erro ao criar fluxo.');
    }
  }

  Future<Map<String, dynamic>> updateFluxo(FluxoCaixa fluxo) async {
    final response = await _handleRequest(
      () => http.put(
        Uri.parse('$_baseUrl/fluxo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(fluxo.toJson()),
      ),
    );
    if (response['success'] == true) {
      return response;
    } else {
      throw Exception(response['msg'] ?? 'Erro ao atualizar fluxo.');
    }
  }

  Future<Map<String, dynamic>> deleteFluxo(int id, int idRef) async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.delete(Uri.parse('$_baseUrl/fluxo/$id/$idLoja/$idRef')),
    );
    if (response['success'] == true) {
      return response;
    } else {
      throw Exception(response['msg'] ?? 'Erro ao deletar fluxo.');
    }
  }

  // Endpoints de Categoria
  Future<Categoria> getCategoria(int id) async {
    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/categoria/$id')),
    );
    if (response['success'] == true) {
      return Categoria.fromJson(response['data']);
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar categoria.');
    }
  }

  Future<List<Categoria>> listCategorias() async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/categoria/list/$idLoja')),
    );
    if (response['success'] == true) {
      final List<dynamic> list = response['data'];
      return list.map((item) => Categoria.fromJson(item)).toList();
    } else {
      throw Exception(response['msg'] ?? 'Erro ao listar categorias.');
    }
  }

  // Endpoints de Caixa
  Future<Caixa> getCaixa() async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/caixa/$idLoja')),
    );

    if (response['success'] == true) {
      if (response['data'] == null) {
        throw Exception('Caixa não encontrado para a loja $idLoja.');
      }
      return Caixa.fromJson(response['data']);
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar caixa.');
    }
  }

  Future<List<Caixa>> getCaixas() async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/caixas/$idLoja')),
    );

    if (response['success'] == true) {
      final List<dynamic> list = response['data'];
      return list.map((item) => Caixa.fromJson(item)).toList();
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar lista de caixas.');
    }
  }

  Future<Map<String, dynamic>> updateCaixa(Caixa caixa) async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.post(
        Uri.parse('$_baseUrl/caixa/$idLoja'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(caixa.toJson()),
      ),
    );
    if (response['success'] == true) {
      return response;
    } else {
      throw Exception(response['msg'] ?? 'Erro ao atualizar caixa.');
    }
  }

  // Relatório Mensal
  Future<List<RelatorioMensal>> getRelatorioMensal(int ano) async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/caixa/mensal/$idLoja/$ano')),
    );

    if (response['success'] == true) {
      final List<dynamic> list = response['data'];
      return list.map((item) => RelatorioMensal.fromJson(item)).toList();
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar relatório mensal.');
    }
  }

  // Relatório Semanal
  Future<List<RelatorioSemanal>> getRelatorioSemanal() async {
    final idLoja = GlobalState().firstIdLoja;
    if (idLoja == null) throw Exception('Nenhuma loja selecionada.');

    final response = await _handleRequest(
      () => http.get(Uri.parse('$_baseUrl/caixa/semanal/$idLoja')),
    );

    if (response['success'] == true) {
      final List<dynamic> list = response['data'];
      return list.map((item) => RelatorioSemanal.fromJson(item)).toList();
    } else {
      throw Exception(response['msg'] ?? 'Erro ao buscar relatório semanal.');
    }
  }

  // Login
  Future<Map<String, dynamic>> login(String user, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'login': user, 'senha': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 401) {
      final decodedJson = json.decode(response.body);
      if (decodedJson['success'] == false) {
        throw Exception(decodedJson['msg'] ?? 'Credenciais inválidas');
      }
      return decodedJson;
    } else {
      throw Exception(
        'Falha ao tentar realizar o login. Status: ${response.statusCode}',
      );
    }
  }
}
