import 'package:json_annotation/json_annotation.dart';

part 'relatorio_mensal.g.dart';

@JsonSerializable()
class RelatorioMensal {
  @JsonKey(name: 'id_loja')
  final int? idLoja;

  @JsonKey(name: 'ano')
  final int? ano;

  @JsonKey(name: 'mes')
  final int? mes;

  @JsonKey(name: 'media_saldo')
  final double? mediaSaldo;

  @JsonKey(name: 'soma_saldo')
  final double? somaSaldo;

  @JsonKey(name: 'soma_pedidos_confirmados')
  final double? somaPedidosConfirmados;

  @JsonKey(name: 'media_pedidos_confirmados')
  final double? mediaPedidosConfirmados;

  @JsonKey(name: 'soma_pedidos_estornados')
  final double? somaPedidosEstornados;

  RelatorioMensal({
    this.idLoja,
    this.ano,
    this.mes,
    this.mediaSaldo,
    this.somaSaldo,
    this.somaPedidosConfirmados,
    this.mediaPedidosConfirmados,
    this.somaPedidosEstornados,
  });

  factory RelatorioMensal.fromJson(Map<String, dynamic> json) =>
      _$RelatorioMensalFromJson(json);

  Map<String, dynamic> toJson() => _$RelatorioMensalToJson(this);

  // Helper para obter o nome do mês
  String get nomeMes {
    const meses = [
      '',
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];
    return mes != null && mes! > 0 && mes! <= 12 ? meses[mes!] : 'N/A';
  }

  // Helper para obter o nome do mês abreviado
  String get nomeMesAbreviado {
    const meses = [
      '',
      'Jan',
      'Fev',
      'Mar',
      'Abr',
      'Mai',
      'Jun',
      'Jul',
      'Ago',
      'Set',
      'Out',
      'Nov',
      'Dez',
    ];
    return mes != null && mes! > 0 && mes! <= 12 ? meses[mes!] : 'N/A';
  }
}
