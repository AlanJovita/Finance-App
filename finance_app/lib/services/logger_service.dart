import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LoggerService {
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  static const String _logFileName = 'finance_app_errors.log';
  static const int _maxLogSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Registra um erro no arquivo de log
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
      final logEntry = _formatLogEntry(
        timestamp,
        source,
        error,
        stackTrace,
        additionalInfo,
      );

      // Tenta salvar no arquivo
      await _writeToFile(logEntry);

      // Também imprime no console para debug
      print('🔴 ERRO REGISTRADO: $source');
      print(logEntry);
    } catch (e) {
      // Se falhar ao salvar o log, apenas imprime no console
      print('⚠️ Falha ao salvar log: $e');
      print('Erro original: $error');
    }
  }

  /// Registra uma informação no log
  Future<void> logInfo(String source, String message) async {
    try {
      final timestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());
      final logEntry = '[$timestamp] [INFO] [$source] $message\n\n';

      await _writeToFile(logEntry);
      print('ℹ️ INFO: $source - $message');
    } catch (e) {
      print('⚠️ Falha ao salvar log info: $e');
    }
  }

  /// Registra uma advertência no log
  Future<void> logWarning(String source, String message) async {
    try {
      final timestamp = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());
      final logEntry = '[$timestamp] [WARNING] [$source] $message\n\n';

      await _writeToFile(logEntry);
      print('⚠️ WARNING: $source - $message');
    } catch (e) {
      print('⚠️ Falha ao salvar log warning: $e');
    }
  }

  /// Formata a entrada do log
  String _formatLogEntry(
    String timestamp,
    String source,
    dynamic error,
    StackTrace? stackTrace,
    Map<String, dynamic>? additionalInfo,
  ) {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('[$timestamp] [ERROR] [$source]');
    buffer.writeln('-' * 80);
    buffer.writeln('Erro: ${error.toString()}');

    if (additionalInfo != null && additionalInfo.isNotEmpty) {
      buffer.writeln('-' * 80);
      buffer.writeln('Informações Adicionais:');
      additionalInfo.forEach((key, value) {
        buffer.writeln('  $key: $value');
      });
    }

    if (stackTrace != null) {
      buffer.writeln('-' * 80);
      buffer.writeln('Stack Trace:');
      buffer.writeln(stackTrace.toString());
    }

    buffer.writeln('=' * 80);
    buffer.writeln();

    return buffer.toString();
  }

  /// Escreve no arquivo de log
  Future<void> _writeToFile(String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');

      // Verifica o tamanho do arquivo e limpa se necessário
      if (await file.exists()) {
        final size = await file.length();
        if (size > _maxLogSizeBytes) {
          await _rotateLogFile(file);
        }
      }

      // Adiciona o conteúdo ao arquivo
      await file.writeAsString(content, mode: FileMode.append, flush: true);
    } catch (e) {
      // Falha silenciosa - não queremos que o logging cause problemas
      print('⚠️ Erro ao escrever no arquivo de log: $e');
    }
  }

  /// Rotaciona o arquivo de log quando fica muito grande
  Future<void> _rotateLogFile(File file) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFile = File(
        '${directory.path}/finance_app_errors_$timestamp.log',
      );

      // Renomeia o arquivo antigo
      await file.copy(backupFile.path);
      await file.delete();

      // Mantém apenas os últimos 3 backups
      await _cleanOldBackups(directory);
    } catch (e) {
      print('⚠️ Erro ao rotacionar arquivo de log: $e');
    }
  }

  /// Remove backups antigos mantendo apenas os 3 mais recentes
  Future<void> _cleanOldBackups(Directory directory) async {
    try {
      final files =
          directory
              .listSync()
              .where(
                (f) =>
                    f is File &&
                    f.path.contains('finance_app_errors_') &&
                    f.path.endsWith('.log'),
              )
              .map((f) => f as File)
              .toList();

      if (files.length > 3) {
        // Ordena por data de modificação (mais antigos primeiro)
        files.sort(
          (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
        );

        // Remove os mais antigos, mantendo apenas 3
        for (var i = 0; i < files.length - 3; i++) {
          await files[i].delete();
        }
      }
    } catch (e) {
      print('⚠️ Erro ao limpar backups antigos: $e');
    }
  }

  /// Obtém o caminho do arquivo de log atual
  Future<String> getLogFilePath() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$_logFileName';
    } catch (e) {
      return 'Erro ao obter caminho do log: $e';
    }
  }

  /// Lê o conteúdo do arquivo de log
  Future<String> readLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');

      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'Nenhum log encontrado.';
      }
    } catch (e) {
      return 'Erro ao ler arquivo de log: $e';
    }
  }

  /// Limpa o arquivo de log
  Future<void> clearLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');

      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      print('⚠️ Erro ao limpar arquivo de log: $e');
    }
  }

  /// Exporta logs para compartilhamento
  Future<File?> exportLog() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_logFileName');

      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      print('⚠️ Erro ao exportar log: $e');
      return null;
    }
  }
}
