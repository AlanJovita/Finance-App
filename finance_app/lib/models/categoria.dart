import 'package:json_annotation/json_annotation.dart';

part 'categoria.g.dart';

@JsonSerializable()
class Categoria {
  final int? id;
  @JsonKey(name: 'id_loja')
  final int idLoja;
  final String descricao;
  final bool? ativado;
  @JsonKey(name: 'tipo_fluxo')
  final String tipoFluxo;

  Categoria({
    this.id,
    required this.idLoja,
    required this.descricao,
    this.ativado,
    required this.tipoFluxo,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      _$CategoriaFromJson(json);
  Map<String, dynamic> toJson() => _$CategoriaToJson(this);
}
