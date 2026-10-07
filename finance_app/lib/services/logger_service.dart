import 'dart:convert';
import 'package:finance_app/services/global_state.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../models/evento.dart';
import '../models/erro.dart';
import 'api_config.dart';

/// Log da aplicação: manda erro e evento para o log central do api-master.
///
/// Os erros vão para `POST /v1/erro`, que persiste na tabela `log` do Supabase e
/// alimenta o painel de erros usado pelo suporte (ranking por erro e por
/// cliente). Toda linha carrega [idSoftwareFinance] — é o que separa estes logs
/// dos dos outros produtos que gravam na mesma tabela — e [versaoLog], que é o
/// que distingue um erro do app de um erro da finance-api.
///
/// Nenhum método relança nada: falha de rede ao registrar um log não pode virar
/// o erro que a tela vai mostrar. O padrão em todo o app é `catch`, `await
/// _logger.logError(...)`, depois rethrow ou `return false`.
class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const String _baseUrl = apiBaseUrl;
  static const String _eventoEndpoint = '/v1/evento';
  static const String _erroEndpoint = '/v1/erro';

  /// Envia um evento para o endpoint
  Future<bool> enviarEvento(Evento evento) async {
    try {
      final url = Uri.parse('$_baseUrl$_eventoEndpoint');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(evento.toJson()),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout ao enviar evento');
            },
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Envia um erro para o endpoint (POST /v1/erro — a rota não aceita GET)
  Future<bool> enviarErro(Erro erro) async {
    try {
      final url = Uri.parse('$_baseUrl$_erroEndpoint');

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(erro.toJson()),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw Exception('Timeout ao enviar erro');
            },
          );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  /// Registra um erro e envia para o endpoint
  Future<void> logError(
    String source,
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final timestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      // Extrai informações do stack trace
      String classe = source;
      String metodo = 'unknown';
      int linha = 0;

      if (stackTrace != null) {
        final stackLines = stackTrace.toString().split('\n');
        if (stackLines.isNotEmpty) {
          final firstLine = stackLines.first;
          // Tenta extrair informações da primeira linha do stack trace
          final match = RegExp(
            r'#\d+\s+(\w+)\.(\w+)\s+\(.*:(\d+):\d+\)',
          ).firstMatch(firstLine);
          if (match != null) {
            classe = match.group(1) ?? classe;
            metodo = match.group(2) ?? metodo;
            linha = int.tryParse(match.group(3) ?? '0') ?? 0;
          }
        }
      }

      final descricao = _formatErrorDescription(
        error,
        stackTrace,
        additionalInfo,
      );

      final erro = Erro(
        idLog: 0,
        idCliente: GlobalState().firstIdLoja,
        data: timestamp,
        descricao: descricao,
        versao: versaoLog,
        classe: classe,
        metodo: metodo,
        linha: linha,
        qtd: 1,
        status: 0,
        classificacao: 0,
        origem: idSoftwareFinance,
        idUsuarioLocal: 0,
        idComputadorLocal: 0,
      );

      await enviarErro(erro);
    } catch (e) {
      return;
    }
  }

  /// Registra uma informação no log como evento
  Future<void> logInfo(String message) async {
    try {
      final timestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      final evento = Evento(
        idCliente: GlobalState().firstIdLoja,
        data: timestamp,
        descricao: message,
        origem: idSoftwareFinance,
        idUsuarioLocal: 0,
      );

      await enviarEvento(evento);
    } catch (e) {
      return;
    }
  }

  /// Formata a descrição do erro
  String _formatErrorDescription(
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('Erro: ${error.toString()}');

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.writeln('Informações Adicionais:');
      additionalInfo.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    if (stackTrace != null) {
      buffer.writeln('Stack Trace:');
      final stackLines = stackTrace.toString().split('\n');
      // Limita o stack trace para não ficar muito grande
      final limitedStack = stackLines.take(10).join('\n');
      buffer.writeln(limitedStack);
    }

    return buffer.toString();
  }

  /// Registra um evento customizado
  Future<void> registrarEvento({
    required int idCliente,
    required String descricao,
    required int origem,
    required int idUsuarioLocal,
  }) async {
    try {
      final timestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());

      final evento = Evento(
        idCliente: idCliente,
        data: timestamp,
        descricao: descricao,
        origem: origem,
        idUsuarioLocal: idUsuarioLocal,
      );

      await enviarEvento(evento);
    } catch (e) {
      return;
    }
  }

  /// Registra um erro customizado
  Future<void> registrarErro(Erro erro) async {
    try {
      await enviarErro(erro);
    } catch (e) {
      return;
    }
  }
}
