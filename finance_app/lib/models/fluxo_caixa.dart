import 'package:json_annotation/json_annotation.dart';

part 'fluxo_caixa.g.dart';

/// Tenta converter um valor para [T] (int ou double) de forma segura.
/// Retorna null se o valor for nulo ou a conversão falhar.
T? _safeCast<T extends num>(dynamic value) {
  if (value == null) return null;
  if (value is T) return value;
  if (value is num) {
    if (T == int) {
      return value.toInt() as T?;
    } else if (T == double) {
      return value.toDouble() as T?;
    }
  }
  if (value is String) {
    if (T == int) {
      return int.tryParse(value) as T?;
    } else if (T == double) {
      return double.tryParse(value) as T?;
    }
  }
  return null;
}

/// Converte qualquer valor para String de forma segura.
String? _safeString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  return value.toString();
}

@JsonSerializable(explicitToJson: true)
class FluxoCaixa {
  final int? id;
  @JsonKey(name: 'id_loja')
  final int? idLoja;
  @JsonKey(name: 'id_categoria')
  final int? idCategoria;
  final String? descricao;
  final double? valor;
  @JsonKey(name: 'tipo_fluxo')
  final String? tipoFluxo;
  final bool? cancelado;
  final bool? confirmado;
  @JsonKey(name: 'data_criacao')
  final DateTime? dataCriacao;
  @JsonKey(name: 'data_vencimento')
  final DateTime? dataVencimento;
  @JsonKey(name: 'dia_vencimento')
  final int? diaVencimento;
  final String? repeticao;
  @JsonKey(name: 'id_ref')
  final int? idRef;

  FluxoCaixa({
    this.id,
    this.idLoja,
    this.idCategoria,
    this.descricao,
    this.valor,
    this.tipoFluxo,
    this.cancelado,
    this.confirmado,
    this.dataCriacao,
    this.dataVencimento,
    this.diaVencimento,
    this.repeticao,
    this.idRef,
  });

  factory FluxoCaixa.fromJson(Map<String, dynamic> json) {
    try {
      return FluxoCaixa(
        id: _safeCast<int>(json['id']),
        idLoja: _safeCast<int>(json['id_loja']),
        idCategoria: _safeCast<int>(json['id_categoria']),
        descricao: _safeString(json['descricao']),
        valor: _safeCast<double>(json['valor']),
        tipoFluxo: _safeString(json['tipo_fluxo']),
        cancelado: json['cancelado'] as bool?,
        confirmado: json['confirmado'] as bool?,
        dataCriacao: _parseCustomDate(json['data_criacao']),
        dataVencimento: _parseCustomDate(json['data_vencimento']),
        diaVencimento: _safeCast<int>(json['dia_vencimento']),
        repeticao: _safeString(json['repeticao']),
        idRef: _safeCast<int>(json['id_ref']),
      );
    } catch (e) {
      print('Erro ao converter FluxoCaixa.fromJson: $e');
      print('JSON recebido: $json');
      rethrow;
    }
  }

  /// Converte datas no formato "d/M/yyyy" ou "--:--" para DateTime
  static DateTime? _parseCustomDate(dynamic value) {
    if (value == null) return null;
    final dateStr = value.toString().trim();

    // Verifica se é um formato inválido
    if (dateStr.isEmpty || dateStr == '--:--' || dateStr == '--') {
      return null;
    }

    // Tenta o parse padrão primeiro
    var date = DateTime.tryParse(dateStr);
    if (date != null) return date;

    // Tenta fazer parse do formato "d-M-yyyy" ou "dd-MM-yyyy"
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (e) {
      print('Erro ao fazer parse da data: $dateStr - $e');
    }

    return null;
  }

  Map<String, dynamic> toJson() => _$FluxoCaixaToJson(this);
}
