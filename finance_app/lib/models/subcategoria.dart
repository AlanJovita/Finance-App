import 'package:json_annotation/json_annotation.dart';

import 'categoria.dart' show AtivadoConverter, IdConverter;

part 'subcategoria.g.dart';

/// Filha de uma [Categoria], opcional no lançamento.
///
/// Não tem cor própria: o seletor pinta a subcategoria com a cor da categoria
/// pai a 70% de opacidade, para o círculo da filha ler como variação do pai.
///
/// Também não tem `id_loja`/`id_cliente` — a loja é a da categoria pai, e a API
/// resolve isso no JOIN de `/finance/subcategoria/cliente/{idLoja}`.
@JsonSerializable()
class Subcategoria {
  @IdConverter()
  final int? id;

  @JsonKey(name: 'id_categoria')
  final int idCategoria;

  final String descricao;

  @AtivadoConverter()
  final bool? ativado;

  @AtivadoConverter()
  final bool? destaque;

  final String? icone;

  Subcategoria({
    this.id,
    required this.idCategoria,
    required this.descricao,
    this.ativado,
    this.destaque,
    this.icone,
  });

  factory Subcategoria.fromJson(Map<String, dynamic> json) =>
      _$SubcategoriaFromJson(json);
  Map<String, dynamic> toJson() => _$SubcategoriaToJson(this);
}
