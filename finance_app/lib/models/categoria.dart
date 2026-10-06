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

  /// A API retorna 'id_cliente'; 'id_loja' é aceito como legado no envio.
  @JsonKey(name: 'id_loja', readValue: _readIdLoja)
  final int idLoja;

  static Object? _readIdLoja(Map json, String key) =>
      json['id_cliente'] ?? json[key];

  final String descricao;

  @AtivadoConverter()
  final bool? ativado;

  @JsonKey(name: 'tipo_fluxo')
  final int tipoFluxo;

  /// Marca a categoria para aparecer entre os 4 círculos do seletor.
  @AtivadoConverter()
  final bool? destaque;

  /// Nome do ícone Material (ex.: `shopping_cart`), resolvido por
  /// `CategoriaVisuais.icone`. Nulo/vazio cai no ícone genérico.
  final String? icone;

  /// Cor em `#RRGGBB`, resolvida por `CategoriaVisuais.cor`.
  final String? cor;

  Categoria({
    this.id,
    required this.idLoja,
    required this.descricao,
    this.ativado,
    required this.tipoFluxo,
    this.destaque,
    this.icone,
    this.cor,
  });

  factory Categoria.fromJson(Map<String, dynamic> json) =>
      _$CategoriaFromJson(json);
  Map<String, dynamic> toJson() => _$CategoriaToJson(this);
}
