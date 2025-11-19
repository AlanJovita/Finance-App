import 'package:json_annotation/json_annotation.dart';

part 'categoria.g.dart';

/// Conversor para id: converte null para 0
class IdConverter implements JsonConverter<int?, int> {
  const IdConverter();

  @override
  int fromJson(int json) => json;

  @override
  int toJson(int? object) => object ?? 0;
}

/// Conversor para ativado: converte entre bool (modelo) e int (JSON)
/// JSON → Modelo: 1 = true, 0 ou qualquer outro = false
/// Modelo → JSON: true = 1, false/null = 0
class AtivadoConverter implements JsonConverter<bool?, dynamic> {
  const AtivadoConverter();

  @override
  bool? fromJson(dynamic json) {
    if (json is int) {
      return json == 1;
    } else if (json is bool) {
      return json;
    }
    return false;
  }

  @override
  int toJson(bool? object) => object == true ? 1 : 0;
}

@JsonSerializable()
class Categoria {
  @IdConverter()
  final int? id;

  @JsonKey(name: 'id_loja')
  final int idLoja;

  final String descricao;

  @AtivadoConverter()
  final bool? ativado;

  @JsonKey(name: 'tipo_fluxo')
  final int tipoFluxo;

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
