import 'package:json_annotation/json_annotation.dart';

part 'fluxo_caixa.g.dart';

@JsonSerializable()
class FluxoCaixa {
  final int? id;
  @JsonKey(name: 'id_loja')
  final int idLoja;
  @JsonKey(name: 'id_categoria')
  final int idCategoria;
  final String descricao;
  final double valor;
  @JsonKey(name: 'tipo_fluxo')
  final String tipoFluxo;
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
    required this.idLoja,
    required this.idCategoria,
    required this.descricao,
    required this.valor,
    required this.tipoFluxo,
    this.cancelado,
    this.confirmado,
    this.dataCriacao,
    this.dataVencimento,
    this.diaVencimento,
    this.repeticao,
    this.idRef,
  });

  factory FluxoCaixa.fromJson(Map<String, dynamic> json) =>
      _$FluxoCaixaFromJson(json);
  Map<String, dynamic> toJson() => _$FluxoCaixaToJson(this);
}
