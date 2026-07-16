import 'package:json_annotation/json_annotation.dart';

part 'relatorio_semanal.g.dart';

@JsonSerializable()
class RelatorioSemanal {
  /// A API retorna 'id_cliente'; 'id_loja' é aceito como legado.
  @JsonKey(name: 'id_loja', readValue: _readIdLoja)
  final int? idLoja;

  static Object? _readIdLoja(Map json, String key) =>
      json['id_cliente'] ?? json[key];

  @JsonKey(name: 'dia_semana')
  final int? diaSemana;

  @JsonKey(name: 'media_saldo')
  final double? mediaSaldo;

  @JsonKey(name: 'media_pedidos_confirmados')
  final double? mediaPedidosConfirmados;

  @JsonKey(name: 'record_saldo')
  final double? recordSaldo;

  @JsonKey(name: 'record_pedidos_confirmados')
  final int? recordPedidosConfirmados;

  RelatorioSemanal({
    this.idLoja,
    this.diaSemana,
    this.mediaSaldo,
    this.mediaPedidosConfirmados,
    this.recordSaldo,
    this.recordPedidosConfirmados,
  });

  factory RelatorioSemanal.fromJson(Map<String, dynamic> json) =>
      _$RelatorioSemanalFromJson(json);

  Map<String, dynamic> toJson() => _$RelatorioSemanalToJson(this);

  // Helper para obter o nome do dia da semana
  String get nomeDiaSemana {
    const dias = [
      '',
      'Segunda-feira',
      'Terça-feira',
      'Quarta-feira',
      'Quinta-feira',
      'Sexta-feira',
      'Sábado',
      'Domingo',
    ];
    return diaSemana != null && diaSemana! > 0 && diaSemana! <= 7
        ? dias[diaSemana!]
        : 'N/A';
  }

  // Helper para obter o nome abreviado do dia da semana
  String get nomeDiaSemanaAbreviado {
    const dias = ['', 'Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
    return diaSemana != null && diaSemana! > 0 && diaSemana! <= 7
        ? dias[diaSemana!]
        : 'N/A';
  }

  // Helper para obter nome super abreviado (3 letras)
  String get nomeDiaSemanaCurto {
    const dias = ['', 'SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SÁB', 'DOM'];
    return diaSemana != null && diaSemana! > 0 && diaSemana! <= 7
        ? dias[diaSemana!]
        : 'N/A';
  }
}
